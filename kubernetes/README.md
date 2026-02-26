# Kubernetes Deployment

Production-ready Kubernetes manifests for Elephant using Kustomize.

## Deployment Options

Choose the right deployment method for your needs:

| Option | Best For | Setup Time | Resources | Cost | Production-Ready |
|--------|----------|------------|-----------|------|------------------|
| [Minikube](minikube/) | Local K8s testing | 5-10 min | 8GB RAM, 4 CPU | Free | No |
| [Docker Compose](../docker-compose/) | Quick local dev | 2-5 min | 4GB RAM, 2 CPU | Free | No |
| [Base Manifests](base/) | Self-managed K8s | 10-15 min | 16GB RAM, 8 CPU | Varies | Yes |
| [AWS Terraform](../terraform/aws/) | AWS production | 15-20 min | Cloud | $200-1500/mo | Yes |

### Quick Decision Guide

- **Just want to try Elephant?** → Use [Docker Compose](../docker-compose/)
- **Testing Kubernetes manifests?** → Use [Minikube](minikube/)
- **Deploying to existing cluster?** → Use [Base Manifests](base/)
- **Need complete AWS setup?** → Use [AWS Terraform](../terraform/aws/)

## Overview

This directory contains Kubernetes manifests to deploy the complete Elephant stack:

- **Infrastructure**: PostgreSQL, Keycloak, MinIO, OpenSearch
- **Services**: elephant-repository, elephant-index, elephant-user
- **Configuration**: ConfigMaps, Secrets, PersistentVolumeClaims

## Prerequisites

- Kubernetes cluster (1.25+)
- kubectl configured
- Storage class named `standard` (or modify PVCs)
- At least 16GB RAM and 4 CPU cores available

## Quick Start

### Deploy Everything

```bash
# Create namespace and deploy all services
kubectl apply -k elephant-handbook/kubernetes/base

# Watch deployment progress
kubectl get pods -n elephant -w

# Check service status
kubectl get all -n elephant
```

### Access Services

```bash
# Port forward to access services locally
kubectl port-forward -n elephant svc/keycloak 8080:8080
kubectl port-forward -n elephant svc/repository 1080:1080
kubectl port-forward -n elephant svc/index 1082:1082
kubectl port-forward -n elephant svc/user 1083:1083
kubectl port-forward -n elephant svc/minio 9001:9001
```

## Architecture

### Infrastructure Layer

**PostgreSQL** (StatefulSet)
- Main database for all Elephant services
- Includes init script with extensions and roles
- 20Gi persistent storage
- Single replica (can be scaled with replication)

**Keycloak** (Deployment + StatefulSet for DB)
- Authentication and authorization (OIDC)
- Separate PostgreSQL database
- 2 replicas for high availability
- Admin credentials: admin/admin (change in production!)

**MinIO** (StatefulSet)
- S3-compatible object storage
- Stores archived documents
- 50Gi persistent storage
- Includes init job to create buckets

**OpenSearch** (StatefulSet)
- Full-text search engine
- 30Gi persistent storage
- Requires vm.max_map_count=262144 (set by init container)

### Application Layer

**elephant-repository** (Deployment)
- Document storage and versioning
- 2 replicas with pod anti-affinity
- Automatic database migrations on startup
- Connects to PostgreSQL, MinIO, Keycloak

**elephant-index** (Deployment)
- Search indexing and percolation
- 2 replicas for high availability
- Connects to PostgreSQL, OpenSearch, repository

**elephant-user** (Deployment)
- User events and inbox
- 2 replicas for high availability
- Automatic database migrations on startup

## Configuration

### Secrets

All secrets use default development values. For production:

