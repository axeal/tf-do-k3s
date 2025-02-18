# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_account" "do-account" {
}

resource "digitalocean_vpc" "droplets-network" {
  name   = "${var.prefix}-droplets-vpc"
  region = var.region
}

resource "time_sleep" "wait_20_seconds_to_destroy_vpc" {
  depends_on       = [digitalocean_vpc.droplets-network]
  destroy_duration = "20s"
}

resource "digitalocean_loadbalancer" "k3s-server" {
  depends_on = [time_sleep.wait_20_seconds_to_destroy_vpc]
  name       = "${var.prefix}-k3s-server"
  vpc_uuid   = digitalocean_vpc.droplets-network.id
  region     = var.region

  forwarding_rule {
    entry_port     = 6443
    entry_protocol = "tcp"

    target_port     = 6443
    target_protocol = "tcp"
  }

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "tcp"

    target_port     = 80
    target_protocol = "tcp"
  }

  forwarding_rule {
    entry_port     = 443
    entry_protocol = "tcp"

    target_port     = 443
    target_protocol = "tcp"
  }

  healthcheck {
    port     = 6443
    protocol = "tcp"
  }

  droplet_tag = "${var.prefix}-k3s-server"

}

resource "digitalocean_database_cluster" "k3s" {
  name                 = "${var.prefix}-k3s"
  engine               = var.db_engine
  version              = var.db_version
  size                 = var.db_size
  private_network_uuid = digitalocean_vpc.droplets-network.id
  region               = var.region
  node_count           = 1
}

resource "digitalocean_database_db" "k3s" {
  cluster_id = digitalocean_database_cluster.k3s.id
  name       = "k3s"
}

resource "random_string" "cluster-token" {
  length  = 24
  special = true
}

resource "digitalocean_droplet" "server-node" {
  depends_on = [time_sleep.wait_20_seconds_to_destroy_vpc]
  count      = var.count_server_nodes
  image      = var.image
  name       = "${var.prefix}-server-${count.index}"
  vpc_uuid   = digitalocean_vpc.droplets-network.id
  region     = var.region
  size       = var.server_size
  user_data = templatefile("files/userdata_server", {
    count              = "${count.index}"
    k3s_version        = var.k3s_version
    database_uri       = digitalocean_database_cluster.k3s.private_uri
    database_name      = digitalocean_database_db.k3s.name
    rancher_chart_repo = var.rancher_chart_repo
    rancher_version    = var.rancher_version
    admin_password     = var.admin_password
    token              = random_string.cluster-token.result
    lb_ip              = digitalocean_loadbalancer.k3s-server.ip
  })
  ssh_keys = var.ssh_keys
  tags = [
    join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")]),
    "${var.prefix}-k3s-server"
  ]
}

resource "digitalocean_droplet" "agent-node" {
  depends_on = [time_sleep.wait_20_seconds_to_destroy_vpc]
  count      = var.count_agent_nodes
  image      = var.image
  name       = "${var.prefix}-agent-${count.index}"
  vpc_uuid   = digitalocean_vpc.droplets-network.id
  region     = var.region
  size       = var.agent_size
  user_data = templatefile("files/userdata_agent", {
    k3s_version = var.k3s_version
    token       = random_string.cluster-token.result
    lb_ip       = digitalocean_loadbalancer.k3s-server.ip
  })
  ssh_keys = var.ssh_keys
  tags = [
    join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])
  ]
}

resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/files/ssh_config_template", {
    prefix  = var.prefix
    servers = [for node in digitalocean_droplet.server-node : node.ipv4_address],
    agents  = [for node in digitalocean_droplet.agent-node : node.ipv4_address],
    user    = var.user
  })
  filename = "${path.module}/ssh_config"
}

output "rancher-url" {
  value = ["https://${digitalocean_loadbalancer.k3s-server.ip}.nip.io"]
}
