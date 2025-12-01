#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
K8S_DIR="$SCRIPT_DIR/k8s"

# Configuration
SKIP_TERRAFORM=false
SKIP_WAIT=false
DOMAIN=""
USE_SOPS=false

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing=()
    
    if ! command -v terraform &> /dev/null; then
        missing+=("terraform")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi
    
    if [[ "$USE_SOPS" == "true" ]] && ! command -v sops &> /dev/null; then
        missing+=("sops")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Install missing tools:"
        for tool in "${missing[@]}"; do
            case $tool in
                terraform)
                    echo "  terraform: https://www.terraform.io/downloads"
                    ;;
                kubectl)
                    echo "  kubectl: https://kubernetes.io/docs/tasks/tools/"
                    ;;
                sops)
                    echo "  sops: brew install sops (macOS) or https://github.com/getsops/sops"
                    ;;
            esac
        done
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to check Terraform configuration
check_terraform_config() {
    print_header "Checking Terraform Configuration"
    
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        print_error "terraform.tfvars not found!"
        echo ""
        echo "Create terraform.tfvars from example:"
        echo "  cd $TERRAFORM_DIR"
        echo "  cp terraform.tfvars.example terraform.tfvars"
        echo "  nano terraform.tfvars"
        echo ""
        echo "Required values:"
        echo "  - hcloud_token"
        echo "  - ssh_public_key"
        exit 1
    fi
    
    print_success "Terraform configuration found"
}

# Function to check Kubernetes secrets
check_k8s_secrets() {
    print_header "Checking Kubernetes Secrets Configuration"
    
    if [ ! -f "$K8S_DIR/secrets.yaml" ]; then
        print_error "secrets.yaml not found!"
        echo ""
        echo "Create secrets.yaml from example:"
        echo "  cd $K8S_DIR"
        echo "  cp secrets.yaml.example secrets.yaml"
        
        if [[ "$USE_SOPS" == "true" ]]; then
            echo "  nano secrets.yaml  # Edit with your values"
            echo "  sops -e -i secrets.yaml  # Encrypt with SOPS"
        else
            echo "  nano secrets.yaml  # Edit with your values"
        fi
        
        echo ""
        exit 1
    fi
    
    print_success "Kubernetes secrets configuration found"
}

# Function to apply Terraform
apply_terraform() {
    print_header "Deploying Infrastructure with Terraform"
    
    cd "$TERRAFORM_DIR"
    
    print_info "Initializing Terraform..."
    terraform init
    
    print_info "Validating Terraform configuration..."
    terraform validate
    
    print_info "Planning infrastructure changes..."
    terraform plan -out=tfplan
    
    echo ""
    read -p "$(echo -e ${YELLOW}Apply Terraform plan? [y/N]:${NC} )" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Terraform deployment cancelled"
        exit 0
    fi
    
    print_info "Applying Terraform configuration..."
    terraform apply tfplan
    
    print_success "Infrastructure deployed successfully!"
    
    # Get outputs
    CONTROL_PLANE_IP=$(terraform output -raw control_plane_public_ip)
    LOAD_BALANCER_IP=$(terraform output -raw load_balancer_ip)
    
    echo ""
    print_info "Control Plane IP: $CONTROL_PLANE_IP"
    print_info "Load Balancer IP: $LOAD_BALANCER_IP"
    
    cd "$SCRIPT_DIR"
}

# Function to wait for cluster initialization
wait_for_cluster() {
    print_header "Waiting for Kubernetes Cluster Initialization"
    
    cd "$TERRAFORM_DIR"
    CONTROL_PLANE_IP=$(terraform output -raw control_plane_public_ip)
    cd "$SCRIPT_DIR"
    
    print_info "Cluster initialization takes 5-10 minutes..."
    print_info "Checking if cluster is ready..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${CONTROL_PLANE_IP} "test -f /etc/kubernetes/admin.conf" 2>/dev/null; then
            print_success "Cluster is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -ne "\r  Attempt $attempt/$max_attempts..."
        sleep 10
    done
    
    echo ""
    print_error "Cluster initialization timeout"
    echo ""
    echo "You can monitor the initialization manually:"
    echo "  ssh root@${CONTROL_PLANE_IP} \"tail -f /var/log/cloud-init-output.log\""
    exit 1
}

