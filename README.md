# Terraform config to launch Rancher 2 on an K3s cluster

## Summary

This Terraform setup will:

- Start `count_server_nodes` amount of K3s server node droplets
- Start `count_agent_nodes` amount of K3s agent node droplets
- Create a loadbalancer pointing at the server droplets for ports 80, 443, 6443
- Install k3s on the first server node, according to `k3s_version`
- Install k3s on the other server nodes, according to `k3s_version` and join them to the cluster via the loadbalancer
- Install K3s on the agent nodes, according to `k3s_version`, and join them to the cluster via the loadbalancer
- Install the cert-manager helm chart
- Install the Rancher helm chart according to the version specified in `rancher_version` using the helm repository specified in `rancher_chart_repo` if specified (or falling back to rancher-latest)

## Options

- If `etcd` is set to `false`, it will create a database for the K3s datastore, according to `db_engine` and `db_version`

All available options/variables are described in [terraform.tfvars.example](https://github.com/axeal/tf-do-k3s/blob/master/terraform.tfvars.example).

## SSH Config

**Note: set the appropriate users for the images in the terraform variables, default is `root`**

You can use the use the auto-generated ssh_config file to connect to the droplets by droplet name, e.g. `ssh <prefix>-server-0`. To do so, you have two options:

1. Add an `Include` directive at the top of the SSH config file in your home directory (`~/.ssh/config`) to include the ssh_config file at the location you have checked out the this repository, e.g. `Include ~/git/tf-do-k3s/ssh_config`.

2. Specify the ssh_config file when invoking `ssh` via the `-F` option, e.g. `ssh -F ~/git/tf-do-k3s/ssh_config <host>`.

## How to use

- Clone this repository
- Move the file `terraform.tfvars.example` to `terraform.tfvars` and edit (see inline explanation)
- Run `terraform apply`
