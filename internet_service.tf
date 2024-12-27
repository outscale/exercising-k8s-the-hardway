resource "outscale_internet_service" "internet_service" {
  tags {
    key   = "name"
    value = "${var.cluster_name}"
  }
}

resource "outscale_internet_service_link" "internet_service_link" {
  internet_service_id = outscale_internet_service.internet_service.internet_service_id
  net_id              = outscale_net.net.net_id
}
