# Kubernetes Deployment Guide

This guide provides step-by-step instructions for deploying LootChat to Kubernetes on Hetzner Cloud.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Hetzner Cloud account](https://console.hetzner.cloud/)
- Domain name with DNS management access
- SSH key pair

## Step 1: Get Hetzner API Token

1. Log into [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Select or create a project
3. Navigate to **Security → API Tokens**
4. Click **Generate API Token**
5. Name it (e.g., "LootChat Terraform")
6. Select **Read & Write** permissions
7. Copy the token (you won't see it again!)

## Step 2: Prepare SSH Key

Generate an SSH key if you don't have one:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

View your public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the output (starts with `ssh-ed25519 ...`).

## Step 3: Configure Terraform

Navigate to the terraform directory:

```bash
cd terraform
```

Copy the example configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```bash
nano terraform.tfvars
```

Update with your values:

```hcl
# Your Hetzner API token
hcloud_token = "YOUR_HETZNER_API_TOKEN"

# Your SSH public key
ssh_public_key = "ssh-ed25519 AAAAC3NzaC... your_email@example.com"

# Cluster name
cluster_name = "lootchat"

# Location (fsn1, nbg1, hel1, ash, hil)
location = "nbg1"

# Server configuration
control_plane_server_type = "cax21"  # 4 vCPU, 8GB RAM
worker_server_type = "cax11"          # 2 vCPU, 4GB RAM
worker_count = 4

# Kubernetes version
kubernetes_version = "1.32.0"
```

**Cost calculation:**

- Control plane: €10/month
- 4 workers: €16/month
- Load balancer: €5/month
- Storage: ~€3/month
- **Total: ~€34/month**

## Step 4: Deploy Infrastructure

Initialize Terraform:

```bash
terraform init
```

Preview the deployment plan:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

Type `yes` when prompted.

**This will create:**

- Private network
- Firewall rules
- 1 control plane server
- 4 worker servers
- Load balancer
- SSH keys

**Deployment takes ~5 minutes.**

## Step 5: Wait for Cluster Initialization

The servers will automatically install and configure Kubernetes. This takes **5-10 minutes**.

Get the control plane IP from Terraform output:

```bash
terraform output control_plane_public_ip
```

Monitor initialization progress:

```bash
ssh root@<control-plane-ip> "tail -f /var/log/cloud-init-output.log"
```

Wait for the message:

```
Control Plane Initialization Complete!
```

Press `Ctrl+C` to exit.

## Step 6: Download Kubeconfig

Use the provided script:

```bash
./setup-kubeconfig.sh
```

This will:

- Download kubeconfig from control plane
- Save to `~/.kube/config`
- Backup existing config if present
- Test connection

Verify cluster access:

```bash
kubectl get nodes
```

You should see 5 nodes (1 control plane + 4 workers) in `Ready` state.

## Step 7: Configure DNS

Get your load balancer IP:

```bash
terraform output load_balancer_ip
```

Create an A record in your DNS provider:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ or lootchat | <load-balancer-ip> | 300 |

**Examples:**

- **Cloudflare:** DNS → Add record → A
- **Namecheap:** Advanced DNS → Add record → A
- **GoDaddy:** DNS Management → Add → A

Wait for DNS propagation (usually < 5 minutes):

```bash
dig lootchat.yourdomain.com
# or
nslookup lootchat.yourdomain.com
```

## Step 8: Configure Application Secrets

Navigate to k8s directory:

```bash
cd ../k8s
```

Create secrets file from example:

```bash
cp secrets.yaml.example secrets.yaml
```

Edit secrets:

```bash
nano secrets.yaml
```

Update with your values:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: lootchat-secrets
  namespace: lootchat
type: Opaque
stringData:
  # Database
  POSTGRES_USER: lootchat
  POSTGRES_PASSWORD: <generate-strong-password>
  POSTGRES_DB: lootchat
  
  # JWT Secret (generate with: openssl rand -base64 32)
  JWT_SECRET: <generate-strong-secret>
  
  # Admin User
  ADMIN_USERNAME: admin
  ADMIN_EMAIL: admin@yourdomain.com
  ADMIN_PASSWORD: <generate-strong-password>
  
  # Email SMTP
  MAIL_HOST: smtp.gmail.com
  MAIL_PORT: "587"
  MAIL_USERNAME: your-email@gmail.com
  MAIL_PASSWORD: <your-app-password>
  
  # Session
  NUXT_SESSION_PASSWORD: <generate-with-openssl-rand-base64-32>
```

**Generate secrets:**

```bash
# JWT Secret
openssl rand -base64 32

# Session password
openssl rand -base64 32

# Strong password
openssl rand -base64 24
```

## Step 9: Update ConfigMap

Edit the ConfigMap:

```bash
nano configmap.yaml
```

Update domain and CORS:

```yaml
data:
  APP_URL: "https://lootchat.yourdomain.com"
  CORS_ALLOWED_ORIGINS: "https://lootchat.yourdomain.com"
```

## Step 10: Update Ingress

Edit ingress configuration:

```bash
nano ingress.yaml
```

Update host:

```yaml
spec:
  rules:
    - host: lootchat.yourdomain.com  # Your domain
      http:
        paths:
          - path: /
```

Update TLS:

```yaml
  tls:
    - hosts:
        - lootchat.yourdomain.com  # Your domain
      secretName: lootchat-tls
```

## Step 11: Deploy LootChat

Apply all Kubernetes manifests:

```bash
kubectl apply -k .
```

This will create:

- Namespace
- Secrets
- ConfigMaps
- Persistent Volume Claims
- Deployments (PostgreSQL, Redis, Kafka, MinIO, LiveKit, Backend, Frontend)
- Services
- Ingress
- Network Policies

## Step 12: Monitor Deployment

Watch pods starting:

```bash
kubectl get pods -n lootchat -w
```

Wait for all pods to show `Running` status.

Check specific service:

```bash
kubectl logs -n lootchat -l app=backend -f
kubectl logs -n lootchat -l app=frontend -f
```

## Step 13: Verify SSL Certificate

Cert-manager will automatically request a Let's Encrypt certificate.

Check certificate status:

```bash
kubectl get certificate -n lootchat
kubectl describe certificate lootchat-tls -n lootchat
```

Wait for `Ready=True` status (may take 2-5 minutes).

## Step 14: Access LootChat

Open your browser:

```text
https://lootchat.yourdomain.com
```

You should see the LootChat login page!

**First login:**

1. Click "Register" or use admin credentials from secrets
2. Check email for verification link
3. Complete registration
4. Start chatting!

## Post-Deployment

### Setup Backups

Create a backup CronJob for PostgreSQL:

```bash
kubectl apply -f k8s/postgres-backup-cronjob.yaml
```

## Maintenance

### View Logs

```bash
# All pods in namespace
kubectl logs -n lootchat -l app=backend

# Specific pod
kubectl logs -n lootchat <pod-name>

# Follow logs
kubectl logs -n lootchat <pod-name> -f
```

### Scale Services

```bash
# Scale backend replicas
kubectl scale deployment backend -n lootchat --replicas=3

# Scale frontend replicas
kubectl scale deployment frontend -n lootchat --replicas=2
```

### Update Configuration

```bash
# Edit ConfigMap
kubectl edit configmap lootchat-config -n lootchat

# Edit Secrets
kubectl edit secret lootchat-secrets -n lootchat

# Restart deployments to pick up changes
kubectl rollout restart deployment backend -n lootchat
kubectl rollout restart deployment frontend -n lootchat
```

### Check Resource Usage

```bash
kubectl top nodes
kubectl top pods -n lootchat
```

## Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n lootchat
kubectl logs <pod-name> -n lootchat
```

### Database Connection Issues

```bash
# Check PostgreSQL logs
kubectl logs -n lootchat -l app=postgres

# Test connection
kubectl exec -it -n lootchat <backend-pod> -- sh
psql -h postgres -U lootchat -d lootchat
```

### Ingress Not Working

```bash
# Check ingress
kubectl get ingress -n lootchat
kubectl describe ingress lootchat -n lootchat

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx <ingress-controller-pod>
```

### Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate
kubectl describe certificate lootchat-tls -n lootchat
kubectl describe certificaterequest -n lootchat
```

## Cleanup

To destroy everything:

```bash
# Delete Kubernetes resources
cd k8s
kubectl delete -k .

# Destroy infrastructure
cd ../terraform
terraform destroy
```

Type `yes` when prompted.

**Note:** This will delete all data permanently!

## Next Steps

- Configure [backups](BACKUP.md)
- Enable [GitOps with FluxCD](FLUX.md)
- Review [security best practices](SECURITY.md)

## Support

- [Configuration Guide](CONFIGURATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [GitHub Issues](https://github.com/babou212/LootChat/issues)
