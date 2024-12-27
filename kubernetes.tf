data "local_file" "kubernetes-csr-json" {
  filename = "${path.root}/kubernetes/kubernetes-csr.json"
}

resource "shell_script" "kubernetes" {
  lifecycle_commands {
    create = <<-EOF
	../bin/cfssl gencert \
            -ca=../ca/ca.pem \
            -ca-key=../ca/ca-key.pem \
            -config=../ca/ca-config.json \
            -profile=kubernetes \
            -hostname=10.32.0.1,127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local,${join(",", [for i in range(var.control_plane_count) : format("10.0.0.%d", 10 + i)])},${outscale_load_balancer.kubernetes-lb.dns_name} \
            kubernetes-csr.json \
            | ../bin/cfssljson -bare kubernetes
    EOF
    read   = <<-EOF
        echo "{\"pem_b64\": \"$(cat kubernetes.pem|base64)\",
               \"csr_b64\": \"$(cat kubernetes.csr|base64)\",
               \"key_b64\": \"$(cat kubernetes-key.pem|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f kubernetes.pem
        rm -f kubernetes-key.pem
        rm -f kubernetes.csr
    EOF
  }
  working_directory = "${path.root}/kubernetes"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, data.local_file.kubernetes-csr-json]
}

resource "shell_script" "kube-apiserver-bin" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget -q --https-only --timestamping "https://dl.k8s.io/v${var.kubernetes_version}/bin/linux/amd64/kube-apiserver" -O bin/kube-apiserver
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/kube-apiserver|base64)\", \"version\": \"${var.kubernetes_version}\"}"
    EOF
    delete = "rm -f bin/kube-apiserver"
  }
}

resource "local_file" "kube-apiserver-service" {
  count           = var.control_plane_count
  filename        = "${path.root}/kubernetes/control-plane-${count.index}_kube-apiserver.service"
  file_permission = "0660"
  content         = <<-EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
  --advertise-address=${format("10.0.0.%d", 10 + count.index)} \
  --allow-privileged=true \
  --apiserver-count=3 \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/var/log/audit.log \
  --authorization-mode=Node,RBAC \
  --bind-address=0.0.0.0 \
  --client-ca-file=/var/lib/kubernetes/ca.pem \
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
  --etcd-cafile=/var/lib/kubernetes/ca.pem \
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \
  --etcd-servers=${join(",", [for i in range(var.control_plane_count) : format("https://10.0.0.%d:2379", 10 + i)])} \
  --event-ttl=1h \
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \
  --runtime-config='api/all=true' \
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \
  --service-account-issuer=https://${outscale_load_balancer.kubernetes-lb.dns_name}:6443 \
  --service-cluster-ip-range=10.32.0.0/24 \
  --service-node-port-range=30000-32767 \
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  ${var.with_cloud_provider ? "--cloud-provider=external" : ""} \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

resource "shell_script" "kubernetes-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kubernetes/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook kubernetes/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat kubernetes/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check kubernetes/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.etcd-playbook, shell_script.admin-playbook, outscale_load_balancer.kubernetes-lb, data.local_file.kubernetes-csr-json, shell_script.kubernetes, shell_script.kube-apiserver-bin, local_file.kube-apiserver-service]
}
