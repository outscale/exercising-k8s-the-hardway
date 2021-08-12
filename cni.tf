resource "local_file" "cni-bridge-conf" {
  count           = var.worker_count
  filename        = "${path.root}/cni/worker-${count.index}_10-bridge.conf"
  file_permission = "0660"
  content         = <<-EOF
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "10.200.${count.index}.0/24"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
}

resource "shell_script" "cni-bin" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin/cni
        wget -q --https-only --timestamping "https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz" -O cni.tgz
        tar -xvf cni.tgz -C bin/cni
        rm -f cni.tgz
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/cni/*|base64)\"}"
    EOF
    delete = "rm -rf bin/cni"
  }
}

resource "shell_script" "cni-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook cni/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook cni/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat cni/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check cni/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.workers-playbook, shell_script.cni-bin, local_file.cni-bridge-conf]
}
