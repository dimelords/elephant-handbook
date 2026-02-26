# Elephant Kubernetes Deployment Guide

Quick reference for deploying Elephant to Kubernetes.

## Prerequisites Checklist

- [ ] Kubernetes cluster (1.25+) with kubectl access
- [ ] Storage class `standard` available (or modify PVCs)
- [ ] Minimum resources: 4 CPU cores, 8Gi RAM, 105Gi storage
- [ ] Cluster can run privileged init containers (for OpenSearch)

## One-Command Deploy

```bash
kubectl apply -k elephant-handbook/kubernetes/base
```

This deploys everything in the correct order with automatic dependency waiting.

## Verify Deployment

```bash
# Watch pods start up (takes 2-5 minutes)
kubectl get pods -n elephant -w

# Check when all pods are ready
kubectl get pods -n elephant

# Expected output (all Running with 1/1 or 2/2 ready):
# NAME                                   READY   STATUS    RESTARTS   AGE
# elephant-index-xxx                     1/1     Running   0          2m
# elephant-repository-xxx                1/1     Running   0          2m
# elephant-user-xxx                      1/1     Running   0          2m
# keycloak-xxx                           1/1     Running   0          3m
# keycloak-postgres-0                    1/1     Running   0          4m
# minio-0                                1/1     Running   0          4m
# opensearch-0                           1/1     Running   0          4m
# postgres-0                             1/1     Running   0          4m
```

## Access Services Locally

```bash
# Keycloak (authentication)
kubectl port-forward -n elephant svc/keycloak 8080:8080
# Access: http://localhost:8080/admin (admin/admin)

# Repository API
kubectl port-forward -n elephant svc/repository 1080:1080
# Access: http://localhost:1080/twirp/

# Index API
kubectl port-forward -n elephant svc/index 1082:1082
# Access: http://localhost:1082/twirp/

# User API
kubectl port-forward -n elephant svc/user 1083:1083
# Access: http://localhost:1083/twirp/

# MinIO Console
kubectl port-forward -n elephant svc/minio 9001:9001
# Access: http://localhost:9001 (minioadmin/minioadmin)

# OpenSearch
kubectl port-forward -n elephant svc/opensearch 9200:9200
# Access: http://localhost:9200
```

## Common Operations

### View Logs

```bash
# All services
kubectl logs -n elephant -l app.kubernetes.io/part-of=elephant --tail=50

# Specific service
kubectl logs -n elephant -l app=elephant-repository -f
```

### Scale Services

```bash
# Scale up
kubectl scale deployment elephant-repository -n elephant --replicas=3

# Scale down
kubectl scale deployment elephant-repository -n elephant --replicas=1
```

### Restart Service

```bash
kubectl rollout restart deployment elephant-repository -n elephant
```

### Database Access

```bash
# Connect to PostgreSQL
kubectl exec -it -n elephant postgres-0 -- psql -U postgres -d elephant

# Run query
kubectl exec -n elephant postgres-0 -- psql -U postgres -d elephant -c "SELECT COUNT(*) FROM document;"
```

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n elephant

# Common causes:
# - Insufficient resources
# - Storage class not found
# - Node selector not matching
```

### Pods Stuck in Init

```bash
# Check init container logs
kubectl logs <pod-name> -n elephant -c wait-for-postgres

# Common causes:
# - Dependency service not ready
# - Network policy blocking traffic
```

### OpenSearch Won't Start

```bash
# Check if vm.max_map_count is set
kubectl logs -n elephant opensearch-0 -c sysctl

# If init container fails, set on nodes:
# sudo sysctl -w vm.max_map_count=262144
```

### Database Connection Errors

```bash
# Test connectivity
kubectl run -it --rm debug --image=postgres:16-alpine --restart=Never -n elephant -- \
  psql -h postgres -U postgres -d elephant -c "SELECT 1;"
```

## Update Configuration

### Change Environment Variables

```bash
# Edit ConfigMap
kubectl edit configmap elephant-repository-config -n elephant

# Restart to apply
kubectl rollout restart deployment elephant-repository -n elephant
```

### Update Secrets

```bash
# Create new secret
kubectl create secret generic postgres-credentials \
  --from-literal=username=postgres \
  --from-literal=password=NEW_PASSWORD \
  --namespace=elephant \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart services
kubectl rollout restart statefulset postgres -n elephant
kubectl rollout restart deployment elephant-repository -n elephant
```

## Cleanup

### Remove Everything

```bash
# Delete all resources
kubectl delete -k elephant-handbook/kubernetes/base

# Or delete namespace (faster)
kubectl delete namespace elephant
```

### Keep Data

```bash
# Delete only deployments/services
kubectl delete deployment,service,statefulset -n elephant --all

# PVCs remain - redeploy to reuse
kubectl apply -k elephant-handbook/kubernetes/base
```

## Production Checklist

Before deploying to production:

- [ ] Change all default passwords in secrets
- [ ] Configure proper resource limits based on load testing
- [ ] Set up ingress with TLS certificates
- [ ] Enable network policies
- [ ] Configure backup strategy for PostgreSQL and MinIO
- [ ] Deploy monitoring (Prometheus, Grafana)
- [ ] Set up log aggregation (Loki, CloudWatch)
- [ ] Configure autoscaling (HPA)
- [ ] Test disaster recovery procedures
- [ ] Document runbooks for common issues

## Next Steps

1. **Configure Keycloak**: Create realm, client, users
2. **Load Schemas**: Use eleconf to configure document types
3. **Deploy Frontend**: Add elephant-chrome deployment
4. **Set Up Ingress**: Expose services externally
5. **Enable Monitoring**: Deploy observability stack

## See Also

- [Full README](README.md) - Complete documentation
- [Docker Compose](../docker-compose/README.md) - Local development
- [Configuration Guide](../docs/configuration/) - Schema setup
