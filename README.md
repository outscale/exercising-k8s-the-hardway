# Exercising with "kubernetes the hard way"
[![Project Sandbox](https://docs.outscale.com/fr/userguide/_images/Project-Sandbox-yellow.svg)](https://docs.outscale.com/en/userguide/Open-Source-Projects.html)

This reprository is an Outscale implementation of [kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way).

It uses [Outscale's terraform provider](https://registry.terraform.io/providers/outscale-dev/outscale/latest/docs) combined with [Ansible](https://www.ansible.com/).

Its purpose is mainly to play with Kubernetes, Terraform and Ansible on [Outscale cloud](http://www.outscale.com/).

Note that this project only follow the tutorial and has a number limitation like:
- Services IPs are only available on worker nodes
- No Ingress Controller installed
- Storage management is not availabled (no CSI)

# Architecture

The Kubernetes cluster is deployed inside a [Net](https://wiki.outscale.net/display/EN/About+VPCs) with two [Subnets](https://wiki.outscale.net/display/EN/Getting+Information+About+Your+Subnets):
- One subnet for control-plane nodes (3 VM by default)
- One subnet for worker nodes (2 VM by default)

Additional services deployed:
- A [Load-balancer](https://wiki.outscale.net/display/EN/About+Load+Balancers) distributes Kubernetes's API traffic on control-planes.
- A [NAT Service](https://wiki.outscale.net/display/EN/About+NAT+Gateways) is created to provide internet access to workers.
- Each control-plane has a public IP and are used as a bastion host to access worker nodes.
- Cloud controller manager (CCM) can be enabled in to run Service of type Load Balancer

# Prerequisite

- [Terraform](https://www.terraform.io/) (>= 0.14)
- [Ansible](https://www.ansible.com/) (>= 2.4)
- [Outscale Access Key and Secret Key](https://wiki.outscale.net/display/EN/Creating+an+Access+Key)

# Configuration

```
export TF_VAR_access_key_id="myaccesskey"
export TF_VAR_secret_key_id="mysecretkey"
export TF_VAR_region="eu-west-2"
```

By editing ['terraform.tfvars'](terraform.tfvars), you can adjust the number of nodes, kubernetes version, enabling CCM, etc.
Depending of your operating system, you may have to adapt `terraform_os` and `terraform_arch` variables.

Note about CCM: due to a meta-data bug (to be fixed), you will have to enable it in two steps:
1. run `terraform apply`
2. In `terraform.tfvars`: set `with_cloud_provider` to `true`.
3. In `workers.tf`, uncomment "OscK8sClusterID" tag in `outscale_vm` resource.
4. run again `terraform apply`

For macOS:
```
terraform_os = "darwin"
terraform_arch = "amd64"
```

# Deploy

Terraform will deploy all IaaS components and will run Ansible playbooks to setup nodes.

```
terraform init
terraform apply
```

This should take few minutes to complete, [time for a break](https://xkcd.com/303/).

# Connect to nodes

To connect to a worker node:
```
ssh -F ssh_config worker-0
```

To connect to a control-plane node and list all worker nodes:
```
ssh -F ssh_config control-plane-0
kubectl get nodes
```

Note that worker nodes may take few seconds to register to Kubernetes.

# Smoke Test

Smoke testing our newly created Kubernetes cluster can be done very similarely to [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/13-smoke-test.md).
Note that workers has no public IP so you can test Nodeport service from one control-plane.

You can also deploy a Service of type Load Balancer by setting `with_example_2048=true` (need `with_cloud_provider` enabled as well). You can get the load-balancer URL through `kubectl get service -n 2048`.

# Cleaning Up

Just run `terraform destroy`.

Alternatively, you can manually cleanup your resources if something goes wrong:
- Connect to [cockpit interface](https://cockpit.outscale.com/)
- Go to VPC->VPCs, Select the created VPC, click the "Teardown" button and validate.
- Go to Network/Security->Keypairs and delete Keypairs created for each node (3 control-planes and 2 workers by default)
- Go to Network/Security->External Ips and delete EIP created for each control-planes (3 by default)

# Contributing

Feel free to report an issue.
