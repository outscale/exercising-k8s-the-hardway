resource "local_file" "hosts" {
  filename        = "${path.root}/hosts"
  file_permission = "0660"
  content = format("%s\n\n%s\n%s\n",
    "127.0.0.1	localhost\n::1		localhost ip6-localhost ip6-loopback\nff02::1		ip6-allnodes\nff02::2		ip6-allrouters",
    join("\n", [for i in range(var.control_plane_count) : format("10.0.0.%d control-plane-%s", i+10, i)]),
    join("\n", [for i in range(var.worker_count) : format("10.0.1.%d worker-%s", i+10, i)]),
  )
}
