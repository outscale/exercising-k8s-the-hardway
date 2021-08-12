data "local_file" "kube-proxy-csr-json" {
  filename = "${path.root}/kube-proxy/kube-proxy-csr.json"
}

resource "shell_script" "kube-proxy" {
  lifecycle_commands {
    create = <<-EOF
	../bin/cfssl gencert \
            -ca=../ca/ca.pem \
            -ca-key=../ca/ca-key.pem \
            -config=../ca/ca-config.json \
            -profile=kubernetes \
            kube-proxy-csr.json \
            | ../bin/cfssljson -bare kube-proxy
    EOF
    read   = <<-EOF
        echo "{\"pem_b64\": \"$(cat kube-proxy.pem|base64)\",
               \"csr_b64\": \"$(cat kube-proxy.csr|base64)\",
               \"key_b64\": \"$(cat kube-proxy-key.pem|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f kube-proxy.pem
        rm -f kube-proxy-key.pem
        rm -f kube-proxy.csr
    EOF
  }
  working_directory = "${path.root}/kube-proxy"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, data.local_file.kube-proxy-csr-json]
}

resource "shell_script" "kube-proxy-kubeconfig" {
  lifecycle_commands {
    create = <<-EOF
        ../bin/kubectl-local config set-cluster ${var.cluster_name} \
            --certificate-authority=../ca/ca.pem \
            --embed-certs=true \
            --server=https://${outscale_load_balancer.kubernetes-lb.dns_name}:6443 \
            --kubeconfig=kube-proxy.kubeconfig
        ../bin/kubectl-local config set-credentials system:kube-proxy \
            --client-certificate=kube-proxy.pem \
            --client-key=kube-proxy-key.pem \
            --embed-certs=true \
            --kubeconfig=kube-proxy.kubeconfig
        ../bin/kubectl-local config set-context default --cluster=${var.cluster_name} \
            --user=system:kube-proxy \
            --kubeconfig=kube-proxy.kubeconfig
        ../bin/kubectl-local config use-context default \
            --kubeconfig=kube-proxy.kubeconfig
    EOF
    read   = <<-EOF
        echo "{\"b64\": \"$(cat kube-proxy.kubeconfig|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f kube-proxy.kubeconfig
    EOF
  }
  working_directory = "${path.root}/kube-proxy"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, shell_script.kube-proxy]
}

resource "shell_script" "kube-proxy-bin" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget -q --https-only --timestamping "https://storage.googleapis.com/kubernetes-release/release/${var.kubernetes_version}/bin/linux/amd64/kube-proxy" -O bin/kube-proxy
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/kube-proxy|base64)\"}"
    EOF
    delete = "rm -f bin/kube-proxy"
  }
}

resource "shell_script" "kube-proxy-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kube-proxy/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kube-proxy/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat kube-proxy/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check kube-proxy/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.cni-playbook, data.local_file.kube-proxy-csr-json, shell_script.kube-proxy-kubeconfig, shell_script.kube-proxy-bin]
}
