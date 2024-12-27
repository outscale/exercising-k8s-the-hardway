data "local_file" "kube-scheduler-csr-json" {
  filename = "${path.root}/kube-scheduler/kube-scheduler-csr.json"
}

resource "shell_script" "kube-scheduler" {
  lifecycle_commands {
    create = <<-EOF
	../bin/cfssl gencert \
            -ca=../ca/ca.pem \
            -ca-key=../ca/ca-key.pem \
            -config=../ca/ca-config.json \
            -profile=kubernetes \
            kube-scheduler-csr.json \
            | ../bin/cfssljson -bare kube-scheduler
    EOF
    read   = <<-EOF
        echo "{\"pem_b64\": \"$(cat kube-scheduler.pem|base64)\",
               \"csr_b64\": \"$(cat kube-scheduler.csr|base64)\",
               \"key_b64\": \"$(cat kube-scheduler-key.pem|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f kube-scheduler.pem
        rm -f kube-scheduler-key.pem
        rm -f kube-scheduler.csr
    EOF
  }
  working_directory = "${path.root}/kube-scheduler"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, data.local_file.kube-scheduler-csr-json]
}

resource "shell_script" "kube-scheduler-kubeconfig" {
  lifecycle_commands {
    create = <<-EOF
        ../bin/kubectl-local config set-cluster ${var.cluster_name} \
            --certificate-authority=../ca/ca.pem \
            --embed-certs=true \
            --server=https://127.0.0.1:6443 \
            --kubeconfig=kube-scheduler.kubeconfig
        ../bin/kubectl-local config set-credentials system:kube-scheduler \
            --client-certificate=kube-scheduler.pem \
            --client-key=kube-scheduler-key.pem \
            --embed-certs=true \
            --kubeconfig=kube-scheduler.kubeconfig
        ../bin/kubectl-local config set-context default --cluster=${var.cluster_name} \
            --user=system:kube-scheduler \
            --kubeconfig=kube-scheduler.kubeconfig
        ../bin/kubectl-local config use-context default \
            --kubeconfig=kube-scheduler.kubeconfig
    EOF
    read   = <<-EOF
        echo "{\"b64\": \"$(cat kube-scheduler.kubeconfig|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f kube-scheduler.kubeconfig
    EOF
  }
  working_directory = "${path.root}/kube-scheduler"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, shell_script.kube-scheduler]
}

resource "shell_script" "kube-scheduler-bin" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget -q --https-only --timestamping "https://dl.k8s.io/v${var.kubernetes_version}/bin/linux/amd64/kube-scheduler" -O bin/kube-scheduler
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/kube-scheduler|base64)\", \"version\": \"${var.kubernetes_version}\"}"
    EOF
    delete = "rm -f bin/kube-scheduler"
  }
}

resource "local_file" "kube-scheduler-service" {
  filename        = "${path.root}/kube-scheduler/kube-scheduler.service"
  file_permission = "0660"
  content         = <<-EOF
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \
  --config=/etc/kubernetes/config/kube-scheduler.yaml \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

resource "shell_script" "kube-scheduler-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kube-scheduler/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kube-scheduler/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat kube-scheduler/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check kube-scheduler/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.kubernetes-playbook, data.local_file.kube-scheduler-csr-json, shell_script.kube-scheduler, shell_script.kube-scheduler-kubeconfig, shell_script.kube-scheduler-bin, local_file.kube-scheduler-service]
}
