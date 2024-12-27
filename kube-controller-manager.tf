data "local_file" "kube-controller-manager-csr-json" {
  filename = "${path.root}/kube-controller-manager/kube-controller-manager-csr.json"
}

resource "shell_script" "kube-controller-manager" {
  lifecycle_commands {
    create = <<-EOF
	../bin/cfssl gencert \
            -ca=../ca/ca.pem \
            -ca-key=../ca/ca-key.pem \
            -config=../ca/ca-config.json \
            -profile=kubernetes \
            kube-controller-manager-csr.json \
            | ../bin/cfssljson -bare kube-controller-manager
    EOF
    read   = <<-EOF
        echo "{\"pem_b64\": \"$(cat kube-controller-manager.pem|base64)\",
               \"csr_b64\": \"$(cat kube-controller-manager.csr|base64)\",
               \"key_b64\": \"$(cat kube-controller-manager-key.pem|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f kube-controller-manager.pem
        rm -f kube-controller-manager-key.pem
        rm -f kube-controller-manager.csr
    EOF
  }
  working_directory = "${path.root}/kube-controller-manager"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, data.local_file.kube-controller-manager-csr-json]
}

resource "shell_script" "kube-controller-manager-kubeconfig" {
  lifecycle_commands {
    create = <<-EOF
        ../bin/kubectl-local config set-cluster ${var.cluster_name} \
            --certificate-authority=../ca/ca.pem \
            --embed-certs=true \
            --server=https://127.0.0.1:6443 \
            --kubeconfig=kube-controller-manager.kubeconfig
        ../bin/kubectl-local config set-credentials system:kube-controller-manager \
            --client-certificate=kube-controller-manager.pem \
            --client-key=kube-controller-manager-key.pem \
            --embed-certs=true \
            --kubeconfig=kube-controller-manager.kubeconfig
        ../bin/kubectl-local config set-context default --cluster=${var.cluster_name} \
            --user=system:kube-controller-manager \
            --kubeconfig=kube-controller-manager.kubeconfig
        ../bin/kubectl-local config use-context default \
            --kubeconfig=kube-controller-manager.kubeconfig
    EOF
    read   = <<-EOF
        echo "{\"b64\": \"$(cat kube-controller-manager.kubeconfig|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f kube-controller-manager.kubeconfig
    EOF
  }
  working_directory = "${path.root}/kube-controller-manager"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, shell_script.kube-controller-manager]
}

resource "shell_script" "kube-controller-manager-bin" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget -q --https-only --timestamping "https://dl.k8s.io/v${var.kubernetes_version}/bin/linux/amd64/kube-controller-manager" -O bin/kube-controller-manager
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/kube-controller-manager|base64)\", \"version\": \"${var.kubernetes_version}\"}"
    EOF
    delete = "rm -f bin/kube-controller-manager"
  }
}

resource "local_file" "kube-controller-manager-service" {
  filename        = "${path.root}/kube-controller-manager/kube-controller-manager.service"
  file_permission = "0660"
  content         = <<-EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \
  --bind-address=0.0.0.0 \
  --cluster-cidr=10.200.0.0/16 \
  --cluster-name=${var.cluster_name} \
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \
  --leader-elect=true \
  --root-ca-file=/var/lib/kubernetes/ca.pem \
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \
  --service-cluster-ip-range=10.32.0.0/24 \
  --use-service-account-credentials=true \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

resource "shell_script" "kube-controller-manager-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kube-controller-manager/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kube-controller-manager/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat kube-controller-manager/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check kube-controller-manager/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.kubernetes-playbook, data.local_file.kube-controller-manager-csr-json, shell_script.kube-controller-manager, shell_script.kube-controller-manager-kubeconfig, shell_script.kube-controller-manager-bin, local_file.kube-controller-manager-service]
}
