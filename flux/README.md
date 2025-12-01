# FluxCD GitOps Configuration

This directory contains FluxCD configuration for automated deployment and image updates.

## Overview

FluxCD monitors this repository and automatically:
- Deploys Kubernetes manifests from the `k8s/` directory
- Updates container images when new versions are published
- Manages the entire infrastructure as code

## Files

### Core Configuration

- **`gitrepository.yaml`** - Defines the Git repository to watch
- **`kustomization.yaml`** - Defines what to deploy from the repository

### Image Automation

- **`imagerepository.yaml`** - Watches Docker Hub for new backend/frontend images
- **`imagepolicy.yaml`** - Defines which image tags to use (based on timestamp)
- **`imageupdateautomation.yaml`** - Automatically updates k8s manifests with new images

## Setup

### Prerequisites

1. **FluxCD installed in your cluster**
   ```bash
   flux install
   ```

2. **GitHub Personal Access Token** (for private repos)
   ```bash
   flux create secret git lootchat-git-auth \
     --url=https://github.com/babou212/loot-chat-self-host \
     --username=babou212 \
     --password=<your-github-pat>
   ```

### Install FluxCD Resources

```bash
# Apply all flux configuration
kubectl apply -f flux/production/

# Or use flux CLI
flux reconcile source git lootchat-infrastructure
flux reconcile kustomization lootchat-infrastructure
```

## How It Works

### 1. Repository Monitoring

FluxCD watches this repository every 1 minute:
```yaml
spec:
  interval: 1m
  url: https://github.com/babou212/loot-chat-self-host
  ref:
    branch: main
```

### 2. Manifest Deployment

When changes are detected in `k8s/`, FluxCD applies them:
```yaml
spec:
  path: ./k8s
  prune: true  # Remove resources not in git
```

### 3. Image Updates

FluxCD watches Docker Hub for new images:
- Pattern: `master-{commit}-{timestamp}`
- Policy: Use newest timestamp
- Auto-commit: Updates manifests and pushes to git

## Workflow

```
1. Developer pushes code → GitHub
2. CI/CD builds image → Docker Hub (babou212/lootchat-backend:master-abc123-1234567890)
3. FluxCD detects new image
4. FluxCD updates k8s/backend.yaml with new image tag
5. FluxCD commits change to git
6. FluxCD deploys updated manifest to cluster
```

## Domain Configuration

**Important**: FluxCD will deploy template files if you don't configure domains first.

Before enabling FluxCD, ensure:
1. Domain is configured in `secrets.yaml`
2. Run `./configure-domain.sh --sops` to generate manifests
3. Commit generated `ingress.yaml` and `configmap.yaml` to git

Or use the `.spec.ignore` in `gitrepository.yaml` to exclude templates:
```yaml
ignore: |
  /k8s/*.template
```

## Monitoring FluxCD

```bash
# Check FluxCD status
flux get all

# Check GitRepository sync
flux get sources git

# Check Kustomization status
flux get kustomizations

# Check image automation
flux get images all

# View logs
flux logs --all-namespaces --follow

# Force reconciliation
flux reconcile source git lootchat-infrastructure
flux reconcile kustomization lootchat-infrastructure
```

## Troubleshooting

### Repository Not Syncing

```bash
# Check GitRepository status
kubectl get gitrepository -n flux-system lootchat-infrastructure -o yaml

# Common issues:
# 1. Invalid credentials
# 2. Wrong branch name
# 3. Network issues
```

### Images Not Updating

```bash
# Check ImageRepository
kubectl get imagerepository -n flux-system

# Check ImagePolicy
kubectl get imagepolicy -n flux-system

# Check ImageUpdateAutomation
kubectl get imageupdateautomation -n flux-system

# Common issues:
# 1. Wrong image name pattern
# 2. No matching tags
# 3. Missing write permissions to git
```

### Manifests Not Applying

```bash
# Check Kustomization
kubectl describe kustomization -n flux-system lootchat-infrastructure

# Common issues:
# 1. Invalid YAML
# 2. Missing dependencies (e.g., namespace)
# 3. Resource conflicts
```

## Disabling Image Automation

If you want manual control over image versions:

```bash
# Suspend image automation
flux suspend image update lootchat-infrastructure

# Resume
flux resume image update lootchat-infrastructure
```

## Multiple Environments

For staging/production environments:

```
flux/
  staging/
    gitrepository.yaml  # branch: staging
    kustomization.yaml
  production/
    gitrepository.yaml  # branch: main
    kustomization.yaml
```

## Security Notes

1. **Git Credentials**: Stored as secret `lootchat-git-auth`
2. **Write Access**: FluxCD needs write access for image automation
3. **Read-Only Mode**: Remove `imageupdateautomation.yaml` for read-only deployments

## Resources

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [Image Automation Guide](https://fluxcd.io/docs/guides/image-update/)
- [GitOps Toolkit](https://fluxcd.io/docs/components/)

---

**Note**: This configuration assumes you're using the `loot-chat-self-host` repository for infrastructure management. The main LootChat application repository handles code and CI/CD.
