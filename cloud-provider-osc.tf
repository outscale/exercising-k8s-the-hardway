resource "local_file" "cloud-provider-osc_secrets" {
  count           = var.with_cloud_provider ? 1 : 0
  filename        = "${path.root}/cloud-provider-osc/secrets.yaml"
  file_permission = "0660"
  content         = <<-EOF
apiVersion: v1
kind: Secret
metadata:
  name: osc-secret
  namespace: kube-system
stringData:
  key_id: ${var.access_key_id}
  access_key: ${var.secret_key_id}
  aws_default_region: AWS_DEFAULT_REGION
  aws_availability_zones: AWS_AVAILABILITY_ZONES
  osc_account_id: OSC_ACCOUNT_ID
  osc_account_iam: OSC_ACCOUNT_IAM
  osc_user_id: OSC_USER_ID
  osc_arn: OSC_ARN
EOF
}

resource "shell_script" "cloud-provider-osc-playbook" {
  count = var.with_cloud_provider ? 1 : 0
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook cloud-provider-osc/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook cloud-provider-osc/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat cloud-provider-osc/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check cloud-provider-osc/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.kubernetes-playbook, local_file.cloud-provider-osc_secrets]
}
