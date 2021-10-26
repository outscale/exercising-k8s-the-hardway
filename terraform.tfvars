#access_key_id       = "MyAccessKey"
#secret_key_id       = "MySecretKey"
#region              = "eu-west-2"

image_id              = "ami-4779e795" # Ubuntu-20.04-2021.09.09-0 on eu-west-2
control_plane_vm_type = "tinav5.c4r8p1"
control_plane_count   = 3
worker_vm_type        = "tinav5.c4r8p1"
worker_count          = 3
cluster_name          = "phandalin"
kubernetes_version    = "v1.21.0"
terraform_os          = "linux"
terraform_arch        = "amd64"
with_cloud_provider   = false
with_example_2048     = false # Deploy a Service of type Load Balancer as an example (need with_cloud_provider = true)
