# LootChat Configuration Guide

This document provides a comprehensive reference for all configurable values in LootChat.

## Table of Contents

- [Environment Variables](#environment-variables)
- [Terraform Variables](#terraform-variables)
- [Kubernetes Configuration](#kubernetes-configuration)
- [Security Settings](#security-settings)
- [Email Configuration](#email-configuration)
- [Database Configuration](#database-configuration)
- [Cache Configuration](#cache-configuration)
- [Media Server Configuration](#media-server-configuration)

---

## Environment Variables

### Database Configuration

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `POSTGRES_USER` | PostgreSQL username | Yes | - | `lootchat` |
| `POSTGRES_PASSWORD` | PostgreSQL password | Yes | - | `securepass123` |
| `POSTGRES_DB` | Database name | Yes | - | `lootchat` |
| `POSTGRES_HOST` | Database host | No | `localhost` | `db` |
| `POSTGRES_PORT` | Database port | No | `5432` | `5432` |

**Best Practices:**

- Use strong passwords (16+ characters, mixed case, numbers, symbols)
- Never use default passwords in production
- Change credentials after initial setup

### Authentication & Security

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `JWT_SECRET` | Secret key for JWT token signing | Yes | - | `your-secret-key-here` |
| `JWT_EXPIRATION` | JWT token expiration time | No | `86400000` | `86400000` (24h in ms) |
| `CORS_ALLOWED_ORIGINS` | Comma-separated allowed origins | Yes | - | `http://localhost:3000,https://lootchat.com` |

**Generating JWT Secret:**

```bash
# Generate a secure 32-character secret
openssl rand -base64 32
```

**Important:** Never reuse JWT secrets across environments!

### Admin User Configuration

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `ADMIN_USERNAME` | Initial admin username | Yes | - | `admin` |
| `ADMIN_EMAIL` | Initial admin email | Yes | - | `admin@lootchat.com` |
| `ADMIN_PASSWORD` | Initial admin password | Yes | - | `ChangeMe123!` |
| `ADMIN_FIRST_NAME` | Admin first name | No | `System` | `John` |
| `ADMIN_LAST_NAME` | Admin last name | No | `Administrator` | `Doe` |

**Security Notes:**

- Change the admin password immediately after first login
- Use a strong password (12+ characters, mixed case, numbers, symbols)
- Consider using a password manager

### Email Configuration (SMTP)

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `MAIL_HOST` | SMTP server hostname | No | - | `smtp.gmail.com` |
| `MAIL_PORT` | SMTP server port | No | `587` | `587` |
| `MAIL_USERNAME` | SMTP username | No | - | `your-email@gmail.com` |
| `MAIL_PASSWORD` | SMTP password | No | - | `your-app-password` |
| `MAIL_FROM` | From email address | No | `MAIL_USERNAME` | `noreply@lootchat.com` |
| `MAIL_FROM_NAME` | From name | No | `APP_NAME` | `LootChat` |

**Email Providers:**

**Gmail:**

1. Enable 2FA on your Google account
2. Generate an [App Password](https://support.google.com/accounts/answer/185833)
3. Use the app password, not your regular password
4. Settings:
   - Host: `smtp.gmail.com`
   - Port: `587`

**SendGrid:**

1. Create a SendGrid account
2. Generate an API key
3. Settings:
   - Host: `smtp.sendgrid.net`
   - Port: `587`
   - Username: `apikey`
   - Password: `<your-api-key>`

**Mailgun:**

1. Create a Mailgun account
2. Get SMTP credentials
3. Settings:
   - Host: `smtp.mailgun.org`
   - Port: `587`

**AWS SES:**

1. Verify your domain/email in SES
2. Create SMTP credentials
3. Settings:
   - Host: `email-smtp.<region>.amazonaws.com`
   - Port: `587`

### Application Settings

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `APP_NAME` | Application name | No | `LootChat` | `My Chat App` |
| `APP_URL` | Base URL of your app | No | - | `https://lootchat.com` |
| `NUXT_SESSION_PASSWORD` | Session encryption key | Yes | - | Generate with `openssl rand -base64 32` |

### Optional Integrations

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `NUXT_PUBLIC_TENOR_API_KEY` | Tenor GIF API key | No | - | `your-tenor-key` |

**Getting a Tenor API Key:**

1. Visit [Tenor API](https://developers.google.com/tenor/guides/quickstart)
2. Create a project
3. Enable Tenor API
4. Create credentials

### Redis Configuration

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `REDIS_HOST` | Redis hostname | No | `localhost` | `redis` |
| `REDIS_PORT` | Redis port | No | `6379` | `6379` |
| `REDIS_PASSWORD` | Redis password | No | - | `redis-password` |

### Kafka Configuration

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka brokers | No | `localhost:9092` | `kafka:9092` |

---

## Terraform Variables

Configuration for infrastructure deployment on Hetzner Cloud.

### Authentication

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `hcloud_token` | Hetzner Cloud API token | Yes | `get-from-hetzner-console` |
| `ssh_public_key` | SSH public key for server access | Yes | `ssh-ed25519 AAAAC3...` |

**Getting Hetzner API Token:**

1. Log into [Hetzner Console](https://console.hetzner.cloud/)
2. Select your project
3. Go to Security → API Tokens
4. Generate new token with Read & Write permissions

**Generating SSH Key:**

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
cat ~/.ssh/id_ed25519.pub
```

### Cluster Configuration

| Variable | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `cluster_name` | Kubernetes cluster name | No | `lootchat` | `my-lootchat` |
| `location` | Hetzner datacenter location | No | `nbg1` | `fsn1`, `nbg1`, `hel1` |
| `network_zone` | Network zone | No | `eu-central` | `eu-central`, `us-east` |

**Available Locations:**

- `fsn1` - Falkenstein, Germany
- `nbg1` - Nuremberg, Germany
- `hel1` - Helsinki, Finland
- `ash` - Ashburn, USA
- `hil` - Hillsboro, USA

### Server Configuration

| Variable | Description | Default | Specs | Monthly Cost |
|----------|-------------|---------|-------|--------------|
| `control_plane_server_type` | Master node type | `cax21` | 4 vCPU ARM, 8GB RAM, 80GB SSD | €10 |
| `worker_server_type` | Worker node type | `cax11` | 2 vCPU ARM, 4GB RAM, 40GB SSD | €4 |
| `worker_count` | Number of workers | `4` | - | €16 (for 4) |
| `load_balancer_type` | Load balancer type | `lb11` | 5k connections | €5 |

**Server Type Options:**

ARM-based (CAX, more cost-effective):

- `cax11` - 2 vCPU, 4GB RAM, 40GB - €4/month
- `cax21` - 4 vCPU, 8GB RAM, 80GB - €10/month
- `cax31` - 8 vCPU, 16GB RAM, 160GB - €20/month
- `cax41` - 16 vCPU, 32GB RAM, 320GB - €40/month

x86-based (CPX, better compatibility):

- `cpx11` - 2 vCPU, 2GB RAM, 40GB - €5/month
- `cpx21` - 3 vCPU, 4GB RAM, 80GB - €10/month
- `cpx31` - 4 vCPU, 8GB RAM, 160GB - €17/month

**Recommendations:**

- **Small setup:** 1x cax21 control + 2x cax11 workers (~€18/month)
- **Medium setup:** 1x cax21 control + 4x cax11 workers (~€26/month)
- **Large setup:** 1x cax31 control + 6x cax21 workers (~€80/month)

### Network Configuration

| Variable | Description | Default | Valid Range |
|----------|-------------|---------|-------------|
| `network_cidr` | Private network CIDR | `10.0.0.0/16` | Any private range |
| `subnet_cidr` | Subnet CIDR | `10.0.1.0/24` | Within network_cidr |
| `pod_network_cidr` | Kubernetes pod network | `10.244.0.0/16` | Any private range |

### Security

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `allowed_ssh_ips` | IPs allowed to SSH | `["0.0.0.0/0"]` | `["1.2.3.4/32"]` |

**Security Best Practice:**
Restrict SSH to your IP only:

```terraform
allowed_ssh_ips = [
  "1.2.3.4/32"  # Your IP address
]
```

Get your IP: `curl ifconfig.me`

### Kubernetes Version

| Variable | Description | Default |
|----------|-------------|---------|
| `kubernetes_version` | K8s version to install | `1.32.0` |

**Version Selection:**

- Use stable releases (e.g., 1.32.x, 1.31.x)
- Check [Kubernetes releases](https://kubernetes.io/releases/)
- Test new versions in staging first

---

## Kubernetes Configuration

### Resource Limits

Default resource limits for each service (in `k8s/*.yaml`):

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|-------------|-----------|----------------|--------------|
| Backend | 500m | 2000m | 512Mi | 2Gi |
| Frontend | 200m | 1000m | 256Mi | 1Gi |
| PostgreSQL | 500m | 2000m | 512Mi | 2Gi |
| Redis | 200m | 500m | 256Mi | 512Mi |
| Kafka | 500m | 2000m | 512Mi | 2Gi |
| MinIO | 200m | 1000m | 256Mi | 1Gi |
| LiveKit | 1000m | 4000m | 1Gi | 4Gi |

**Adjusting Resources:**

Edit the respective YAML file:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

### Storage Volumes

Default persistent volume sizes:

| Service | Volume Size | Storage Class |
|---------|-------------|---------------|
| PostgreSQL | 10Gi | hcloud-volumes |
| Redis | 5Gi | hcloud-volumes |
| MinIO | 20Gi | hcloud-volumes |
| Uploads | 10Gi | hcloud-volumes |

**Expanding Volumes:**

Edit `k8s/pvcs.yaml`:

```yaml
spec:
  resources:
    requests:
      storage: 20Gi  # Increase size
```

### Ingress Configuration

Edit `k8s/ingress.yaml`:

```yaml
spec:
  rules:
    - host: lootchat.yourdomain.com  # Your domain
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 3000
```

**SSL Certificates:**

LootChat uses cert-manager with Let's Encrypt. Edit `k8s/ingress.yaml`:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - lootchat.yourdomain.com
      secretName: lootchat-tls
```

---

## Security Settings

### Network Policies

Network policies are enabled by default for security:

- `networkpolicy-default-deny.yaml` - Deny all traffic by default
- `networkpolicy-backend.yaml` - Allow backend connections
- `networkpolicy-frontend.yaml` - Allow frontend connections
- `networkpolicy-postgres.yaml` - Restrict database access
- `networkpolicy-redis.yaml` - Restrict Redis access

**Disabling Network Policies:**

If you experience connectivity issues, you can temporarily disable:

```bash
kubectl delete -f k8s/networkpolicy-*.yaml
```

### Priority Classes

Priority classes ensure critical services stay running:

- `high-priority` - For backend, database
- `medium-priority` - For frontend, cache
- `low-priority` - For non-critical services

---

## Email Configuration

### Email Templates

LootChat sends emails for:

- Email verification
- Password reset
- Admin invitations
- Notifications (optional)

Email templates are configurable in the backend configuration.

### Testing Email

Test your email configuration:

```bash
# Register a new user
# Check for verification email
# Test password reset
```

---

## Database Configuration

### Connection Pooling

Default connection pool settings:

```properties
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.connection-timeout=30000
```

**For high traffic, increase pool size:**

```yaml
env:
  - name: SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE
    value: "20"
```

### Backup Configuration

**Automatic Backups:**

Create a CronJob for backups:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:16
            command:
            - /bin/sh
            - -c
            - pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > /backup/backup-$(date +%Y%m%d).sql.gz
```

---

## Cache Configuration

### Redis Settings

**Memory Management:**

```yaml
command:
  - redis-server
  - --maxmemory 1gb
  - --maxmemory-policy allkeys-lru
```

---

## Media Server Configuration

### LiveKit

LiveKit handles voice/video chat. Configuration in `k8s/livekit.yaml`.

**TURN Server:**
For NAT traversal, configure TURN servers:

```yaml
env:
  - name: LIVEKIT_TURN_SERVER
    value: "turn:your-turn-server.com:3478"
```

---

## Environment-Specific Configurations

### Production

- Strict CORS
- Error-level logging
- Full resources
- Monitoring enabled
- Backups enabled
- High availability

---

### Testing Configuration

```bash
# Test database connection
kubectl exec -it <backend-pod> -- psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB

# Test Redis connection
kubectl exec -it <redis-pod> -- redis-cli ping

# Test Kafka connection
kubectl exec -it <kafka-pod> -- kafka-topics --bootstrap-server localhost:9092 --list

# View logs
kubectl logs <pod-name> -n lootchat
```

---

## Troubleshooting Configuration Issues

### Common Problems

1. **Cannot connect to database**
   - Verify `POSTGRES_HOST`, `POSTGRES_PORT`
   - Check database credentials
   - Verify network policies

2. **JWT errors**
   - Ensure `JWT_SECRET` is set and consistent
   - Check token expiration settings

3. **Email not sending**
   - Verify SMTP credentials
   - Check firewall rules (port 587/465)
   - Test with `telnet smtp.server.com 587`

4. **CORS errors**
   - Add frontend URL to `CORS_ALLOWED_ORIGINS`
   - Verify protocol (http vs https)
   - Check domain spelling

---

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [Hetzner Cloud Docs](https://docs.hetzner.com/)
- [Spring Boot Configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/application-properties.html)

---

**Need help?** Check the [Troubleshooting Guide](TROUBLESHOOTING.md) or open an issue on GitHub.
