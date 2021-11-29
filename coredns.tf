resource "shell_script" "coredns-yaml" {
  lifecycle_commands {
    create = <<-EOF
        mkdir -p coredns
        wget -q --https-only --timestamping "https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.8.yaml" -O coredns/coredns-1.8.yaml
        sed -i "s%loadbalance%loadbalance\n\tforward . /etc/resolv%" coredns/coredns-1.8.yaml
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(md5sum coredns/coredns-1.8.yaml|base64)\"}"
    EOF
    delete = "rm -f coredns/coredns-1.8.yaml"
  }
}

resource "shell_script" "coredns-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook coredns/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook coredns/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat coredns/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check coredns/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.kube-scheduler-playbook, shell_script.kube-controller-manager-playbook, shell_script.coredns-yaml]
}
