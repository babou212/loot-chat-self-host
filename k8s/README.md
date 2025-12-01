# Kubernetes Manifests

This directory contains Kubernetes manifests for deploying LootChat.

## Template System

Some manifests use a template system to make domain configuration easy and dynamic:

### Template Files (Committed to Git)

- `ingress.yaml.template` - Ingress rules with `{{DOMAIN}}` placeholders
- `configmap.yaml.template` - ConfigMap with `{{DOMAIN}}` placeholders

### Generated Files (Not in Git)

- `ingress.yaml` - Generated from template with your actual domain
- `configmap.yaml` - Generated from template with your actual domain

## Quick Start

### Option 1: Automated (Recommended)

The `deploy.sh` script automatically configures domains:

```bash
# From repository root
./deploy.sh          # Without SOPS
./deploy.sh --sops   # With SOPS-encrypted secrets
```

### Option 2: Manual Configuration

```bash
# Configure domain from secrets
./configure-domain.sh          # Without SOPS
./configure-domain.sh --sops   # With SOPS-encrypted secrets

# Apply to cluster
kubectl apply -f namespace.yaml
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml
kubectl apply -f ingress.yaml
# ... apply other manifests
```

## How It Works

1. **Store domain in secrets.yaml**

   ```yaml
   stringData:
     DOMAIN: yourdomain.com
   ```

2. **Run configure-domain.sh**
   - Reads `DOMAIN` from `secrets.yaml`
   - Substitutes `{{DOMAIN}}` in templates
   - Generates `ingress.yaml` and `configmap.yaml`

3. **Apply to Kubernetes**

   ```bash
   kubectl apply -f .
   ```

## Domain Configuration

Your domain will be used for:

- **Main app**: `yourdomain.com`
- **MinIO**: `minio.yourdomain.com`
- **LiveKit**: `livekit.yourdomain.com`
- **TURN server**: `turn.yourdomain.com`

All these are configured automatically from your `DOMAIN` secret.

## Files Overview

### Static Manifests (No Domain Config Needed)

- `namespace.yaml` - Creates lootchat namespace
- `priority-classes.yaml` - Pod priority classes
- `pvcs.yaml` - Persistent volume claims
- `postgres.yaml` - PostgreSQL deployment
- `redis.yaml` - Redis deployment
- `kafka.yaml` - Kafka deployment
- `minio.yaml` - MinIO object storage
- `livekit.yaml` - LiveKit media server
- `backend.yaml` - LootChat backend deployment
- `frontend.yaml` - LootChat frontend deployment
- `networkpolicy-*.yaml` - Network security policies

### Template Manifests (Domain Configured)

- `ingress.yaml.template` → `ingress.yaml`
- `configmap.yaml.template` → `configmap.yaml`

### Secret Manifests

- `secrets.yaml.example` - Template for creating your secrets
- `secrets.yaml` - Your actual secrets (not in git)

## Changing Your Domain

1. Update `DOMAIN` in `k8s/secrets.yaml`
2. Run `./configure-domain.sh` (or `./configure-domain.sh --sops`)
3. Apply changes: `kubectl apply -f k8s/ingress.yaml -f k8s/configmap.yaml`
4. Update DNS records to point to your load balancer
5. Wait for SSL certificates to renew (automatic with cert-manager)

## SSL Certificates

Certificates are automatically issued by cert-manager using Let's Encrypt.

Check certificate status:

```bash
kubectl get certificate -n lootchat
```

## Troubleshooting

### Domain not configured

```
Error: invalid host "{{DOMAIN}}"
```

**Solution**: Run `./configure-domain.sh` to generate manifests from templates

### Wrong domain in ingress

**Solution**: Update `DOMAIN` in secrets.yaml and rerun `./configure-domain.sh`

### Certificates not issuing

**Solution**:

1. Verify DNS is pointing to load balancer IP
2. Check cert-manager logs: `kubectl logs -n cert-manager deploy/cert-manager`

## See Also

- [Deployment Script Guide](../docs/DEPLOYMENT-SCRIPT.md)
- [Domain Setup Guide](../docs/DOMAIN-SETUP.md)
- [Kubernetes Guide](../docs/KUBERNETES.md)
- [Configuration Reference](../docs/CONFIGURATION.md)
