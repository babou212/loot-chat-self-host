# Domain Configuration Guide

This guide explains how to configure your domain for LootChat self-hosting.

## Overview

LootChat requires domain configuration for:

- **Main application**: `yourdomain.com`
- **MinIO (file storage)**: `minio.yourdomain.com`
- **LiveKit (voice/video)**: `livekit.yourdomain.com`
- **TURN server**: `turn.yourdomain.com`

## Quick Setup

### 1. DNS Configuration

Point your domain to your Kubernetes cluster load balancer:

```bash
# Get your load balancer IP
terraform output load_balancer_ip
# or
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Create these DNS A records:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | YOUR_LOAD_BALANCER_IP | 300 |
| A | minio | YOUR_LOAD_BALANCER_IP | 300 |
| A | livekit | YOUR_LOAD_BALANCER_IP | 300 |
| A | turn | YOUR_LOAD_BALANCER_IP | 300 |

**Example for domain `example.com` with IP `1.2.3.4`:**

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | 1.2.3.4 | 300 |
| A | minio | 1.2.3.4 | 300 |
| A | livekit | 1.2.3.4 | 300 |
| A | turn | 1.2.3.4 | 300 |

### 2. Update Configuration Files

You need to update your domain in several places:

#### ConfigMap (k8s/configmap.yaml)

```yaml
data:
  # Update these with your domain
  LIVEKIT_URL: "wss://livekit.yourdomain.com"
  LIVEKIT_PUBLIC_URL: "wss://livekit.yourdomain.com"
  MINIO_DOMAIN: "minio.yourdomain.com"
  MINIO_URL: "https://minio.yourdomain.com"
```

#### Secrets (k8s/secrets.yaml)

Using SOPS encryption:

```yaml
stringData:
  DOMAIN: yourdomain.com
  CORS_ALLOWED_ORIGINS: https://yourdomain.com
  APP_PUBLIC_BASE_URL: https://yourdomain.com
  NUXT_PUBLIC_API_URL: https://yourdomain.com
```

#### Ingress (k8s/ingress.yaml)

Update all three ingress resources:

1. **Main application ingress:**

```yaml
spec:
  tls:
    - hosts:
        - yourdomain.com  # Update this
      secretName: lootchat-tls
  rules:
    - host: yourdomain.com  # Update this
```

2. **MinIO ingress:**

```yaml
spec:
  tls:
    - hosts:
        - minio.yourdomain.com  # Update this
      secretName: minio-tls
  rules:
    - host: minio.yourdomain.com  # Update this
```

#### LiveKit (k8s/livekit.yaml)

```yaml
config:
  turn:
    domain: turn.yourdomain.com  # Update this
  
  tls:
    - turn.yourdomain.com  # Update this

# And in the ingress section:
spec:
  tls:
    - hosts:
        - livekit.yourdomain.com  # Update this
  rules:
    - host: livekit.yourdomain.com  # Update this
```

### 3. Apply Configuration

```bash
# Apply ConfigMap
kubectl apply -f k8s/configmap.yaml

# Apply Secrets (with SOPS)
sops -d k8s/secrets.yaml | kubectl apply -f -

# Apply Ingress
kubectl apply -f k8s/ingress.yaml

# Apply LiveKit
kubectl apply -f k8s/livekit.yaml

# Restart deployments to pick up changes
kubectl rollout restart deployment -n lootchat
```

## Using SOPS for Domain Configuration

### Why Use SOPS?

SOPS (Secrets OPerationS) allows you to:

- Encrypt sensitive configuration (including domain URLs)
- Commit encrypted secrets to git safely
- Enable GitOps workflows
- Share secrets securely with team members

### Setup SOPS

1. **Install SOPS:**

```bash
# macOS
brew install sops

# Linux
wget https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops
```

2. **Generate GPG key:**

```bash
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits
# Get your fingerprint:
gpg --list-keys
```

3. **Configure SOPS:**

```bash
# Copy example config
cp k8s/.sops.yaml.example k8s/.sops.yaml

# Edit and add your GPG fingerprint
nano k8s/.sops.yaml
```

Update `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: secrets\.yaml$
    encrypted_regex: ^(data|stringData)$
    pgp: YOUR_GPG_FINGERPRINT_HERE
```

4. **Create and encrypt secrets:**

```bash
# Copy template
cp k8s/secrets.yaml.example k8s/secrets.yaml

# Edit with your domain
nano k8s/secrets.yaml
```

Update secrets with your domain:

```yaml
stringData:
  DOMAIN: example.com
  CORS_ALLOWED_ORIGINS: https://example.com
  APP_PUBLIC_BASE_URL: https://example.com
  NUXT_PUBLIC_API_URL: https://example.com
```

Encrypt:

```bash
# Encrypt in place
sops -e -i k8s/secrets.yaml

# Now it's safe to commit!
git add k8s/secrets.yaml k8s/.sops.yaml
git commit -m "Add domain configuration"
```

5. **Use encrypted secrets:**

```bash
# View decrypted
sops -d k8s/secrets.yaml

# Edit (decrypts, opens editor, re-encrypts on save)
sops k8s/secrets.yaml

