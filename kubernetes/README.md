# Kubernetes Deployment

Production-ready Kubernetes manifests for Elephant using Kustomize.

## Directory Structure

```
kubernetes/
├── base/                    # Base manifests
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── postgres/
│   ├── opensearch/
│   ├── minio/
│   ├── repository/
│   ├── index/
│   ├── user/
│   └── chrome/
├── overlays/
│   ├── dev/                 # Development environment
│   ├── staging/             # Staging environment
│   └── production/          # Production environment
└── helm/
    └── elephant/            # Helm chart

## Quick Start

### Deploy to Development

```bash
kubectl apply -k kubernetes/overlays/dev
```

### Deploy to Production

```bash
kubectl apply -k kubernetes/overlays/production
```

## Using Helm

```bash
# Install
helm install elephant ./kubernetes/helm/elephant \
  --namespace elephant \
  --create-namespace \
  --values values-production.yaml

# Upgrade
helm upgrade elephant ./kubernetes/helm/elephant \
  --namespace elephant \
  --values values-production.yaml
```

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
  --from-file=configs/grafana/dashboards/ \
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