# Function to setup kubeconfig
setup_kubeconfig() {
    print_header "Setting up Kubeconfig"
    
    cd "$TERRAFORM_DIR"
    
    if [ -f "./setup-kubeconfig.sh" ]; then
        chmod +x ./setup-kubeconfig.sh
        ./setup-kubeconfig.sh
    else
        CONTROL_PLANE_IP=$(terraform output -raw control_plane_public_ip)
        
        # Backup existing kubeconfig
        if [ -f ~/.kube/config ]; then
            BACKUP_FILE=~/.kube/config.backup.$(date +%Y%m%d-%H%M%S)
            print_info "Backing up existing kubeconfig to $BACKUP_FILE"
            cp ~/.kube/config "$BACKUP_FILE"
        fi
        
        # Create .kube directory
        mkdir -p ~/.kube
        
        print_info "Downloading kubeconfig from control plane..."
        scp -o StrictHostKeyChecking=no root@${CONTROL_PLANE_IP}:/etc/kubernetes/admin.conf ~/.kube/config
        chmod 600 ~/.kube/config
    fi
    
    cd "$SCRIPT_DIR"
    
    print_success "Kubeconfig configured successfully"
    
    # Verify connection
    print_info "Verifying cluster connection..."
    kubectl cluster-info
    echo ""
    kubectl get nodes
}

# Function to deploy LootChat
deploy_lootchat() {
    print_header "Deploying LootChat Application"
    
    cd "$K8S_DIR"
    
    # Configure domain-specific resources
    print_info "Configuring domain-specific resources..."
    if [ -f "configure-domain.sh" ]; then
        chmod +x configure-domain.sh
        if [[ "$USE_SOPS" == "true" ]]; then
            ./configure-domain.sh --sops
        else
            ./configure-domain.sh
        fi
    else
        print_warning "configure-domain.sh not found, skipping domain configuration"
    fi
    
    # Apply namespace first
    if [ -f "namespace.yaml" ]; then
        print_info "Creating namespace..."
        kubectl apply -f namespace.yaml
    fi
    
    # Apply priority classes
    if [ -f "priority-classes.yaml" ]; then
        print_info "Creating priority classes..."
        kubectl apply -f priority-classes.yaml
    fi
    
    # Apply secrets
    print_info "Applying secrets..."
    if [[ "$USE_SOPS" == "true" ]]; then
        sops -d secrets.yaml | kubectl apply -f -
    else
        kubectl apply -f secrets.yaml
    fi
    
    # Apply configmap (use generated version if available)
    if [ -f "configmap.generated.yaml" ]; then
        print_info "Applying configuration (domain-configured)..."
        kubectl apply -f configmap.generated.yaml
    elif [ -f "configmap.yaml" ]; then
        print_info "Applying configuration..."
        kubectl apply -f configmap.yaml
    fi
    
    # Apply storage
    print_info "Setting up storage..."
    if [ -f "pvcs.yaml" ]; then
        kubectl apply -f pvcs.yaml
    fi
    
    # Apply database
    print_info "Deploying PostgreSQL..."
    if [ -f "postgres.yaml" ]; then
        kubectl apply -f postgres.yaml
    fi
    
    # Apply Redis
    print_info "Deploying Redis..."
    if [ -f "redis.yaml" ]; then
        kubectl apply -f redis.yaml
    fi
    
    # Apply Kafka
    print_info "Deploying Kafka..."
    if [ -f "kafka.yaml" ]; then
        kubectl apply -f kafka.yaml
    fi
    
    # Apply MinIO
    print_info "Deploying MinIO..."
    if [ -f "minio.yaml" ]; then
        kubectl apply -f minio.yaml
    fi
    
    # Apply LiveKit
    print_info "Deploying LiveKit..."
    if [ -f "livekit.yaml" ]; then
        kubectl apply -f livekit.yaml
    fi
    
    # Wait for infrastructure services
    print_info "Waiting for infrastructure services to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n lootchat --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=redis -n lootchat --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=kafka -n lootchat --timeout=300s || true
    
    # Apply backend
    print_info "Deploying backend..."
    if [ -f "backend.yaml" ]; then
        kubectl apply -f backend.yaml
    fi
    
    # Apply frontend
    print_info "Deploying frontend..."
    if [ -f "frontend.yaml" ]; then
        kubectl apply -f frontend.yaml
    fi
    
    # Apply network policies
    print_info "Applying network policies..."
    kubectl apply -f networkpolicy-*.yaml 2>/dev/null || true
    
    # Apply ingress (use generated version if available)
    print_info "Configuring ingress..."
    if [ -f "ingress.generated.yaml" ]; then
        print_info "Applying ingress (domain-configured)..."
        kubectl apply -f ingress.generated.yaml
    elif [ -f "ingress.yaml" ]; then
        kubectl apply -f ingress.yaml
    fi
    
    cd "$SCRIPT_DIR"
    
    print_success "LootChat application deployed!"
}

# Function to check deployment status
check_deployment_status() {
    print_header "Checking Deployment Status"
    
    print_info "Pods in lootchat namespace:"
    kubectl get pods -n lootchat
    
    echo ""
    print_info "Services in lootchat namespace:"
    kubectl get svc -n lootchat
    
    echo ""
    print_info "Ingress configuration:"
    kubectl get ingress -n lootchat
    
    echo ""
    print_info "Certificates:"
    kubectl get certificate -n lootchat
}

