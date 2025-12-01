#!/bin/bash
set -e

# Script to configure domain-specific Kubernetes resources from secrets
# This script reads the DOMAIN from secrets.yaml and substitutes it into manifests
# It works directly with the committed files and generates temporary versions

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
    ADMIN_EMAIL=$(sops -d "$K8S_DIR/secrets.yaml" | grep "^\s*ADMIN_EMAIL:" | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
    MAIL_USERNAME=$(sops -d "$K8S_DIR/secrets.yaml" | grep "^\s*MAIL_USERNAME:" | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
else
    DOMAIN=$(grep "^\s*DOMAIN:" "$K8S_DIR/secrets.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")
    ADMIN_EMAIL=$(grep "^\s*ADMIN_EMAIL:" "$K8S_DIR/secrets.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
    MAIL_USERNAME=$(grep "^\s*MAIL_USERNAME:" "$K8S_DIR/secrets.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
fi

# Determine email to use (prefer MAIL_USERNAME, fallback to ADMIN_EMAIL or construct from domain)
if [ -n "$MAIL_USERNAME" ]; then
    EMAIL="$MAIL_USERNAME"
elif [ -n "$ADMIN_EMAIL" ]; then
    EMAIL="$ADMIN_EMAIL"
else
    EMAIL="admin@${DOMAIN}"
fi

if [ -z "$DOMAIN" ]; then
    print_error "Could not extract DOMAIN from secrets.yaml"
    exit 1
fi

print_info "Domain: $DOMAIN"
print_info "Email: $EMAIL"

# Process manifests with placeholders
print_info "Generating domain-configured manifests..."

for file in ingress.yaml configmap.yaml livekit.yaml; do
    if [ -f "$K8S_DIR/$file" ]; then
        if grep -q "{{DOMAIN}}\|{{EMAIL}}" "$K8S_DIR/$file" 2>/dev/null; then
            print_info "Processing $file..."
            sed -e "s/{{DOMAIN}}/$DOMAIN/g" \
                -e "s/{{EMAIL}}/$EMAIL/g" \
                "$K8S_DIR/$file" > "$K8S_DIR/${file%.yaml}.generated.yaml"
            print_info "✓ ${file%.yaml}.generated.yaml created"
        fi
    fi
done

echo ""
print_info "Domain configuration complete!"
echo ""
echo "Generated files (temporary, not in git):"
ls -1 "$K8S_DIR"/*.generated.yaml 2>/dev/null | sed 's/.*\//  - /' || echo "  (none)"
echo ""
echo "To apply:"
echo "  kubectl apply -f $K8S_DIR/*.generated.yaml"
echo "  kubectl apply -f $K8S_DIR/ --exclude='*.generated.yaml'"
echo ""
