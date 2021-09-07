#access_key_id       = "MyAccessKey"
#secret_key_id       = "MySecretKey"
#region              = "eu-west-2"

image_id              = "ami-19c942b5" # Ubuntu-20.04-2021.05.07-1 on eu-west-2
control_plane_vm_type = "tinav5.c4r8p1"
control_plane_count   = 3
worker_vm_type        = "tinav5.c4r8p1"
worker_count          = 3
cluster_name          = "phandalin"
kubernetes_version    = "v1.21.0"
terraform_os          = "linux"
terraform_arch        = "amd64"
with_cloud_provider   = false
