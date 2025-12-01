# LootChat Self-Hosting Guide

Welcome to the LootChat self-hosting repository! This repository contains everything you need to deploy and run your own instance of LootChat.

## 📋 Table of Contents

- [Overview](#overview)
- [Deployment Options](#deployment-options)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Methods](#deployment-methods)
  - [Kubernetes (Production)](#kubernetes-production)
  - [Docker Compose (Development/Testing)](#docker-compose-developmenttesting)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

LootChat is a modern, real-time chat application built with:

- **Backend:** Java 25 (Spring Boot), Apache Kafka, PostgreSQL, Redis
- **Frontend:** Nuxt 4 (Vue 3, TypeScript)
- **Real-time:** WebSocket + STOMP messaging
- **Voice/Video:** LiveKit integration
- **DevOps:** Kubernetes-ready

This repository provides infrastructure-as-code for deploying LootChat to your own infrastructure.

---

## 🚀 Deployment Options

### 1. **Kubernetes on Hetzner Cloud** (Recommended!)

- **Cost:** ~€25/month for a small cluster
- **Benefits:** Scalable, automated deployments, high availability
- **Setup Time:** ~30 minutes

---

## 📦 Prerequisites

### For Kubernetes Deployment

- [Terraform](https://www.terraform.io/downloads) (>= 1.0)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Hetzner Cloud Account](https://console.hetzner.cloud/)
- A domain name with DNS access
- SSH key pair

---

## ⚡ Quick Start

### Option 1: Automated Deployment (Easiest!)

```bash
# Clone this repository
git clone https://github.com/yourusername/loot-chat-self-host.git
cd loot-chat-self-host

# Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add your Hetzner API token and SSH key

# Configure Kubernetes secrets
cd ../k8s
cp secrets.yaml.example secrets.yaml
nano secrets.yaml  # Add your configuration

# Return to root and run automated deployment
cd ..
./deploy.sh

# The script will:
# ✅ Deploy infrastructure with Terraform
# ✅ Wait for cluster initialization
# ✅ Configure kubectl
# ✅ Deploy LootChat services
# ✅ Provide next steps for DNS setup
```

### Option 2: Manual Kubernetes Deployment

```bash
# 1. Clone this repository
git clone https://github.com/yourusername/loot-chat-self-host.git
cd loot-chat-self-host

# 2. Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# 3. Deploy infrastructure
terraform init
terraform apply

# 4. Wait for cluster initialization (5-10 minutes)
# Monitor with: ssh root@<control-plane-ip> "tail -f /var/log/cloud-init-output.log"

# 5. Download kubeconfig
./setup-kubeconfig.sh

# 6. Configure DNS
# Point your domain to the Load Balancer IP shown in Terraform outputs

# 7. Deploy LootChat
cd ../k8s
# Update secrets.yaml and configmap.yaml with your configuration
kubectl apply -k .

# 8. Access your LootChat instance
# https://yourdomain.com
```

---

## 🎯 Deployment Methods

### Kubernetes

Kubernetes deployment provides:

- **High Availability:** Multi-node cluster with load balancing
- **Scalability:** Easy horizontal scaling for all services
- **Security:** Network policies, RBAC, secret management

#### Architecture

The Kubernetes deployment includes:

- 1 Control Plane node (2 vCPU, 4GB RAM)
- 4 Worker nodes (2 vCPU, 4GB RAM each)
- Hetzner Cloud Load Balancer
- Private networking with firewall rules
- Persistent volumes for data storage

#### Step-by-Step Guide

**Automated Deployment (Recommended):**

```bash
# Full automated deployment
./deploy.sh

# Or with options
./deploy.sh --help              # View all options
./deploy.sh --skip-terraform    # Deploy only K8s application
./deploy.sh --sops              # Use SOPS-encrypted secrets
```

**Manual Deployment:**

See [docs/KUBERNETES.md](docs/KUBERNETES.md) for detailed manual instructions.

#### Cost Breakdown (Hetzner Cloud)

| Resource | Type | Monthly Cost (€) |
|----------|------|------------------|
| Control Plane | CAX21 (2 vCPU ARM, 4GB) | ~€3.75 |
| Worker Nodes x4 | CAX11 (2 vCPU ARM, 4GB) | ~€16 |
| Load Balancer | LB11 | ~€5 |

*Prices approximate, see [Hetzner Pricing](https://www.hetzner.com/cloud) for current rates.*

---

## ⚙️ Configuration

### Environment Variables

LootChat is highly configurable through environment variables. See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for a complete reference.

**Essential Configuration:**

| Variable | Description | Required |
|----------|-------------|----------|
| `POSTGRES_USER` | Database username | Yes |
| `POSTGRES_PASSWORD` | Database password | Yes |
| `JWT_SECRET` | Secret for JWT tokens | Yes |
| `ADMIN_EMAIL` | Initial admin email | Yes |
| `ADMIN_PASSWORD` | Initial admin password | Yes |
| `CORS_ALLOWED_ORIGINS` | Allowed frontend URLs | Yes |

**Optional Configuration:**

| Variable | Description | Default |
|----------|-------------|---------|
| `MAIL_HOST` | SMTP server | - |
| `MAIL_PORT` | SMTP port | 587 |
| `NUXT_PUBLIC_TENOR_API_KEY` | Tenor GIF API key | - |

### Secrets Management

**Kubernetes:**

- Use `kubectl` to create secrets
- Or use sealed-secrets/SOPS
- Example: `kubectl create secret generic lootchat-secrets --from-env-file=.env`

### Domain Configuration

**Kubernetes:**

1. Get Load Balancer IP: `terraform output load_balancer_ip`
2. Create DNS A record: `yourdomain.com → <load-balancer-ip>`
3. Update `ingress.yaml` with your domain
4. Apply: `kubectl apply -f k8s/ingress.yaml`

---

## 📚 Documentation

- **[Deployment Script Guide](docs/DEPLOYMENT-SCRIPT.md)** - Automated deployment reference
- **[Kubernetes Guide](docs/KUBERNETES.md)** - Detailed Kubernetes setup
- **[Domain Setup](docs/DOMAIN-SETUP.md)** - DNS and SOPS configuration
- **[Configuration Reference](docs/CONFIGURATION.md)** - All configuration options
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

---

## 📊 Monitoring

### Basic Monitoring

**Kubernetes:**

```bash
# View pod status
kubectl get pods -n lootchat

# View logs
kubectl logs -n lootchat -l app=backend -f

# Check resource usage
kubectl top nodes
kubectl top pods -n lootchat
```

For monitoring, consider adding your own monitoring solution such as Prometheus, Grafana, or cloud-native monitoring tools.

---

## 🔧 Troubleshooting

### Common Issues

**Kubernetes:**

1. **Pods not starting:**

   ```bash
   kubectl get pods -n lootchat
   kubectl describe pod <pod-name> -n lootchat
   kubectl logs <pod-name> -n lootchat
   ```

2. **Services not accessible:**

   ```bash
   kubectl get svc -n lootchat
   kubectl get ingress -n lootchat
   ```

3. **Storage issues:**

   ```bash
   kubectl get pvc -n lootchat
   kubectl describe pvc <pvc-name> -n lootchat
   ```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more solutions.

---

## 🔐 Security Considerations

### Checklist

- [ ] Change all default passwords
- [ ] Generate strong JWT secret (32+ characters)
- [ ] Enable HTTPS with valid certificates
- [ ] Restrict SSH access to specific IPs
- [ ] Enable network policies (Kubernetes)
- [ ] Regular backups of database
- [ ] Keep systems updated
- [ ] Monitor logs for suspicious activity
- [ ] Use strong database passwords
- [ ] Configure firewall rules

---

## 🤝 Contributing

Found a bug or have a suggestion? Contributions are welcome!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📄 License

This project is licensed under the GPL-3.0 License. See the [LICENSE](LICENSE) file for details.

Copyright (c) 2025 babou212

---

## 🙋 Support

- **Issues:** [GitHub Issues](https://github.com/babou212/LootChat/issues)
- **Documentation:** [docs/](docs/)

---

## 🌟 Acknowledgments

Built with amazing technologies:

- [Spring Boot](https://spring.io/projects/spring-boot)
- [Nuxt](https://nuxt.com/)
- [Kubernetes](https://kubernetes.io/)
- [PostgreSQL](https://www.postgresql.org/)
- [Apache Kafka](https://kafka.apache.org/)
- [LiveKit](https://livekit.io/)
- [Terraform](https://www.terraform.io/)

---

**Happy self-hosting! 🎉**
