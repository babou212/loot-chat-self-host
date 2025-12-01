# Troubleshooting Guide

Common issues and solutions for LootChat self-hosting.

## Table of Contents

- [Terraform Issues](#terraform-issues)
- [Kubernetes Issues](#kubernetes-issues)
- [Application Issues](#application-issues)
- [Network Issues](#network-issues)
- [Database Issues](#database-issues)
- [Email Issues](#email-issues)
- [Performance Issues](#performance-issues)

## Terraform Issues

### Issue: Terraform Apply Fails

**Symptoms:**

```text
Error: Error creating server: invalid server type (invalid_input)
```

**Solutions:**

1. Verify server type exists in your location:

   ```bash
   curl -H "Authorization: Bearer $HCLOUD_TOKEN" \
     'https://api.hetzner.cloud/v1/server_types'
   ```

2. Check location availability
3. Try different server type

### Issue: SSH Key Not Found

**Symptoms:**

```text
Error: SSH key not found
```

**Solutions:**

1. Verify SSH key is valid:

   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

2. Ensure it's in the correct format (ssh-ed25519 or ssh-rsa)
3. Check no extra whitespace or newlines

### Issue: API Token Invalid

**Symptoms:**

```text
Error: unable to fetch server types: unauthorized (unauthorized)
```

**Solutions:**

1. Verify token in Hetzner Console
2. Check token has Read & Write permissions
3. Generate new token if needed

## Kubernetes Issues

### Issue: Pods Stuck in Pending

**Symptoms:**

```bash
kubectl get pods -n lootchat
NAME                        READY   STATUS    RESTARTS   AGE
backend-xxx                 0/1     Pending   0          5m
```

**Diagnosis:**

```bash
kubectl describe pod backend-xxx -n lootchat
```

**Common Causes:**

1. **Insufficient resources:**

   ```text
   Events: 0/5 nodes are available: insufficient memory
   ```

   Solution: Scale down resource requests or add more nodes

2. **PVC not bound:**

   ```text
   Events: pod has unbound immediate PersistentVolumeClaims
   ```

   Solution: Check PVC status:

   ```bash
   kubectl get pvc -n lootchat
   kubectl describe pvc postgres-pvc -n lootchat
   ```

3. **Image pull errors:**

   ```text
   Events: Failed to pull image
   ```

   Solution: Check image exists and is accessible

### Issue: Pods Crash Loop

**Symptoms:**

```text
NAME                        READY   STATUS             RESTARTS   AGE
backend-xxx                 0/1     CrashLoopBackOff   5          10m
```

**Diagnosis:**

```bash
kubectl logs backend-xxx -n lootchat
kubectl logs backend-xxx -n lootchat --previous
```

**Common Causes:**

1. **Database connection failed:**

   ```text
   Connection refused: postgres:5432
   ```

   Solution: Verify database is running and accessible

2. **Missing secrets:**

   ```text
   Required environment variable JWT_SECRET not set
   ```

   Solution: Create secrets:

   ```bash
   kubectl apply -f k8s/secrets.yaml
   ```

3. **Application error:**
   Check logs for stack trace and fix application issue

### Issue: Service Not Accessible

**Symptoms:**
Cannot access application via ingress/load balancer

**Diagnosis:**

```bash
# Check services
kubectl get svc -n lootchat

# Check ingress
kubectl get ingress -n lootchat
kubectl describe ingress lootchat -n lootchat

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx <controller-pod>
```

**Solutions:**

1. **DNS not configured:**
   - Verify A record points to load balancer IP
   - Test: `dig yourdomain.com`

2. **Certificate not ready:**

   ```bash
   kubectl get certificate -n lootchat
   kubectl describe certificate lootchat-tls -n lootchat
   ```

   Wait for Ready=True status

3. **Firewall blocking:**
   - Check Hetzner firewall rules
   - Verify ports 80, 443 are open

### Issue: Cert-Manager Not Working

**Symptoms:**
Certificate stays in Pending state

**Diagnosis:**

```bash
kubectl get certificate -n lootchat
kubectl describe certificate lootchat-tls -n lootchat
kubectl get certificaterequest -n lootchat
kubectl logs -n cert-manager -l app=cert-manager
```

**Solutions:**

1. **Rate limit hit:**
   Let's Encrypt has rate limits. Wait or use staging issuer.

2. **DNS not propagated:**
   Wait for DNS to propagate (use `dig yourdomain.com`)

3. **HTTP-01 challenge failed:**
   Ensure port 80 is accessible and ingress is configured correctly

## Application Issues

### Issue: Cannot Login

**Symptoms:**
Login fails with 401 Unauthorized

**Solutions:**

1. **Check admin credentials:**

   ```bash
   kubectl get secret lootchat-secrets -n lootchat -o jsonpath='{.data.ADMIN_EMAIL}' | base64 -d
   kubectl get secret lootchat-secrets -n lootchat -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d
   ```

2. **Check backend logs:**

   ```bash
   kubectl logs -n lootchat -l app=backend | grep -i error
   ```

3. **Verify JWT secret is set:**

   ```bash
   kubectl get secret lootchat-secrets -n lootchat -o jsonpath='{.data.JWT_SECRET}' | base64 -d
   ```

### Issue: Messages Not Sending

**Symptoms:**
Messages don't appear in real-time

**Diagnosis:**

```bash
# Check backend logs
kubectl logs -n lootchat -l app=backend | grep -i kafka

# Check Kafka
kubectl logs -n lootchat -l app=kafka

# Check WebSocket connection in browser console
```

**Solutions:**

1. **Kafka not running:**

   ```bash
   kubectl get pods -n lootchat -l app=kafka
   kubectl logs -n lootchat -l app=kafka
   ```

2. **WebSocket connection failed:**
   - Check browser console for WebSocket errors
   - Verify backend is accessible
   - Check CORS configuration

### Issue: File Uploads Fail

**Symptoms:**
Cannot upload images/files

**Solutions:**

1. **MinIO not running:**

   ```bash
   kubectl get pods -n lootchat -l app=minio
   kubectl logs -n lootchat -l app=minio
   ```

2. **Storage full:**

   ```bash
   kubectl get pvc -n lootchat
   # Check capacity and usage
   ```

3. **Check MinIO configuration:**

   ```bash
   kubectl logs -n lootchat -l app=backend | grep -i minio
   ```

## Network Issues

### Issue: Network Policies Blocking Traffic

**Symptoms:**
Services cannot communicate

**Diagnosis:**

```bash
# Test from one pod to another
kubectl exec -it <pod-name> -n lootchat -- ping <service-name>
kubectl exec -it <pod-name> -n lootchat -- curl http://<service-name>:port
```

**Solutions:**

1. **Temporarily disable network policies:**

   ```bash
   kubectl delete -f k8s/networkpolicy-*.yaml
   ```

2. **Check network policy rules:**

   ```bash
   kubectl get networkpolicy -n lootchat
   kubectl describe networkpolicy <policy-name> -n lootchat
   ```

3. **Update network policy to allow traffic:**
   Edit the appropriate `networkpolicy-*.yaml` file

## Database Issues

### Issue: Database Connection Failed

**Symptoms:**

```text
Connection refused: postgres:5432
FATAL: password authentication failed
```

**Solutions:**

1. **Check database is running:**

   ```bash
   kubectl get pods -n lootchat -l app=postgres
   kubectl logs -n lootchat -l app=postgres
   ```

2. **Verify credentials:**

   ```bash
   kubectl get secret lootchat-secrets -n lootchat -o yaml
   ```

3. **Test connection:**

   ```bash
   kubectl exec -it -n lootchat <backend-pod> -- sh
   psql -h postgres -U lootchat -d lootchat
   ```

### Issue: Database Out of Space

**Symptoms:**

```text
ERROR: could not extend file: No space left on device
```

**Solutions:**

1. **Check PVC size:**

   ```bash
   kubectl get pvc postgres-pvc -n lootchat
   ```

2. **Expand PVC:**
   Edit `k8s/pvcs.yaml`:

   ```yaml
   spec:
     resources:
       requests:
         storage: 20Gi  # Increase from 10Gi
   ```

   Apply:

   ```bash
   kubectl apply -f k8s/pvcs.yaml
   ```

3. **Clean old data:**

   ```bash
   kubectl exec -it -n lootchat <postgres-pod> -- psql -U lootchat -d lootchat
   # Run cleanup queries
   VACUUM FULL;
   ```

## Email Issues

### Issue: Emails Not Sending

**Symptoms:**
Email verification/reset emails not received

**Diagnosis:**

```bash
kubectl logs -n lootchat -l app=backend | grep -i mail
```

**Solutions:**

1. **SMTP credentials wrong:**
   - Verify SMTP settings in secrets
   - For Gmail, use App Password not regular password

2. **Firewall blocking:**
   - Ensure outbound port 587 is open
   - Test: `telnet smtp.gmail.com 587`

3. **Email in spam:**
   - Check spam folder
   - Configure SPF/DKIM records

4. **Test SMTP connection:**

   ```bash
   kubectl exec -it -n lootchat <backend-pod> -- sh
   nc -zv smtp.gmail.com 587
   ```

### Issue: Gmail App Password Not Working

**Solutions:**

1. Ensure 2FA is enabled on Google account
2. Generate new App Password: <https://myaccount.google.com/apppasswords>
3. Use App Password in MAIL_PASSWORD, not regular password
4. Remove spaces from App Password

## Performance Issues

### Issue: High CPU Usage

**Diagnosis:**

```bash
kubectl top nodes
kubectl top pods -n lootchat
```

**Solutions:**

1. **Scale horizontally:**

   ```bash
   kubectl scale deployment backend -n lootchat --replicas=3
   kubectl scale deployment frontend -n lootchat --replicas=2
   ```

2. **Increase resource limits:**
   Edit deployment YAML:

   ```yaml
   resources:
     limits:
       cpu: "4000m"
   ```

3. **Optimize application:**
   - Check for memory leaks
   - Review query performance
   - Add caching

### Issue: High Memory Usage

**Diagnosis:**

```bash
kubectl top pods -n lootchat --sort-by=memory
```

**Solutions:**

1. **Increase memory limits:**

   ```yaml
   resources:
     limits:
       memory: "4Gi"
   ```

2. **Check for memory leaks:**

   ```bash
   kubectl logs -n lootchat <pod-name> | grep -i "OutOfMemory"
   ```

3. **Restart pods:**

   ```bash
   kubectl rollout restart deployment backend -n lootchat
   ```

## Getting Help

If you're still stuck:

1. **Check logs:**

   ```bash
   kubectl logs -n lootchat <pod-name> --tail=100
   ```

2. **Describe resources:**

   ```bash
   kubectl describe pod <pod-name> -n lootchat
   kubectl describe deployment <deployment-name> -n lootchat
   ```

3. **Check events:**

   ```bash
   kubectl get events -n lootchat --sort-by='.lastTimestamp'
   ```

4. **Open an issue:**
   - Visit: <https://github.com/babou212/LootChat/issues>
   - Include: logs, error messages, configuration (no secrets!)