```bash
# Update PostgreSQL credentials
kubectl create secret generic postgres-credentials \
  --from-literal=username=postgres \
  --from-literal=password=STRONG_PASSWORD_HERE \
  --from-literal=database=elephant \
  --namespace=elephant \
  --dry-run=client -o yaml | kubectl apply -f -

# Update Keycloak credentials
kubectl create secret generic keycloak-credentials \
  --from-literal=admin-username=admin \
  --from-literal=admin-password=STRONG_PASSWORD_HERE \
  --from-literal=db-username=postgres \
  --from-literal=db-password=STRONG_PASSWORD_HERE \
  --namespace=elephant \
  --dry-run=client -o yaml | kubectl apply -f -

# Update MinIO credentials
kubectl create secret generic minio-credentials \
  --from-literal=root-user=minioadmin \
  --from-literal=root-password=STRONG_PASSWORD_HERE \
  --namespace=elephant \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Resource Limits

Current resource allocations:

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|-------------|-----------|----------------|--------------|
| postgres | 500m | 2000m | 1Gi | 4Gi |
| keycloak | 500m | 2000m | 1Gi | 2Gi |
| keycloak-postgres | 250m | 1000m | 512Mi | 2Gi |
| minio | 500m | 2000m | 1Gi | 4Gi |
| opensearch | 1000m | 2000m | 2Gi | 4Gi |
| repository | 500m | 2000m | 512Mi | 2Gi |
| index | 500m | 2000m | 512Mi | 2Gi |
| user | 250m | 1000m | 256Mi | 1Gi |

**Total minimum**: ~4 CPU, ~8Gi RAM  
**Total with limits**: ~14 CPU, ~23Gi RAM

Adjust based on your cluster capacity and workload.

### Storage

Persistent volumes required:

| PVC | Size | Purpose |
|-----|------|---------|
| postgres-data | 20Gi | Main database |
| keycloak-postgres-data | 5Gi | Keycloak database |
| minio-data | 50Gi | Object storage |
| opensearch-data | 30Gi | Search indexes |

**Total**: 105Gi

Ensure your cluster has a storage class named `standard` or modify the PVCs.

## Deployment Order

Services have init containers that wait for dependencies:

1. **Infrastructure** (parallel):
   - postgres
   - keycloak-postgres
   - minio
   - opensearch

2. **Keycloak** (after keycloak-postgres)

3. **MinIO Init Job** (after minio)

4. **Elephant Services** (after postgres, keycloak, minio, opensearch):
   - repository
   - index
   - user

Init containers ensure proper startup order automatically.

## Operations

### View Logs

```bash
# All pods in namespace
kubectl logs -n elephant -l app.kubernetes.io/part-of=elephant --tail=100

# Specific service
kubectl logs -n elephant -l app=elephant-repository -f

# PostgreSQL logs
kubectl logs -n elephant -l app=postgres -f
```

### Scale Services

```bash
# Scale repository service
kubectl scale deployment elephant-repository -n elephant --replicas=3

# Scale index service
kubectl scale deployment elephant-index -n elephant --replicas=3
```

### Database Access

```bash
# Connect to PostgreSQL
kubectl exec -it -n elephant postgres-0 -- psql -U postgres -d elephant

# Run SQL file
kubectl exec -i -n elephant postgres-0 -- psql -U postgres -d elephant < schema.sql
```

### Backup Database

```bash
# Create backup
kubectl exec -n elephant postgres-0 -- pg_dump -U postgres elephant > backup.sql

# Restore backup
kubectl exec -i -n elephant postgres-0 -- psql -U postgres elephant < backup.sql
```

### Update Configuration

```bash
# Edit ConfigMap
kubectl edit configmap elephant-repository-config -n elephant

# Restart deployment to pick up changes
kubectl rollout restart deployment elephant-repository -n elephant
```

## Monitoring

Services expose Prometheus metrics:

- repository: `:1080/metrics`
- index: `:1082/metrics`
- user: `:1083/metrics`

Pods are annotated for Prometheus scraping:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "1080"
  prometheus.io/path: "/metrics"
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n elephant

# Describe pod for events
kubectl describe pod <pod-name> -n elephant

# Check logs
kubectl logs <pod-name> -n elephant
```

### Database Connection Issues

```bash
# Test PostgreSQL connectivity
kubectl run -it --rm debug --image=postgres:16-alpine --restart=Never -n elephant -- \
  psql -h postgres -U postgres -d elephant

# Check if database exists
kubectl exec -it postgres-0 -n elephant -- psql -U postgres -l
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n elephant

# Check PV status
kubectl get pv

# Describe PVC for events
kubectl describe pvc postgres-data -n elephant
```

### OpenSearch Not Starting

OpenSearch requires `vm.max_map_count=262144`. The init container sets this, but it requires privileged access.

If pods fail with "max virtual memory areas" error:

```bash
# On each node (or via DaemonSet)
sudo sysctl -w vm.max_map_count=262144

# Make permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

## Cleanup

### Remove Everything

```bash
# Delete all resources
kubectl delete -k elephant-handbook/kubernetes/base

# Delete namespace (removes everything)
kubectl delete namespace elephant
```

### Keep Data

To remove services but keep data (PVCs):

```bash
# Delete deployments and services
kubectl delete deployment,service,statefulset -n elephant --all

