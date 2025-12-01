#!/bin/bash
set -e

# Script to configure domain-specific Kubernetes resources from secrets
# This script reads the DOMAIN from secrets.yaml and substitutes it into templates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR"
USE_SOPS=false

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sops)
            USE_SOPS=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Usage: $0 [--sops]"
            exit 1
            ;;
    esac
done

# Check if secrets.yaml exists
if [ ! -f "$K8S_DIR/secrets.yaml" ]; then
    print_error "secrets.yaml not found!"
    echo "Create it from secrets.yaml.example and configure your values"
    exit 1
fi

# Extract DOMAIN from secrets
print_info "Extracting domain from secrets..."
if [[ "$USE_SOPS" == "true" ]]; then
    if ! command -v sops &> /dev/null; then
        print_error "SOPS not found! Install it or run without --sops flag"
        exit 1
    fi
    DOMAIN=$(sops -d "$K8S_DIR/secrets.yaml" | grep "^\s*DOMAIN:" | awk '{print $2}' | tr -d '"' | tr -d "'")
    EMAIL=$(sops -d "$K8S_DIR/secrets.yaml" | grep "^\s*ADMIN_EMAIL:" | awk '{print $2}' | tr -d '"' | tr -d "'")
else
    DOMAIN=$(grep "^\s*DOMAIN:" "$K8S_DIR/secrets.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")
    EMAIL=$(grep "^\s*ADMIN_EMAIL:" "$K8S_DIR/secrets.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")
fi

# Fallback for email if not found
if [ -z "$EMAIL" ]; then
    EMAIL="admin@${DOMAIN}"
fi

if [ -z "$DOMAIN" ]; then
    print_error "Could not extract DOMAIN from secrets.yaml"
    exit 1
fi

print_info "Domain: $DOMAIN"
print_info "Email: $EMAIL"

# Process ingress.yaml
if [ -f "$K8S_DIR/ingress.yaml.template" ]; then
    print_info "Generating ingress.yaml from template..."
    sed -e "s/{{DOMAIN}}/$DOMAIN/g" \
        -e "s/{{EMAIL}}/$EMAIL/g" \
        "$K8S_DIR/ingress.yaml.template" > "$K8S_DIR/ingress.yaml"
    print_info "✓ ingress.yaml generated"
else
    print_error "ingress.yaml.template not found!"
    exit 1
fi

# Process configmap.yaml
if [ -f "$K8S_DIR/configmap.yaml.template" ]; then
    print_info "Generating configmap.yaml from template..."
    sed -e "s/{{DOMAIN}}/$DOMAIN/g" \
        "$K8S_DIR/configmap.yaml.template" > "$K8S_DIR/configmap.yaml"
    print_info "✓ configmap.yaml generated"
else
    print_error "configmap.yaml.template not found!"
    exit 1
fi

# Process livekit.yaml if it has templates
if [ -f "$K8S_DIR/livekit.yaml" ]; then
    if grep -q "{{DOMAIN}}" "$K8S_DIR/livekit.yaml" 2>/dev/null; then
        print_info "Updating livekit.yaml with domain..."
        sed -i.bak "s/{{DOMAIN}}/$DOMAIN/g" "$K8S_DIR/livekit.yaml"
        rm -f "$K8S_DIR/livekit.yaml.bak"
        print_info "✓ livekit.yaml updated"
    fi
fi

echo ""
print_info "Domain configuration complete!"
echo ""
echo "Generated files:"
echo "  - ingress.yaml (domain: $DOMAIN)"
echo "  - configmap.yaml (LiveKit: livekit.$DOMAIN, MinIO: minio.$DOMAIN)"
echo ""
echo "Next steps:"
echo "  1. Review the generated files"
echo "  2. Apply to Kubernetes: kubectl apply -f $K8S_DIR/"
echo ""
