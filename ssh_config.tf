resource "local_file" "ssh_config" {
  filename        = "${path.root}/ssh_config"
  file_permission = "0660"
  content = format("%s\n\n%s\n",
    join("\n\n", [for eip in outscale_public_ip.control-planes : format("Host control-plane-%s\n     HostName %s\n     User outscale\n     IdentityFile control-planes/control-plane-%s.pem\n     IdentitiesOnly yes\n     UserKnownHostsFile known_hosts\n     StrictHostKeyChecking accept-new", index(outscale_public_ip.control-planes, eip), eip.public_ip, index(outscale_public_ip.control-planes, eip))]),
    join("\n\n", [for i in range(var.worker_count) : format("Host worker-%d\n     HostName 10.0.1.%d\n     ProxyJump control-plane-%d\n     User outscale\n     IdentityFile workers/worker-%s.pem\n     IdentitiesOnly yes\n     UserKnownHostsFile known_hosts\n     StrictHostKeyChecking accept-new", i, 10 + i, i % var.control_plane_count, i)])
  )
}


resource "shell_script" "known_hosts" {
  lifecycle_commands {
    create = <<-EOF
        touch known_hosts
    EOF
    read   = <<-EOF
        echo "{}"
    EOF
    delete = <<-EOF
        rm -f known_hosts
    EOF
  }
  depends_on = [local_file.ssh_config]
}