# PVCs remain - redeploy to reuse data
kubectl apply -k elephant-handbook/kubernetes/base
```

## Production Considerations

### Security

1. **Change default passwords** in all secrets
2. **Enable TLS** for all services
3. **Use network policies** to restrict traffic
4. **Enable RBAC** with least privilege
5. **Use external secrets** (AWS Secrets Manager, Vault)

### High Availability

1. **PostgreSQL**: Use managed database (RDS, Cloud SQL) or PostgreSQL operator
2. **Keycloak**: Already 2 replicas, consider 3+ for production
3. **MinIO**: Use distributed mode (4+ nodes) or managed S3
4. **OpenSearch**: Use 3+ nodes with proper shard allocation

### Monitoring

1. **Deploy Prometheus** to scrape metrics
2. **Deploy Grafana** with dashboards (see `configs/observability/`)
3. **Set up alerts** for critical issues
4. **Enable logging** to centralized system (Loki, CloudWatch)

### Backups

1. **Database**: Regular pg_dump or use backup operator
2. **MinIO**: Enable versioning and replication
3. **OpenSearch**: Snapshot to S3
4. **Disaster recovery**: Test restore procedures

## Next Steps

1. **Configure Keycloak**: Create realm, client, users (see docs)
2. **Load schemas**: Use eleconf to configure document types
3. **Deploy frontend**: Add elephant-chrome deployment
4. **Set up ingress**: Expose services externally
5. **Enable monitoring**: Deploy observability stack

## See Also

- [Minikube Setup](minikube/) - Local Kubernetes testing
  - [Quick Reference](minikube/QUICKREF.md) - One-page cheat sheet
- [Docker Compose Setup](../docker-compose/README.md) - Local development
- [AWS Terraform](../terraform/aws/) - Cloud deployment
- [Configuration Guide](../docs/configuration/) - Schema and workflow setup
- [Observability](../docs/operations/observability.md) - Monitoring setup
- [Deployment Guide](DEPLOYMENT-GUIDE.md) - Detailed deployment instructions

## Prerequisites

- Kubernetes 1.24+
- kubectl configured
- Sufficient cluster resources
- StorageClass for persistent volumes
- LoadBalancer or Ingress controller

## Architecture

```
                    ┌──────────────┐
                    │   Ingress    │
                    └──────┬───────┘
                           │
        ┏━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━┓
        ┃                                    ┃
        ▼                                    ▼
┌───────────────┐                   ┌───────────────┐
│  elephant-    │                   │  elephant-    │
│  chrome       │                   │  repository   │
│  (Deployment) │                   │  (Deployment) │
└───────────────┘                   └───────┬───────┘
                                            │
                         ┏━━━━━━━━━━━━━━━━━┻━━━━━━━━━━┓
                         ┃                             ┃
                         ▼                             ▼
                 ┌───────────────┐           ┌───────────────┐
                 │  elephant-    │           │  PostgreSQL   │
                 │  index        │           │  (StatefulSet)│
                 │  (Deployment) │           └───────────────┘
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │  OpenSearch   │
                 │  (StatefulSet)│
                 └───────────────┘
```

## Resource Requirements

### Minimum (Development)
- **Total CPU**: 4 cores
- **Total Memory**: 8 GB
- **Storage**: 50 GB

### Recommended (Production)
- **Total CPU**: 16 cores
- **Total Memory**: 32 GB
- **Storage**: 500 GB+ (with backup)

### Per Service

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|-------------|-----------|----------------|--------------|
| repository | 500m | 2000m | 512Mi | 2Gi |
| index | 500m | 2000m | 512Mi | 2Gi |
| user | 250m | 1000m | 256Mi | 1Gi |
| chrome | 100m | 500m | 128Mi | 512Mi |
| postgres | 1000m | 4000m | 2Gi | 8Gi |
| opensearch | 1000m | 4000m | 2Gi | 8Gi |
| minio | 500m | 2000m | 1Gi | 4Gi |

## Storage

### StorageClasses Required

- **Fast SSD**: PostgreSQL, OpenSearch (high IOPS)
- **Standard**: MinIO, backups

### Persistent Volume Claims

- `postgres-data`: 100Gi (production: 500Gi+)
- `opensearch-data`: 100Gi (production: 1Ti+)
- `minio-data`: 100Gi (production: 1Ti+)

## Secrets Management

Create secrets before deployment:

```bash
# Database credentials
kubectl create secret generic postgres-credentials \
  --from-literal=username=elephant \
  --from-literal=password='your-secure-password' \
  --namespace elephant

# S3 credentials
kubectl create secret generic s3-credentials \
  --from-literal=access-key-id='your-access-key' \
  --from-literal=secret-access-key='your-secret-key' \
  --namespace elephant