# Function to show next steps
show_next_steps() {
    print_header "Deployment Complete!"
    
    cd "$TERRAFORM_DIR"
    LOAD_BALANCER_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "N/A")
    cd "$SCRIPT_DIR"
    
    echo ""
    print_success "LootChat has been deployed successfully!"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Configure DNS:"
    echo "   Point your domain to: $LOAD_BALANCER_IP"
    echo ""
    if [ -n "$DOMAIN" ]; then
        echo "   DNS A Records needed:"
        echo "   - $DOMAIN → $LOAD_BALANCER_IP"
        echo "   - minio.$DOMAIN → $LOAD_BALANCER_IP"
        echo "   - livekit.$DOMAIN → $LOAD_BALANCER_IP"
        echo "   - turn.$DOMAIN → $LOAD_BALANCER_IP"
    else
        echo "   DNS A Records needed:"
        echo "   - yourdomain.com → $LOAD_BALANCER_IP"
        echo "   - minio.yourdomain.com → $LOAD_BALANCER_IP"
        echo "   - livekit.yourdomain.com → $LOAD_BALANCER_IP"
        echo "   - turn.yourdomain.com → $LOAD_BALANCER_IP"
    fi
    echo ""
    echo "2. Wait for DNS propagation (5-10 minutes)"
    echo "   Check with: dig yourdomain.com"
    echo ""
    echo "3. Wait for SSL certificates (2-5 minutes after DNS)"
    echo "   kubectl get certificate -n lootchat"
    echo ""
    echo "4. Access your LootChat instance:"
    if [ -n "$DOMAIN" ]; then
        echo "   https://$DOMAIN"
    else
        echo "   https://yourdomain.com"
    fi
    echo ""
    echo "5. Monitor deployment:"
    echo "   kubectl get pods -n lootchat -w"
    echo "   kubectl logs -n lootchat -l app=lootchat-backend -f"
    echo ""
    echo "For more information, see:"
    echo "  - docs/KUBERNETES.md"
    echo "  - docs/DOMAIN-SETUP.md"
    echo "  - docs/TROUBLESHOOTING.md"
    echo ""
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automated deployment script for LootChat on Kubernetes with Terraform

OPTIONS:
    -h, --help              Show this help message
    -s, --skip-terraform    Skip Terraform infrastructure deployment
    -w, --skip-wait         Skip waiting for cluster initialization
    -d, --domain DOMAIN     Specify domain name (optional)
    --sops                  Use SOPS to decrypt secrets

EXAMPLES:
    # Full deployment (infrastructure + application)
    $0

    # Deploy only application (infrastructure already exists)
    $0 --skip-terraform

    # Deploy with SOPS-encrypted secrets
    $0 --sops

    # Deploy with custom domain
    $0 --domain example.com

    # Skip cluster initialization wait (if already initialized)
    $0 --skip-wait

PREREQUISITES:
    - terraform
    - kubectl
    - sops (if using --sops flag)
    - SSH access configured
    - terraform.tfvars configured in terraform/
    - secrets.yaml configured in k8s/

For more information:
    https://github.com/babou212/loot-chat-self-host

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -s|--skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        -w|--skip-wait)
            SKIP_WAIT=true
            shift
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        --sops)
            USE_SOPS=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_header "LootChat Automated Deployment"
    
    print_info "Starting automated deployment..."
    echo ""
    print_info "Configuration:"
    print_info "  Skip Terraform: $SKIP_TERRAFORM"
    print_info "  Skip Wait: $SKIP_WAIT"
    print_info "  Use SOPS: $USE_SOPS"
    [ -n "$DOMAIN" ] && print_info "  Domain: $DOMAIN"
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy infrastructure
    if [[ "$SKIP_TERRAFORM" == "false" ]]; then
        check_terraform_config
        apply_terraform
        
        if [[ "$SKIP_WAIT" == "false" ]]; then
            wait_for_cluster
        fi
        
        setup_kubeconfig
    else
        print_warning "Skipping Terraform deployment"
        
        # Verify kubectl is configured
        if ! kubectl cluster-info &>/dev/null; then
            print_error "kubectl is not configured!"
            echo ""
            echo "Configure kubectl manually:"
            echo "  cd terraform && ./setup-kubeconfig.sh"
            exit 1
        fi
        
        print_success "Using existing cluster"
        kubectl get nodes
    fi
    
    # Check Kubernetes configuration
    check_k8s_secrets
    
    # Deploy application
    deploy_lootchat
    
    # Wait for pods to start
    print_info "Waiting for pods to start..."
    sleep 10
    
    # Check deployment status
    check_deployment_status
    
    # Show next steps
    show_next_steps
}

# Run main function
main

exit 0
