#!/bin/bash
set -e

# Log everything
exec > >(tee -a /var/log/control-plane-init.log)
exec 2>&1

echo "=========================================="
echo "Initializing Kubernetes Control Plane"
echo "=========================================="
echo "Kubernetes Version: ${kubernetes_version}"
echo "Pod Network CIDR: ${pod_network_cidr}"
echo "Cluster Name: ${cluster_name}"
echo "Architecture: ${server_arch}"
echo "=========================================="

# Detect architecture
ARCH="${server_arch}"
if [ "$ARCH" = "arm64" ]; then
    echo "Using ARM64 architecture"
else
    ARCH="amd64"
    echo "Using AMD64 architecture"
fi

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install prerequisites
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    jq

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install Kubernetes packages
# Extract major.minor version from kubernetes_version
K8S_VERSION_MAJOR_MINOR=$(echo ${kubernetes_version} | cut -d. -f1,2)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION_MAJOR_MINOR/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION_MAJOR_MINOR/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=${kubernetes_version}-* kubeadm=${kubernetes_version}-* kubectl=${kubernetes_version}-*
apt-mark hold kubelet kubeadm kubectl

# Get private IP
PRIVATE_IP=$(hostname -I | awk '{print $2}')
echo "KUBELET_EXTRA_ARGS=--node-ip=$PRIVATE_IP" > /etc/default/kubelet

# Initialize Kubernetes cluster
echo "Initializing Kubernetes cluster..."
kubeadm init \
    --pod-network-cidr=${pod_network_cidr} \
    --apiserver-advertise-address=$PRIVATE_IP \
    --apiserver-cert-extra-sans=$(hostname -I | awk '{print $1}') \
    --node-name=$(hostname -s) \
    --service-cidr=10.96.0.0/12 \
    --kubernetes-version=${kubernetes_version}

# Configure kubectl for root user
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Install Flannel CNI
echo "Installing Flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Configure Flannel to use private network interface
echo "Configuring Flannel to use private network interface (enp7s0)..."
sleep 10  # Wait for DaemonSet to be created
kubectl patch ds -n kube-flannel kube-flannel-ds --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--iface=enp7s0"}]' || true

# Wait for control plane to be ready
echo "Waiting for control plane to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=300s || true

# Install Hetzner Cloud Controller Manager
echo "Installing Hetzner Cloud Controller Manager..."
kubectl -n kube-system create secret generic hcloud --from-literal=token=$HCLOUD_TOKEN --from-literal=network=NETWORK_ID || true

cat <<'EOF_CCM' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-controller-manager
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:cloud-controller-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: cloud-controller-manager
    namespace: kube-system
EOF_CCM

kubectl apply -f https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/latest/download/ccm-networks.yaml

# Install Hetzner CSI Driver
echo "Installing Hetzner CSI Driver..."
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/main/deploy/kubernetes/hcloud-csi.yml

# Install NGINX Ingress Controller
echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# Generate join command for workers EARLY so workers can join
echo "Generating worker join command..."
JOIN_COMMAND=$(kubeadm token create --print-join-command)
echo "$JOIN_COMMAND --apiserver-advertise-address=$PRIVATE_IP" > /root/join-command.sh
chmod +x /root/join-command.sh

# Save join command to a location workers can access
echo "$JOIN_COMMAND" > /tmp/join-command.txt

# Create a flag file to indicate initialization is complete - workers can join now
touch /root/.k8s-init-complete

echo "=========================================="
echo "Control plane is ready for worker nodes!"
echo "=========================================="

# Install cert-manager
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Wait for cert-manager to be ready (after workers have had a chance to join)
echo "Waiting for cert-manager..."
sleep 30
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager || true
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager || true
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager || true

echo "=========================================="
echo "Control Plane Initialization Complete!"
echo "=========================================="
echo "Cluster is ready for worker nodes to join"
echo "Join command saved to /root/join-command.sh"
echo ""
echo "To get kubeconfig:"
echo "  scp root@$(hostname -I | awk '{print $1}'):/etc/kubernetes/admin.conf ~/.kube/config"
echo ""
echo "To check cluster status:"
echo "  kubectl get nodes"
echo "=========================================="