# JWT signing key
kubectl create secret generic jwt-signing-key \
  --from-file=key=path/to/private-key.pem \
  --namespace elephant

# OIDC configuration
kubectl create secret generic oidc-config \
  --from-literal=client-id='your-client-id' \
  --from-literal=client-secret='your-client-secret' \
  --namespace elephant
```

## Monitoring

Deploy Prometheus and Grafana:

```bash
# Using kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Add Elephant dashboards
kubectl create configmap elephant-dashboards \
  --from-file=configs/observability/grafana/dashboards/ \
  --namespace monitoring
```

## Ingress

### NGINX Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: elephant
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - elephant.example.com
      secretName: elephant-tls
  rules:
    - host: elephant.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: elephant-chrome
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: elephant-repository
                port:
                  number: 1080
```

## Scaling

### Horizontal Pod Autoscaling

```bash
# Repository service
kubectl autoscale deployment elephant-repository \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  --namespace elephant

# Index service
kubectl autoscale deployment elephant-index \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  --namespace elephant
```

### Vertical Scaling

PostgreSQL and OpenSearch use StatefulSets. To scale vertically:

1. Update resource limits in manifest
2. Apply changes: `kubectl apply -f postgres.yaml`
3. Perform rolling restart if needed

## High Availability

### Database HA

Use Patroni for PostgreSQL HA:

```yaml
# StatefulSet with 3 replicas
replicas: 3
# Patroni handles leader election and failover
```

### Service HA

Run multiple replicas:

```yaml
replicas:
  repository: 3
  index: 3
  user: 2
  chrome: 3
```

## Backup Strategy

### PostgreSQL Backups

```bash
# Create CronJob for backups
kubectl apply -f kubernetes/base/postgres/backup-cronjob.yaml

# Manual backup
kubectl create job --from=cronjob/postgres-backup manual-backup-$(date +%s) \
  --namespace elephant
```

### OpenSearch Snapshots

```bash
# Register snapshot repository
curl -X PUT "opensearch:9200/_snapshot/elephant_backup" -H 'Content-Type: application/json' -d'
{
  "type": "s3",
  "settings": {
    "bucket": "elephant-backups",
    "region": "us-east-1"
  }
}'

# Create snapshot
curl -X PUT "opensearch:9200/_snapshot/elephant_backup/snapshot_$(date +%Y%m%d)"
```

## Troubleshooting

### View Logs

```bash
# Repository service
kubectl logs -l app=elephant-repository --namespace elephant --tail=100

# Follow logs
kubectl logs -f deployment/elephant-repository --namespace elephant

# Previous pod logs
kubectl logs deployment/elephant-repository --previous --namespace elephant
```

### Check Pod Status

```bash
kubectl get pods --namespace elephant
kubectl describe pod elephant-repository-xxx --namespace elephant
```

### Port Forward for Debugging

```bash
# Repository API
kubectl port-forward svc/elephant-repository 1080:1080 --namespace elephant

# PostgreSQL
kubectl port-forward svc/postgres 5432:5432 --namespace elephant
```

### Exec into Pod

```bash
kubectl exec -it deployment/elephant-repository --namespace elephant -- /bin/sh
```

## Security Best Practices

1. **Network Policies**: Restrict pod-to-pod communication
2. **RBAC**: Minimal service account permissions
3. **Pod Security Standards**: Use restricted policies
4. **Secrets**: Use external secret management (Vault, AWS Secrets Manager)
5. **TLS**: Enable TLS for all inter-service communication
6. **Image Scanning**: Scan container images for vulnerabilities

## Maintenance

### Rolling Updates

```bash
# Update image
kubectl set image deployment/elephant-repository \
  elephant-repository=ghcr.io/dimelords/elephant-repository:v2.0.0 \
  --namespace elephant

# Check rollout status
kubectl rollout status deployment/elephant-repository --namespace elephant

# Rollback if needed
kubectl rollout undo deployment/elephant-repository --namespace elephant
```

### Database Migrations

```bash
# Run migrations as a Job
kubectl apply -f kubernetes/base/postgres/migration-job.yaml

# Check migration status
kubectl logs job/postgres-migration --namespace elephant
```

## Cost Optimization

1. **Right-size resources**: Monitor actual usage and adjust requests/limits
2. **Use node affinity**: Schedule workloads on appropriate node types
3. **Spot instances**: Use spot nodes for non-critical workloads
4. **Storage tiering**: Move cold data to cheaper storage classes
5. **Autoscaling**: Scale down during off-hours

## Further Reading

- [Kustomize Documentation](https://kustomize.io/)
- [Helm Charts](https://helm.sh/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
