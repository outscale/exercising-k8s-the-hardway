resource "shell_script" "etcd-bin" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget -q --https-only --timestamping "https://github.com/etcd-io/etcd/releases/download/v3.5.0/etcd-v3.5.0-linux-amd64.tar.gz" -O etcd.tar.gz
        tar zxvf etcd.tar.gz
        mv etcd-v3.5.0-linux-amd64/etcd* ./bin
        rm -rf etcd-v3.5.0-linux-amd64 etcd.tar.gz
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/etcd*|base64)\", \"version\": \"$(./bin/etcd --version 2> /dev/null)\"}"
    EOF
    delete = "rm -f bin/etcd*"
  }
}

resource "local_file" "etcd-service" {
  count           = var.control_plane_count
  filename        = "${path.root}/etcd/control-plane-${count.index}_etcd.service"
  file_permission = "0660"
  content         = <<-EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name control-plane-${count.index} \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://${format("10.0.0.%d", 10 + count.index)}:2380 \
  --listen-peer-urls https://${format("10.0.0.%d", 10 + count.index)}:2380 \
  --listen-client-urls https://${format("10.0.0.%d", 10 + count.index)}:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://${format("10.0.0.%d", 10 + count.index)}:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster ${join(",", [for i in range(var.control_plane_count) : format("control-plane-%d=https://10.0.0.%d:2380", i, 10 + i)])} \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

resource "shell_script" "etcd-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook etcd/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook etcd/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat etcd/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check etcd/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.etcd-bin, local_file.etcd-service, shell_script.control-planes-playbook]
}
