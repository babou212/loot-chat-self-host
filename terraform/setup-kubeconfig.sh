#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}LootChat - Kubeconfig Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    echo -e "${RED}Error: main.tf not found${NC}"
    echo "Please run this script from the terraform directory"
    exit 1
fi

# Check if Terraform has been applied
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}Error: terraform.tfstate not found${NC}"
    echo ""
    echo "It looks like Terraform hasn't been applied yet."
    echo ""
    echo "Please run the following commands first:"
    echo -e "${YELLOW}  terraform init${NC}"
    echo -e "${YELLOW}  terraform apply${NC}"
    echo ""
    echo "After the infrastructure is created, run this script again."
    exit 1
fi

# Get control plane IP from Terraform
CONTROL_PLANE_IP=$(terraform output -raw control_plane_public_ip 2>/dev/null)

if [ -z "$CONTROL_PLANE_IP" ]; then
    echo -e "${RED}Error: Could not get control plane IP from Terraform${NC}"
    echo "Make sure you've run 'terraform apply' first"
    exit 1
fi

echo -e "${GREEN}Control Plane IP: ${CONTROL_PLANE_IP}${NC}"
echo ""

# Check if cluster is ready
echo -e "${YELLOW}Checking if Kubernetes cluster is ready...${NC}"
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${CONTROL_PLANE_IP} "test -f /etc/kubernetes/admin.conf" 2>/dev/null; then
    echo -e "${GREEN}✓ Cluster is ready!${NC}"
else
    echo -e "${RED}✗ Cluster not ready yet${NC}"
    echo ""
    echo "The cluster is still initializing. This typically takes 5-10 minutes."
    echo ""
    read -p "Do you want to watch the initialization logs? (y/n): " WATCH
    if [[ $WATCH == "y" || $WATCH == "Y" ]]; then
        echo ""
        echo -e "${BLUE}Watching cluster initialization (Ctrl+C to exit)...${NC}"
        ssh -o StrictHostKeyChecking=no root@${CONTROL_PLANE_IP} "tail -f /var/log/cloud-init-output.log"
    fi
    exit 0
fi

# Backup existing kubeconfig if it exists
if [ -f ~/.kube/config ]; then
    BACKUP_FILE=~/.kube/config.backup.$(date +%Y%m%d-%H%M%S)
    echo -e "${YELLOW}Backing up existing kubeconfig to ${BACKUP_FILE}${NC}"
    cp ~/.kube/config "$BACKUP_FILE"
fi

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Download kubeconfig
echo -e "${YELLOW}Downloading kubeconfig from control plane...${NC}"
scp -o StrictHostKeyChecking=no root@${CONTROL_PLANE_IP}:/etc/kubernetes/admin.conf ~/.kube/config

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Kubeconfig downloaded successfully!${NC}"
    
    # Fix permissions
    chmod 600 ~/.kube/config
    
    echo ""
    echo -e "${BLUE}Testing cluster connection...${NC}"
    
    # Test connection
    if kubectl cluster-info &>/dev/null; then
        echo -e "${GREEN}✓ Successfully connected to cluster!${NC}"
        echo ""
        
        # Show nodes
        echo -e "${BLUE}=== Cluster Nodes ===${NC}"
        kubectl get nodes
        
        echo ""
        echo -e "${BLUE}=== Kubernetes Version ===${NC}"
        kubectl version --short
        
        echo ""
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}Setup Complete!${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo ""
        echo "You can now deploy LootChat:"
        echo "  cd ../k8s"
        echo "  kubectl apply -k ."
        echo ""
    else
        echo -e "${RED}✗ Could not connect to cluster${NC}"
        echo "The kubeconfig was downloaded but connection failed."
        echo "This might be a temporary network issue."
        exit 1
    fi
else
    echo -e "${RED}✗ Failed to download kubeconfig${NC}"
    echo "Make sure you can SSH to the control plane:"
    echo "  ssh root@${CONTROL_PLANE_IP}"
    exit 1
fi
