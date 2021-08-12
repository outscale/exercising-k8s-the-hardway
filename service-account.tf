data "local_file" "service-account-csr-json" {
  filename = "${path.root}/service-account/service-account-csr.json"
}

resource "shell_script" "service-account" {
  lifecycle_commands {
    create = <<-EOF
	../bin/cfssl gencert \
            -ca=../ca/ca.pem \
            -ca-key=../ca/ca-key.pem \
            -config=../ca/ca-config.json \
            -profile=kubernetes \
            service-account-csr.json \
            | ../bin/cfssljson -bare service-account
    EOF
    read   = <<-EOF
        echo "{\"pem_b64\": \"$(cat service-account.pem|base64)\",
               \"csr_b64\": \"$(cat service-account.csr|base64)\",
               \"key_b64\": \"$(cat service-account-key.pem|base64)\"}"
    EOF
    delete = <<-EOF
        rm -f service-account.pem
        rm -f service-account-key.pem
        rm -f service-account.csr
    EOF
  }
  working_directory = "${path.root}/service-account"
  depends_on        = [shell_script.cfssl, shell_script.cfssljson, shell_script.ca, data.local_file.ca-config, data.local_file.service-account-csr-json]
}
