resource "outscale_subnet" "control-planes" {
  net_id         = outscale_net.net.net_id
  ip_range       = "10.0.0.0/24"
  subregion_name = "${var.region}a"
}

resource "outscale_route_table" "control-planes" {
  net_id = outscale_net.net.net_id
}

resource "outscale_route" "control-planes-default" {
  destination_ip_range = "0.0.0.0/0"
  gateway_id           = outscale_internet_service.internet_service.internet_service_id
  route_table_id       = outscale_route_table.control-planes.route_table_id
}

resource "outscale_route_table_link" "control-planes" {
  subnet_id      = outscale_subnet.control-planes.subnet_id
  route_table_id = outscale_route_table.control-planes.route_table_id
}

resource "outscale_public_ip" "control-planes" {
  count = var.control_plane_count
}

resource "outscale_public_ip_link" "control-planes" {
  count     = var.control_plane_count
  vm_id     = outscale_vm.control-planes[count.index].vm_id
  public_ip = outscale_public_ip.control-planes[count.index].public_ip
}

resource "tls_private_key" "control-planes" {
  count     = var.control_plane_count
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "local_file" "control-planes-pem" {
  count           = var.control_plane_count
  filename        = "${path.module}/control-planes/control-plane-${count.index}.pem"
  content         = tls_private_key.control-planes[count.index].private_key_pem
  file_permission = "0600"
}

resource "outscale_keypair" "control-planes" {
  count      = var.control_plane_count
  public_key = tls_private_key.control-planes[count.index].public_key_openssh
}

resource "outscale_security_group" "control-plane" {
  description = "Kubernetes control-planes (${var.cluster_name})"
  net_id      = outscale_net.net.net_id
}

resource "outscale_security_group_rule" "control-plane-ssh" {
  flow              = "Inbound"
  security_group_id = outscale_security_group.control-plane.id
  rules {
    from_port_range = "22"
    to_port_range   = "22"
    ip_protocol     = "tcp"
    ip_ranges       = ["0.0.0.0/0"]
  }

  # etcd
  rules {
    from_port_range = "2379"
    to_port_range   = "2380"
    ip_protocol     = "tcp"
    ip_ranges       = ["10.0.0.0/24"]
  }

  # service node port range
  rules {
    from_port_range = "30000"
    to_port_range   = "32767"
    ip_protocol     = "tcp"
    ip_ranges       = ["0.0.0.0/0"]
  }

  # kube-apiserver
  rules {
    from_port_range = "6443"
    to_port_range   = "6443"
    ip_protocol     = "tcp"
    ip_ranges       = ["0.0.0.0/0"]
  }
}

resource "outscale_vm" "control-planes" {
  count              = var.control_plane_count
  image_id           = var.image_id
  vm_type            = var.control_plane_vm_type
  keypair_name       = outscale_keypair.control-planes[count.index].keypair_name
  security_group_ids = [outscale_security_group.control-plane.security_group_id]
  subnet_id          = outscale_subnet.control-planes.subnet_id
  private_ips        = [format("10.0.0.%d", 10 + count.index)]

  tags {
    key   = "osc.fcu.eip.auto-attach"
    value = outscale_public_ip.control-planes[count.index].public_ip
  }

  tags {
    key   = "name"
    value = "${var.cluster_name}-control-plane-${count.index}"
  }
}

resource "shell_script" "control-planes-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook control-planes/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook control-planes/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat control-planes/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check control-planes/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [outscale_public_ip_link.control-planes]
}
