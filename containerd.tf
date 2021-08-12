resource "shell_script" "containerd-bin" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin/containerd
        wget -q --https-only --timestamping "https://github.com/containerd/containerd/releases/download/v1.4.4/containerd-1.4.4-linux-amd64.tar.gz" -O containerd.tar.gz
        tar -xvf containerd.tar.gz -C bin/containerd
        mv bin/containerd/bin/* bin/containerd/
        rm -rf bin/containerd/bin containerd.tar.gz
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/containerd/*|base64)\"}"
    EOF
    delete = "rm -rf bin/containerd"
  }
}

resource "shell_script" "runc-bin" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p bin
        wget -q --https-only --timestamping "https://github.com/opencontainers/runc/releases/download/v1.0.0-rc93/runc.amd64" -O bin/runc
        chmod 660 bin/runc
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum bin/runc|base64)\"}"
    EOF
    delete = "rm -f bin/runc"
  }
}

resource "shell_script" "containerd-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook containerd/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook containerd/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat containerd/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check containerd/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.cni-playbook, shell_script.containerd-bin, shell_script.runc-bin]
}
