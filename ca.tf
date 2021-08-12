data "local_file" "ca-csr-json" {
  filename = "${path.module}/ca/ca-csr.json"
}


data "local_file" "ca-config" {
  filename = "${path.module}/ca/ca-config.json"
}

resource "shell_script" "ca" {
  lifecycle_commands {
    create = <<-EOF
        ../bin/cfssl gencert -initca ca-csr.json | ../bin/cfssljson -bare ca
    EOF
    read   = <<-EOF
        echo "{\"pem_b64\": \"$(cat ca.pem|base64)\",
               \"key_b64\": \"$(cat ca-key.pem|base64)\"}"
    EOF
    delete = "rm -f ca.pem ca-key.pem ca.csr"
  }
  working_directory = "${path.module}/ca"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, data.local_file.ca-csr-json, data.local_file.ca-config]
}
