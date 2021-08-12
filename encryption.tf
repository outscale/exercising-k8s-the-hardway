resource "random_id" "encryption_key" {
  byte_length = 32
}

resource "local_file" "encryption_key" {
  filename = "${path.module}/encryption/encryption-config.yaml"
  content  = <<-EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${random_id.encryption_key.b64_std}
      - identity: {}
  EOF
}
