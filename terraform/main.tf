terraform {
  required_version = ">= 1.0"
  
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# SSH Key for server access
resource "hcloud_ssh_key" "default" {
  name       = "${var.cluster_name}-ssh-key"
  public_key = var.ssh_public_key
}

# Private network for the cluster
resource "hcloud_network" "cluster_network" {
  name     = "${var.cluster_name}-network"
  ip_range = var.network_cidr
}

resource "hcloud_network_subnet" "cluster_subnet" {
  network_id   = hcloud_network.cluster_network.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_cidr
}

# Placement groups for better distribution
resource "hcloud_placement_group" "control_plane" {
  name = "${var.cluster_name}-control-plane"
  type = "spread"
}

resource "hcloud_placement_group" "workers" {
  name = "${var.cluster_name}-workers"
  type = "spread"
}

# Firewall for control plane
resource "hcloud_firewall" "control_plane" {
  name = "${var.cluster_name}-control-plane-fw"

  # SSH access
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = var.allowed_ssh_ips
  }

  # Kubernetes API
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow all traffic within the cluster
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "any"
    source_ips = [var.network_cidr]
  }

  rule {
    direction = "in"
    protocol  = "udp"
    port      = "any"
    source_ips = [var.network_cidr]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [var.network_cidr]
  }
}

# Firewall for worker nodes
resource "hcloud_firewall" "workers" {
  name = "${var.cluster_name}-workers-fw"

  # SSH access
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = var.allowed_ssh_ips
  }

  # HTTP/HTTPS for ingress
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # NodePort range
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "30000-32767"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # TURNS (TURN over TLS)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "5349"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # TURN relay ports for media (UDP range for WebRTC media relay)
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "49152-65535"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow all traffic within the cluster
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "any"
    source_ips = [var.network_cidr]
  }

  rule {
    direction = "in"
    protocol  = "udp"
    port      = "any"
    source_ips = [var.network_cidr]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [var.network_cidr]
  }
}

# Control plane (master) server
resource "hcloud_server" "control_plane" {
  name               = "${var.cluster_name}-master"
  server_type        = var.control_plane_server_type
  image              = var.server_image
  location           = var.location
  ssh_keys           = [hcloud_ssh_key.default.id]
  placement_group_id = hcloud_placement_group.control_plane.id
  firewall_ids       = [hcloud_firewall.control_plane.id]

  labels = {
    cluster = var.cluster_name
    role    = "control-plane"
  }

  user_data = templatefile("${path.module}/templates/control-plane-init.sh", {
    kubernetes_version = var.kubernetes_version
    pod_network_cidr   = var.pod_network_cidr
    cluster_name       = var.cluster_name
    server_arch        = "arm64"
  })

  network {
    network_id = hcloud_network.cluster_network.id
    ip         = cidrhost(var.subnet_cidr, 10)
  }

  depends_on = [
    hcloud_network_subnet.cluster_subnet
  ]
}

# Worker nodes
resource "hcloud_server" "workers" {
  count = var.worker_count

  name               = "${var.cluster_name}-worker-${count.index + 1}"
  server_type        = var.worker_server_type
  image              = var.server_image
  location           = var.location
  ssh_keys           = [hcloud_ssh_key.default.id]
  placement_group_id = hcloud_placement_group.workers.id
  firewall_ids       = [hcloud_firewall.workers.id]

  labels = {
    cluster = var.cluster_name
    role    = "worker"
  }

  user_data = templatefile("${path.module}/templates/worker-init.sh", {
    kubernetes_version = var.kubernetes_version
    control_plane_ip   = cidrhost(var.subnet_cidr, 10)
    server_arch        = "arm64"
  })

  network {
    network_id = hcloud_network.cluster_network.id
    ip         = cidrhost(var.subnet_cidr, 20 + count.index)
  }

  depends_on = [
    hcloud_network_subnet.cluster_subnet,
    hcloud_server.control_plane
  ]
}

# Load balancer for ingress traffic
resource "hcloud_load_balancer" "ingress" {
  name               = "${var.cluster_name}-ingress-lb"
  load_balancer_type = var.load_balancer_type
  location           = var.location

  labels = {
    cluster = var.cluster_name
    purpose = "ingress"
  }
}

resource "hcloud_load_balancer_network" "ingress" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  network_id       = hcloud_network.cluster_network.id
  ip               = cidrhost(var.subnet_cidr, 5)

  depends_on = [
    hcloud_network_subnet.cluster_subnet
  ]
}

# HTTP service on load balancer
resource "hcloud_load_balancer_service" "http" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  protocol         = "http"
  listen_port      = 80
  destination_port = 31315  # NodePort for ingress-nginx HTTP

  health_check {
    protocol = "http"
    port     = 31315  # Health check on NodePort
    interval = 15
    timeout  = 10
    retries  = 3
    http {
      path         = "/healthz"
      status_codes = ["2??", "3??"]
    }
  }
}

# HTTPS service on load balancer
resource "hcloud_load_balancer_service" "https" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 30874  # NodePort for ingress-nginx HTTPS

  health_check {
    protocol = "tcp"
    port     = 30874  # Health check on NodePort
    interval = 15
    timeout  = 10
    retries  = 3
  }
}

# Attach worker nodes to load balancer
resource "hcloud_load_balancer_target" "workers" {
  count = var.worker_count

  type             = "server"
  load_balancer_id = hcloud_load_balancer.ingress.id
  server_id        = hcloud_server.workers[count.index].id
  use_private_ip   = true

  depends_on = [
    hcloud_load_balancer_network.ingress
  ]
}
