resource "shell_script" "cfssl" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget "https://github.com/cloudflare/cfssl/releases/download/v1.6.0/cfssl_1.6.0_${var.terraform_os}_${var.terraform_arch}" -O bin/cfssl
        chmod +x bin/cfssl
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/cfssl)\"}"
    EOF
    delete = "rm -f bin/cfssl"
  }
}

resource "shell_script" "cfssljson" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget "https://github.com/cloudflare/cfssl/releases/download/v1.6.0/cfssljson_1.6.0_${var.terraform_os}_${var.terraform_arch}" -O bin/cfssljson
        chmod +x bin/cfssljson
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/cfssljson)\"}"
    EOF
    delete = "rm -f bin/cfssljson"
  }
}

resource "shell_script" "kubectl-local" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget "https://dl.k8s.io/release/${var.kubernetes_version}/bin/${var.terraform_os}/${var.terraform_arch}/kubectl" -O bin/kubectl-local
        chmod +x bin/kubectl-local
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/kubectl-local)\"}"
    EOF
    delete = "rm -f bin/kubectl-local"
  }
}

resource "shell_script" "kubectl-remote" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget "https://dl.k8s.io/release/${var.kubernetes_version}/bin/linux/amd64/kubectl" -O bin/kubectl
        chmod +x bin/kubectl
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/kubectl)\"}"
    EOF
    delete = "rm -f bin/kubectl"
  }
}

data "local_file" "admin-csr-json" {
  filename = "${path.module}/admin/admin-csr.json"
}

resource "shell_script" "admin" {
  lifecycle_commands {
    create = <<-EOF
        ../bin/cfssl gencert \
            -ca=../ca/ca.pem \
            -ca-key=../ca/ca-key.pem \
            -config=../ca/ca-config.json \
            -profile=kubernetes \
            admin-csr.json \
            | ../bin/cfssljson -bare admin
    EOF
    read   = <<-EOF
        echo "{\"pem_b64\": \"$(cat admin.pem|base64)\",
               \"key_b64\": \"$(cat admin-key.pem|base64)\"}"
    EOF
    delete = "rm -f admin.pem admin-key.pem admin.csr"
  }
  working_directory = "${path.module}/admin"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, data.local_file.admin-csr-json]
}

resource "shell_script" "admin-kubeconfig-lb" {
  lifecycle_commands {
    create = <<-EOF
        ../bin/kubectl-local config set-cluster ${var.cluster_name} \
            --certificate-authority=../ca/ca.pem \
            --embed-certs=true \
            --server=https://${outscale_load_balancer.kubernetes-lb.dns_name}:6443 \
            --kubeconfig=admin.kubeconfig
        ../bin/kubectl-local config set-credentials system:admin \
            --client-certificate=admin.pem \
            --client-key=admin-key.pem \
            --embed-certs=true \
            --kubeconfig=admin.kubeconfig
        ../bin/kubectl-local config set-context default --cluster=${var.cluster_name} \
            --user=system:admin \
            --kubeconfig=admin.kubeconfig
        ../bin/kubectl-local config use-context default \
            --kubeconfig=admin.kubeconfig
    EOF
    read   = <<-EOF
        echo "{\"b64\": \"$(cat admin.kubeconfig|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f admin.kubeconfig
    EOF
  }
  working_directory = "${path.root}/admin"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, shell_script.admin]
}

resource "shell_script" "admin-kubeconfig-public" {
  count = var.control_plane_count
  lifecycle_commands {
    create = <<-EOF
        ../bin/kubectl-local config set-cluster ${var.cluster_name} \
            --certificate-authority=../ca/ca.pem \
            --embed-certs=true \
            --server=https://${outscale_public_ip.control-planes[count.index].public_ip}:6443 \
            --kubeconfig=control-plane-${count.index}_admin.kubeconfig
        ../bin/kubectl-local config set-credentials system:admin \
            --client-certificate=admin.pem \
            --client-key=admin-key.pem \
            --embed-certs=true \
            --kubeconfig=control-plane-${count.index}_admin.kubeconfig
        ../bin/kubectl-local config set-context default --cluster=${var.cluster_name} \
            --user=system:admin \
            --kubeconfig=control-plane-${count.index}_admin.kubeconfig
        ../bin/kubectl-local config use-context default \
            --kubeconfig=control-plane-${count.index}_admin.kubeconfig
    EOF
    read   = <<-EOF
        echo "{\"b64\": \"$(cat control-plane-${count.index}_admin.kubeconfig|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f control-plane-${count.index}_admin.kubeconfig
    EOF
  }
  working_directory = "${path.root}/admin"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, shell_script.admin]
}

resource "shell_script" "admin-kubeconfig-localhost" {
  lifecycle_commands {
    create = <<-EOF
        ../bin/kubectl-local config set-cluster ${var.cluster_name} \
            --certificate-authority=../ca/ca.pem \
            --embed-certs=true \
            --server=https://127.0.0.1:6443 \
            --kubeconfig=localhost_admin.kubeconfig
        ../bin/kubectl-local config set-credentials system:admin \
            --client-certificate=admin.pem \
            --client-key=admin-key.pem \
            --embed-certs=true \
            --kubeconfig=localhost_admin.kubeconfig
        ../bin/kubectl-local config set-context default --cluster=${var.cluster_name} \
            --user=system:admin \
            --kubeconfig=localhost_admin.kubeconfig
        ../bin/kubectl-local config use-context default \
            --kubeconfig=localhost_admin.kubeconfig
    EOF
    read   = <<-EOF
        echo "{\"b64\": \"$(cat localhost_admin.kubeconfig|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f localhost_admin.kubeconfig
    EOF
  }
  working_directory = "${path.root}/admin"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, shell_script.admin]
}

resource "shell_script" "admin-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook admin/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook admin/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat admin/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check admin/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.control-planes-playbook, data.local_file.admin-csr-json, shell_script.admin-kubeconfig-lb, shell_script.admin-kubeconfig-public, shell_script.admin-kubeconfig-localhost]
}
