resource "shell_script" "example-2048-playbook" {
  count = var.with_cloud_provider && var.with_example_2048 ? 1 : 0
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook example-2048/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook example-2048/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat cloud-provider-osc/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check example-2048/playbook.yaml|base64)\"
              }"
    EOF
    delete = "ANSIBLE_CONFIG=ansible.cfg ansible-playbook example-2048/playbook-destroy.yaml"
  }
  depends_on = [shell_script.cloud-provider-osc-playbook]
}
