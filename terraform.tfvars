#access_key_id       = "MyAccessKey"
#secret_key_id       = "MySecretKey"
region              = "eu-west-2"

image_id              = "ami-9f420a20"
bastion_vm_type       = "tinav5.c1r1p1"
control_plane_vm_type = "tinav5.c2r8p1"
control_plane_count   = 3
worker_vm_type        = "tinav5.c2r8p1"
worker_count          = 3
cluster_name          = "k8s"
kubernetes_version    = "1.31.4"
runc_version          = "1.2.1"
containerd_version    = "2.0.0"
etcd_version          = "3.5.17"
cni_version           = "1.6.0"
terraform_os          = "linux"
terraform_arch        = "amd64"
with_cloud_provider   = true
with_example_2048     = true # Deploy a Service of type Load Balancer as an example (need with_cloud_provider = true)
