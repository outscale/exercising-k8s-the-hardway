resource "outscale_subnet" "workers" {
  net_id         = outscale_net.net.net_id
  ip_range       = "10.0.1.0/24"
  subregion_name = "${var.region}a"
  tags {
    key   = "OscK8sClusterID/${var.cluster_name}"
    value = "owned"
  }
}

resource "outscale_route_table" "workers" {
  net_id = outscale_net.net.net_id
  tags {
    key   = "OscK8sClusterID/${var.cluster_name}"
    value = "owned"
  }
}

resource "outscale_route" "workers-default" {
  destination_ip_range = "0.0.0.0/0"
  nat_service_id       = outscale_nat_service.workers.nat_service_id
  route_table_id       = outscale_route_table.workers.route_table_id
}

resource "outscale_route" "worker-pods" {
  count                = var.worker_count
  destination_ip_range = "10.200.${count.index}.0/24"
  vm_id                = outscale_vm.workers[count.index].vm_id
  route_table_id       = outscale_route_table.workers.route_table_id
}

resource "outscale_route_table_link" "workers" {
  subnet_id      = outscale_subnet.workers.subnet_id
  route_table_id = outscale_route_table.workers.route_table_id
}

resource "tls_private_key" "workers" {
  count     = var.worker_count
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "local_file" "workers-pem" {
  count           = var.worker_count
  filename        = "${path.module}/workers/worker-${count.index}.pem"
  content         = tls_private_key.workers[count.index].private_key_pem
  file_permission = "0600"
}

resource "outscale_keypair" "workers" {
  count      = var.worker_count
  public_key = tls_private_key.workers[count.index].public_key_openssh
  keypair_name = "${var.cluster_name}-worker-${count.index}"
}

resource "outscale_security_group" "worker" {
  description = "Kubernetes workers (${var.cluster_name})"
  net_id      = outscale_net.net.net_id
  tags {
    key   = "OscK8sClusterID/${var.cluster_name}"
    value = "owned"
  }
  tags {
    key   = "name"
    value = "${var.cluster_name}-worker"
  }
}

resource "outscale_security_group_rule" "worker-ssh" {
  flow              = "Inbound"
  security_group_id = outscale_security_group.worker.id
  rules {
    from_port_range = "22"
    to_port_range   = "22"
    ip_protocol     = "tcp"
    ip_ranges       = ["0.0.0.0/0"]
  }
  rules {
    ip_protocol = "-1"
    ip_ranges   = ["10.0.0.0/16"]
  }
}

resource "outscale_public_ip" "workers-nat" {
    tags {
    key   = "name"
    value = "${var.cluster_name}-workers"
  }
}

resource "outscale_nat_service" "workers" {
  subnet_id    = outscale_subnet.control-planes.subnet_id
  public_ip_id = outscale_public_ip.workers-nat.id
}

resource "outscale_vm" "workers" {
  count              = var.worker_count
  image_id           = var.image_id
  vm_type            = var.worker_vm_type
  keypair_name       = outscale_keypair.workers[count.index].keypair_name
  security_group_ids = [outscale_security_group.worker.security_group_id]
  subnet_id          = outscale_subnet.workers.subnet_id
  private_ips        = [format("10.0.1.%d", 10 + count.index)]

  tags {
    key   = "name"
    value = "${var.cluster_name}-worker-${count.index}"
  }
  # A bug in metadata make cloud-init crash
  # this tag is only needed for CCM
  tags {
    key   = "OscK8sClusterID/${var.cluster_name}"
    value = "owned"
  }
  tags {
    key   = "OscK8sNodeName"
    value = "worker-${count.index}"
  }
}

resource "shell_script" "workers-playbook" {
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook workers/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook workers/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat workers/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check workers/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [outscale_vm.workers, local_file.hosts, local_file.ssh_config, outscale_public_ip_link.bastion]
}
