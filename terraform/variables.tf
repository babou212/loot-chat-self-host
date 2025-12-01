variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "lootchat"
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location (fsn1, nbg1, hel1, ash, hil)"
  type        = string
  default     = "nbg1"
}

variable "network_zone" {
  description = "Hetzner Cloud network zone (eu-central, us-east, us-west)"
  type        = string
  default     = "eu-central"
}

variable "network_cidr" {
  description = "CIDR block for the private network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "pod_network_cidr" {
  description = "CIDR block for Kubernetes pod network"
  type        = string
  default     = "10.244.0.0/16"
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed to SSH to servers"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "server_image" {
  description = "Server OS image"
  type        = string
  default     = "ubuntu-22.04"
}

variable "control_plane_server_type" {
  description = "Server type for control plane node"
  type        = string
  default     = "cax21" # 4 vCPU ARM, 8 GB RAM, 80 GB SSD
}

variable "worker_server_type" {
  description = "Server type for worker nodes"
  type        = string
  default     = "cax11" # 2 vCPU ARM, 4 GB RAM, 40 GB SSD
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 4
}

variable "load_balancer_type" {
  description = "Load balancer type"
  type        = string
  default     = "lb11" # Up to 5,000 concurrent connections
}

variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.32.0"
}

variable "enable_ccm" {
  description = "Enable Hetzner Cloud Controller Manager"
  type        = bool
  default     = true
}

variable "enable_csi" {
  description = "Enable Hetzner Cloud CSI Driver"
  type        = bool
  default     = true
}
