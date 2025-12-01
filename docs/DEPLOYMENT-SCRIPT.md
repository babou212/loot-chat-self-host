# Automated Deployment Script Guide

The `deploy.sh` script automates the entire LootChat deployment process, from infrastructure provisioning to application deployment.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Basic Usage](#basic-usage)
- [Advanced Options](#advanced-options)
- [What the Script Does](#what-the-script-does)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

---

## Overview

The automated deployment script handles:

1. ✅ Prerequisites checking (terraform, kubectl, sops)
2. ✅ Infrastructure deployment with Terraform
3. ✅ Cluster initialization monitoring
4. ✅ Kubeconfig setup
5. ✅ LootChat application deployment in correct order
6. ✅ Deployment verification
7. ✅ Next steps guidance (DNS, SSL, etc.)

**Deployment Time:** 15-20 minutes (full deployment with infrastructure)

---

## Prerequisites

### Required Tools

```bash
# Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# kubectl
brew install kubectl    # macOS
# or follow https://kubernetes.io/docs/tasks/tools/

# SOPS (optional, only if using encrypted secrets)
brew install sops       # macOS
# or download from https://github.com/getsops/sops
```

### Required Configuration

1. **Terraform Configuration:**

   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   nano terraform.tfvars
   ```

   Required values:
   - `hcloud_token` - Your Hetzner Cloud API token
   - `ssh_public_key` - Your SSH public key

2. **Kubernetes Secrets:**

   ```bash
   cd k8s
   cp secrets.yaml.example secrets.yaml
   nano secrets.yaml
   ```

   Configure all required secrets (database passwords, JWT keys, API keys, etc.)

---

## Basic Usage

### Full Deployment (Infrastructure + Application)

```bash
./deploy.sh
```

This will:

1. Check all prerequisites
2. Apply Terraform configuration to create infrastructure
3. Wait for cluster initialization (~5-10 minutes)
4. Configure kubectl automatically
5. Deploy all LootChat services
6. Show deployment status and next steps

### Deploy Application Only

If you already have infrastructure running:

```bash
./deploy.sh --skip-terraform
```

This skips Terraform and deploys directly to your existing cluster.

---

## Advanced Options

```bash
./deploy.sh [OPTIONS]

OPTIONS:
    -h, --help              Show help message
    -s, --skip-terraform    Skip Terraform infrastructure deployment
    -w, --skip-wait         Skip waiting for cluster initialization
    -d, --domain DOMAIN     Specify domain name (optional)
    --sops                  Use SOPS to decrypt secrets
```

### Examples

**Deploy with SOPS-encrypted secrets:**

```bash
./deploy.sh --sops
```

**Deploy with custom domain:**

```bash
./deploy.sh --domain chat.example.com
```

**Skip cluster initialization wait:**

```bash
./deploy.sh --skip-wait
```

**Deploy only application (infrastructure exists):**

```bash
./deploy.sh --skip-terraform
```

**Combine multiple options:**

```bash
./deploy.sh --skip-terraform --sops --domain chat.example.com
```

---

## What the Script Does

### Phase 1: Prerequisites Check

```
Checking Prerequisites
- terraform: ✅ Found
- kubectl: ✅ Found
- sops: ✅ Found (if --sops flag used)
```

### Phase 2: Configuration Validation

```
Checking Terraform Configuration
- terraform.tfvars: ✅ Found

Checking Kubernetes Secrets
- secrets.yaml: ✅ Found
```

### Phase 3: Infrastructure Deployment

```text
Deploying Infrastructure with Terraform
- Initializing Terraform...
- Validating configuration...
- Planning changes...
- Applying configuration...
  
[Terraform output showing created resources]

✅ Infrastructure deployed!
   Control Plane IP: 135.181.xxx.xxx
   Load Balancer IP: 135.181.xxx.xxx
```

### Phase 4: Cluster Initialization

```text
Waiting for Kubernetes Cluster Initialization
- Cluster initialization takes 5-10 minutes...
- Checking if cluster is ready...
  Attempt 1/60... 2/60... 3/60...
  
✅ Cluster is ready!
```

### Phase 5: Kubeconfig Setup

```text
Setting up Kubeconfig
- Backing up existing kubeconfig...
- Downloading kubeconfig from control plane...
- Verifying cluster connection...

Kubernetes control plane is running at https://...
✅ Kubeconfig configured successfully
```

### Phase 6: Application Deployment

```text
Deploying LootChat Application
- Creating namespace...
- Creating priority classes...
- Applying secrets...
- Applying configuration...
- Setting up storage...
- Deploying PostgreSQL...
- Deploying Redis...
- Deploying Kafka...
- Deploying MinIO...
- Deploying LiveKit...
- Waiting for infrastructure services...
- Deploying backend...
- Deploying frontend...
- Applying network policies...
- Configuring ingress...

✅ LootChat application deployed!
```

### Phase 7: Status Check

```text
Checking Deployment Status

Pods in lootchat namespace:
NAME                                READY   STATUS    RESTARTS
lootchat-backend-xxx                1/1     Running   0
lootchat-frontend-xxx               1/1     Running   0
postgres-0                          1/1     Running   0
redis-xxx                           1/1     Running   0
...

Services in lootchat namespace:
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP
lootchat-backend    ClusterIP   10.96.xxx.xxx   <none>
...

Ingress configuration:
NAME      CLASS   HOSTS              ADDRESS
lootchat  nginx   yourdomain.com     135.181.xxx.xxx
```

### Phase 8: Next Steps Guidance

```text
Deployment Complete!

Next Steps:

1. Configure DNS:
   Point your domain to: 135.181.xxx.xxx
   
   DNS A Records needed:
   - yourdomain.com → 135.181.xxx.xxx
   - minio.yourdomain.com → 135.181.xxx.xxx
   - livekit.yourdomain.com → 135.181.xxx.xxx
   - turn.yourdomain.com → 135.181.xxx.xxx

2. Wait for DNS propagation (5-10 minutes)
   Check with: dig yourdomain.com

3. Wait for SSL certificates (2-5 minutes after DNS)
   kubectl get certificate -n lootchat

4. Access your LootChat instance:
   https://yourdomain.com

5. Monitor deployment:
   kubectl get pods -n lootchat -w
   kubectl logs -n lootchat -l app=lootchat-backend -f
```

---

## Examples

### Example 1: First-Time Deployment

```bash
# Prepare configuration
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add Hetzner API token and SSH key

cd ../k8s
cp secrets.yaml.example secrets.yaml
nano secrets.yaml  # Configure all secrets

# Run automated deployment
cd ..
./deploy.sh

# Wait for completion (15-20 minutes)
# Configure DNS as instructed
# Access https://yourdomain.com
```

### Example 2: Update Deployment

If you need to update your application:

```bash
# Update secrets or configuration
nano k8s/secrets.yaml
nano k8s/configmap.yaml

# Redeploy application only
./deploy.sh --skip-terraform

# Monitor update
kubectl get pods -n lootchat -w
```

### Example 3: Secure Deployment with SOPS

```bash
# Setup SOPS (one-time)
gpg --full-generate-key
gpg --list-secret-keys --keyid-format LONG

# Configure SOPS
cd k8s
cp .sops.yaml.example .sops.yaml
nano .sops.yaml  # Add your GPG fingerprint

# Encrypt secrets
cp secrets.yaml.example secrets.yaml
nano secrets.yaml  # Configure values
sops -e -i secrets.yaml

# Deploy with SOPS
cd ..
./deploy.sh --sops
```

### Example 4: Development/Testing Workflow

```bash
# Initial deployment
./deploy.sh

# Make changes to application
# Update configuration
nano k8s/configmap.yaml

# Quick redeploy without waiting
./deploy.sh --skip-terraform --skip-wait

# Check logs
kubectl logs -n lootchat -l app=lootchat-backend --tail=100
```

---

## Troubleshooting

### Script Fails at Prerequisites Check

**Problem:** Missing tools (terraform, kubectl, sops)

**Solution:**

```bash
# macOS
brew install terraform kubectl sops

# Linux
# Follow installation guides:
# - https://www.terraform.io/downloads
# - https://kubernetes.io/docs/tasks/tools/
# - https://github.com/getsops/sops
```

### Terraform Configuration Not Found

**Problem:**

```text
[ERROR] terraform.tfvars not found!
```

**Solution:**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
# Add your hcloud_token and ssh_public_key
```

### Secrets Configuration Not Found

**Problem:**

```text
[ERROR] secrets.yaml not found!
```

**Solution:**

```bash
cd k8s
cp secrets.yaml.example secrets.yaml
nano secrets.yaml
# Configure all required secrets
```

### Cluster Initialization Timeout

**Problem:**

```text
[ERROR] Cluster initialization timeout
```

**Solution:**

```bash
# Check initialization manually
cd terraform
CONTROL_PLANE_IP=$(terraform output -raw control_plane_public_ip)
ssh root@$CONTROL_PLANE_IP "tail -f /var/log/cloud-init-output.log"

# Wait for initialization to complete, then run:
./deploy.sh --skip-terraform --skip-wait
```

### kubectl Not Configured

**Problem:**

```text
[ERROR] kubectl is not configured!
```

**Solution:**

```bash
cd terraform
./setup-kubeconfig.sh

# Verify
kubectl get nodes
```

### SOPS Decryption Fails

**Problem:**

```text
Failed to decrypt secrets.yaml
```

**Solution:**

```bash
# Verify GPG key is available
gpg --list-secret-keys

# Check SOPS configuration
cat k8s/.sops.yaml

# Ensure secrets.yaml is encrypted with correct key
cd k8s
sops -d secrets.yaml  # Should decrypt successfully

# If not, re-encrypt:
sops -e -i secrets.yaml
```

### Pods Not Starting

**Problem:** Pods stuck in Pending or CrashLoopBackOff

**Solution:**

```bash
# Check pod status
kubectl get pods -n lootchat

# Check specific pod
kubectl describe pod <pod-name> -n lootchat
kubectl logs <pod-name> -n lootchat

# Common issues:
# 1. Storage not available - check PVCs
kubectl get pvc -n lootchat

# 2. Secrets not configured - check secrets
kubectl get secret -n lootchat
kubectl describe secret lootchat-secrets -n lootchat

# 3. Image pull issues - check events
kubectl get events -n lootchat --sort-by='.lastTimestamp'
```

### SSL Certificates Not Issuing

**Problem:** Certificates stuck in Pending

**Solution:**

```bash
# Check certificate status
kubectl get certificate -n lootchat
kubectl describe certificate lootchat-tls -n lootchat

# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager

# Verify DNS is configured correctly
dig yourdomain.com
dig minio.yourdomain.com

# Common issues:
# 1. DNS not propagated - wait 5-10 minutes
# 2. DNS pointing to wrong IP - update DNS records
# 3. Rate limited by Let's Encrypt - wait and retry
```

### Application Not Accessible

**Problem:** Cannot access <https://yourdomain.com>

**Solution:**

```bash
# 1. Check ingress
kubectl get ingress -n lootchat
kubectl describe ingress lootchat -n lootchat

# 2. Verify DNS
dig yourdomain.com
# Should return Load Balancer IP

# 3. Check SSL certificate
kubectl get certificate -n lootchat
# Should show READY=True

# 4. Check backend service
kubectl get svc lootchat-backend -n lootchat
kubectl get endpoints lootchat-backend -n lootchat

# 5. Check backend logs
kubectl logs -n lootchat -l app=lootchat-backend --tail=100
```

---

## Advanced Usage

### Customize Deployment Order

If you need to customize the deployment process, you can modify the script or run commands manually:

```bash
# Deploy infrastructure
cd terraform
terraform init && terraform apply

# Wait for cluster
./wait-for-cluster.sh  # Custom script

# Setup kubectl
./setup-kubeconfig.sh

# Deploy services in custom order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/postgres.yaml
# ... etc
```

### Integration with CI/CD

The script can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Deploy LootChat
  env:
    HCLOUD_TOKEN: ${{ secrets.HCLOUD_TOKEN }}
  run: |
    ./deploy.sh --skip-wait --sops
```

### Multi-Environment Deployments

For multiple environments (staging, production):

```bash
# Use different tfvars files
./deploy.sh --tfvars=terraform/staging.tfvars

# Use different secrets
./deploy.sh --secrets=k8s/secrets-staging.yaml
```

---

## Additional Resources

- **Kubernetes Guide:** [docs/KUBERNETES.md](KUBERNETES.md)
- **Domain Setup:** [docs/DOMAIN-SETUP.md](DOMAIN-SETUP.md)
- **Configuration Reference:** [docs/CONFIGURATION.md](CONFIGURATION.md)
- **Troubleshooting Guide:** [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## Support

If you encounter issues not covered in this guide:

1. Check [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review logs: `kubectl logs -n lootchat <pod-name>`
3. Check events: `kubectl get events -n lootchat`
4. Open an issue on GitHub

---
