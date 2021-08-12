resource "local_file" "workers-kubelet-csr-json" {
  count    = var.worker_count
  filename = "${path.module}/kubelet/worker-${count.index}-kubelet-csr.json"
  content  = <<-EOF
{
  "CN": "system:node:ip-10-0-1-${10 + count.index}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Saint-Cloud",
      "O": "system:nodes",
      "OU": "Outscale Kubernetes",
      "ST": "IDF"
    }
  ]
}
  EOF
}

resource "shell_script" "workers-kubelet" {
  count = var.worker_count
  lifecycle_commands {
    create = <<-EOF
	../bin/cfssl gencert \
            -ca=../ca/ca.pem \
            -ca-key=../ca/ca-key.pem \
            -config=../ca/ca-config.json \
            -hostname=ip-10-0-1-${10 + count.index},${format("10.0.1.%d", 10 + count.index)} \
            -profile=kubernetes \
            worker-${count.index}-kubelet-csr.json \
            | ../bin/cfssljson -bare worker-${count.index}-kubelet
    EOF
    read   = <<-EOF
        echo "{\"pem_b64\": \"$(cat worker-${count.index}-kubelet.pem|base64)\",
               \"csr_b64\": \"$(cat worker-${count.index}-kubelet.csr|base64)\",
               \"key_b64\": \"$(cat worker-${count.index}-kubelet-key.pem|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f worker-${count.index}-kubelet.pem
        rm -f worker-${count.index}-kubelet-key.pem
        rm -f worker-${count.index}-kubelet.csr
    EOF
  }
  working_directory = "${path.root}/kubelet"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, local_file.workers-kubelet-csr-json]
}

resource "shell_script" "workers-kubelet-kubeconfig" {
  count = var.worker_count
  lifecycle_commands {
    create = <<-EOF
	../bin/kubectl-local config set-cluster ${var.cluster_name} \
            --certificate-authority=../ca/ca.pem \
            --embed-certs=true \
            --server=https://${outscale_load_balancer.kubernetes-lb.dns_name}:6443 \
            --kubeconfig=worker-${count.index}.kubeconfig
	../bin/kubectl-local config set-credentials system:node:ip-10-0-1-${10 + count.index} \
            --client-certificate=worker-${count.index}-kubelet.pem \
            --client-key=worker-${count.index}-kubelet-key.pem \
            --embed-certs=true \
            --kubeconfig=worker-${count.index}.kubeconfig
	../bin/kubectl-local config set-context default \
            --cluster=${var.cluster_name} \
            --user=system:node:ip-10-0-1-${10 + count.index} \
            --kubeconfig=worker-${count.index}.kubeconfig
	../bin/kubectl-local config use-context default \
            --kubeconfig=worker-${count.index}.kubeconfig
    EOF
    read   = <<-EOF
        echo "{\"b64\": \"$(cat worker-${count.index}.kubeconfig|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f worker-${count.index}.kubeconfig
    EOF
  }
  working_directory = "${path.root}/kubelet"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, shell_script.workers-kubelet]
}

resource "local_file" "kubelet-config-yaml" {
  count    = var.worker_count
  filename = "${path.module}/kubelet/worker-${count.index}_kubelet-config.yaml"
  content  = <<-EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "10.200.${count.index}.0/24"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/worker-${count.index}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/worker-${count.index}-key.pem"
  EOF
}

resource "shell_script" "kubelet-bin" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget -q --https-only --timestamping "https://storage.googleapis.com/kubernetes-release/release/${var.kubernetes_version}/bin/linux/amd64/kubelet" -O bin/kubelet
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/kubelet|base64)\"}"
    EOF
    delete = "rm -f bin/kubelet"
  }
}

resource "shell_script" "kubelet-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kubelet/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kubelet/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat kubelet/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check kubelet/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [local_file.workers-kubelet-csr-json, shell_script.workers-kubelet, shell_script.workers-kubelet-kubeconfig, local_file.kubelet-config-yaml, shell_script.kubelet-bin, shell_script.containerd-playbook]
}
