resource "outscale_public_ip" "kubernetes-lb" {}


resource "outscale_security_group" "kubernetes-lb" {
  description = "kube-apiserver load balancer (${var.cluster_name})"
  net_id      = outscale_net.net.net_id
}

resource "outscale_security_group_rule" "kubernetes-lb" {
  security_group_id = outscale_security_group.kubernetes-lb.security_group_id
  flow              = "Inbound"
  # kube-apiserver
  rules {
    from_port_range = "6443"
    to_port_range   = "6443"
    ip_protocol     = "tcp"
    ip_ranges       = ["0.0.0.0/0"]
  }
}

resource "outscale_load_balancer" "kubernetes-lb" {
  load_balancer_name = "kubernetes-lb"
  listeners {
    backend_port           = 6443
    backend_protocol       = "TCP"
    load_balancer_protocol = "TCP"
    load_balancer_port     = 6443
  }
  subnets            = [outscale_subnet.control-planes.subnet_id]
  security_groups    = [outscale_security_group.kubernetes-lb.security_group_id]
  load_balancer_type = "internet-facing"
}

resource "outscale_load_balancer_vms" "kubernetes-lb-vms" {
  load_balancer_name = outscale_load_balancer.kubernetes-lb.load_balancer_name
  backend_vm_ids     = [for vm in outscale_vm.control-planes : format("%s", vm.vm_id)]
}

resource "outscale_load_balancer_attributes" "kubernetes-lb" {
  load_balancer_name = outscale_load_balancer.kubernetes-lb.load_balancer_name
  health_check {
    healthy_threshold   = 10
    check_interval      = 30
    path                = "/healthz"
    port                = 6443
    protocol            = "HTTPS"
    timeout             = 5
    unhealthy_threshold = 5
  }
}
