output "control_plane_public_ip" {
  description = "Public IP address of the control plane"
  value       = hcloud_server.control_plane.ipv4_address
}

output "control_plane_private_ip" {
  description = "Private IP address of the control plane"
  value       = tolist(hcloud_server.control_plane.network)[0].ip
}

output "worker_public_ips" {
  description = "Public IP addresses of worker nodes"
  value       = [for worker in hcloud_server.workers : worker.ipv4_address]
}

output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = [for worker in hcloud_server.workers : tolist(worker.network)[0].ip]
}

output "load_balancer_ip" {
  description = "Public IP address of the ingress load balancer"
  value       = hcloud_load_balancer.ingress.ipv4
}

output "network_id" {
  description = "ID of the private network"
  value       = hcloud_network.cluster_network.id
}

output "ssh_command_control_plane" {
  description = "SSH command to connect to control plane"
  value       = "ssh root@${hcloud_server.control_plane.ipv4_address}"
}

output "ssh_command_workers" {
  description = "SSH commands to connect to worker nodes"
  value       = [for worker in hcloud_server.workers : "ssh root@${worker.ipv4_address}"]
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig from control plane"
  value       = "scp root@${hcloud_server.control_plane.ipv4_address}:/etc/kubernetes/admin.conf ~/.kube/config"
}

output "dns_configuration" {
  description = "DNS A record to configure for your domain"
  value = {
    type  = "A"
    name  = "@"
    value = hcloud_load_balancer.ingress.ipv4
    ttl   = 300
  }
}

output "cluster_summary" {
  description = "Summary of the cluster configuration"
  value = {
    cluster_name         = var.cluster_name
    location             = var.location
    control_plane_ip     = hcloud_server.control_plane.ipv4_address
    worker_count         = var.worker_count
    load_balancer_ip     = hcloud_load_balancer.ingress.ipv4
    kubernetes_version   = var.kubernetes_version
  }
}

# Volume outputs removed - volumes managed by Kubernetes PVCs

output "next_steps" {
  description = "Next steps after infrastructure is created"
  value = <<-EOT
    
    ============================================
    Kubernetes Cluster Created Successfully!
    ============================================
    
    1. Wait for cluster initialization (5-10 minutes):
       ssh root@${hcloud_server.control_plane.ipv4_address} "tail -f /var/log/cloud-init-output.log"
    
    2. Download kubeconfig:
       scp root@${hcloud_server.control_plane.ipv4_address}:/etc/kubernetes/admin.conf ~/.kube/config
    
    3. Verify cluster is ready:
       kubectl get nodes
    
    4. Configure DNS A record:
       Point your domain to: ${hcloud_load_balancer.ingress.ipv4}
    
    5. Deploy LootChat:
       cd ../k8s
       kubectl apply -k .
    
    6. Worker Node IPs:
       ${join("\n       ", [for worker in hcloud_server.workers : worker.ipv4_address])}
    
    ============================================
  EOT
}