# Apply to Kubernetes
sops -d k8s/secrets.yaml | kubectl apply -f -
```

## Domain Configuration Examples

### Example 1: Simple Domain (example.com)

**DNS Records:**

```
example.com         A  1.2.3.4
minio.example.com   A  1.2.3.4
livekit.example.com A  1.2.3.4
turn.example.com    A  1.2.3.4
```

**Secrets:**

```yaml
DOMAIN: example.com
CORS_ALLOWED_ORIGINS: https://example.com
APP_PUBLIC_BASE_URL: https://example.com
NUXT_PUBLIC_API_URL: https://example.com
```

**ConfigMap:**

```yaml
LIVEKIT_URL: "wss://livekit.example.com"
LIVEKIT_PUBLIC_URL: "wss://livekit.example.com"
MINIO_DOMAIN: "minio.example.com"
MINIO_URL: "https://minio.example.com"
```

### Example 2: Subdomain (chat.example.com)

**DNS Records:**

```text
chat.example.com            A  1.2.3.4
minio.chat.example.com      A  1.2.3.4
livekit.chat.example.com    A  1.2.3.4
turn.chat.example.com       A  1.2.3.4
```

**Secrets:**

```yaml
DOMAIN: chat.example.com
CORS_ALLOWED_ORIGINS: https://chat.example.com
APP_PUBLIC_BASE_URL: https://chat.example.com
NUXT_PUBLIC_API_URL: https://chat.example.com
```

**ConfigMap:**

```yaml
LIVEKIT_URL: "wss://livekit.chat.example.com"
LIVEKIT_PUBLIC_URL: "wss://livekit.chat.example.com"
MINIO_DOMAIN: "minio.chat.example.com"
MINIO_URL: "https://minio.chat.example.com"
```

## SSL/TLS Certificates

Certificates are automatically managed by cert-manager using Let's Encrypt.

### Verify Certificates

```bash
# Check certificate status
kubectl get certificate -n lootchat

# View certificate details
kubectl describe certificate lootchat-tls -n lootchat
kubectl describe certificate minio-tls -n lootchat
kubectl describe certificate livekit-tls -n lootchat

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

### Certificate Renewal

Certificates auto-renew. If issues occur:

```bash
# Delete certificate to trigger renewal
kubectl delete certificate lootchat-tls -n lootchat

# Certificate will be recreated automatically
kubectl get certificate -n lootchat -w
```

## Testing

### 1. Test DNS Resolution

```bash
# Test each domain resolves
dig yourdomain.com
dig minio.yourdomain.com
dig livekit.yourdomain.com
dig turn.yourdomain.com

# Or use nslookup
nslookup yourdomain.com
```

### 2. Test HTTPS Access

```bash
# Test main application
curl -I https://yourdomain.com

# Test MinIO
curl -I https://minio.yourdomain.com

# Test LiveKit WebSocket
curl -I https://livekit.yourdomain.com
```

### 3. Test in Browser

1. Open `https://yourdomain.com`
2. Check for valid SSL certificate (no warnings)
3. Register/login
4. Test file upload (uses MinIO)
5. Test voice/video call (uses LiveKit)

## Troubleshooting

### DNS Not Propagating

```bash
# Check DNS propagation globally
https://dnschecker.org

# Flush local DNS cache
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

### Certificate Not Issuing

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate events
kubectl describe certificate lootchat-tls -n lootchat

# Common issues:
# - DNS not propagated yet (wait 5-10 minutes)
# - Rate limit hit (use staging issuer for testing)
# - Port 80 not accessible (required for HTTP-01 challenge)
```

### CORS Errors

```bash
# Verify CORS settings match your domain
kubectl get secret lootchat-secrets -n lootchat -o yaml

# Update if needed
sops k8s/secrets.yaml
# Change CORS_ALLOWED_ORIGINS to your domain
sops -d k8s/secrets.yaml | kubectl apply -f -

# Restart backend
kubectl rollout restart deployment lootchat-backend -n lootchat
```

### MinIO Not Accessible

```bash
# Check MinIO pods
kubectl get pods -n lootchat -l app=minio

# Check MinIO logs
kubectl logs -n lootchat -l app=minio

# Verify MinIO environment variables
kubectl describe pod -n lootchat -l app=minio | grep MINIO_
```

## Automation Script

Create a helper script `update-domain.sh`:

```bash
#!/bin/bash
set -e

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 example.com"
    exit 1
fi

echo "Updating LootChat configuration for domain: $DOMAIN"

# Update ConfigMap
sed -i "s/yourdomain\.com/$DOMAIN/g" k8s/configmap.yaml
echo "✓ Updated configmap.yaml"

# Update Ingress
sed -i "s/yourdomain\.com/$DOMAIN/g" k8s/ingress.yaml
echo "✓ Updated ingress.yaml"

# Update LiveKit
sed -i "s/yourdomain\.com/$DOMAIN/g" k8s/livekit.yaml
echo "✓ Updated livekit.yaml"

# Remind about secrets
echo ""
echo "⚠️  Don't forget to update k8s/secrets.yaml with:"
echo "  DOMAIN: $DOMAIN"
echo "  CORS_ALLOWED_ORIGINS: https://$DOMAIN"
echo "  APP_PUBLIC_BASE_URL: https://$DOMAIN"
echo "  NUXT_PUBLIC_API_URL: https://$DOMAIN"
echo ""
echo "Edit secrets:"
echo "  sops k8s/secrets.yaml"
echo ""
echo "Apply changes:"
echo "  kubectl apply -f k8s/configmap.yaml"
echo "  kubectl apply -f k8s/ingress.yaml"
echo "  kubectl apply -f k8s/livekit.yaml"
echo "  sops -d k8s/secrets.yaml | kubectl apply -f -"
echo "  kubectl rollout restart deployment -n lootchat"
```

Make it executable:

```bash
chmod +x update-domain.sh
```

Use it:

```bash
./update-domain.sh example.com
```

## Next Steps

After configuring your domain:

1. Test all functionality
2. Configure backups
4. Review security settings

## Support

For issues:

- Check [Troubleshooting Guide](TROUBLESHOOTING.md)
