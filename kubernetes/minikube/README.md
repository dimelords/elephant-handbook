# Elephant on Minikube

Run the complete Elephant stack locally on Minikube for development and testing.

## Why Minikube?

- **Production-like environment** - Test Kubernetes manifests locally
- **Resource efficient** - Runs on your laptop with 8GB RAM
- **Fast iteration** - Quick deploy/test cycles
- **Offline development** - Works without cloud access
- **Cost-free** - No cloud bills

## Prerequisites

### Required Tools

```bash
# macOS
brew install minikube kubectl

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verify
minikube version
kubectl version --client
```

### System Requirements

**Minimum:**
- CPU: 4 cores
- RAM: 8 GB
- Disk: 40 GB free
- Docker Desktop installed

**Recommended:**
- CPU: 6 cores
- RAM: 12 GB
- Disk: 60 GB free

## Quick Start (One Command)

```bash
cd elephant-handbook/kubernetes/minikube
./start-minikube.sh
```

This script:
1. Starts Minikube with appropriate resources
2. Configures VM settings for OpenSearch
3. Deploys all Elephant services
4. Shows access URLs

Takes ~5-10 minutes.

### Validate Deployment

After deployment, verify everything is working:

```bash
./validate.sh
```

This checks:
- Minikube status
- Pod health
- Service accessibility
- Database connectivity
- OpenSearch cluster health

## Manual Setup

### 1. Start Minikube

```bash
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=40g \
  --driver=docker \
  --kubernetes-version=v1.28.0
```

### 2. Enable Addons

```bash
minikube addons enable storage-provisioner
minikube addons enable default-storageclass
minikube addons enable metrics-server
```

### 3. Configure VM Settings

```bash
# Required for OpenSearch
minikube ssh 'sudo sysctl -w vm.max_map_count=262144'
```

### 4. Deploy Elephant

```bash
# From minikube directory
kubectl apply -k .

# Or from anywhere
kubectl apply -k elephant-handbook/kubernetes/minikube
```

### 5. Wait for Pods

```bash
# Watch deployment
kubectl get pods -n elephant -w

# Wait for all pods to be Running (3-5 minutes)
```

## Access Services

### Get Minikube IP

```bash
minikube ip
# Example: 192.168.49.2
```

### Service URLs

Services are exposed via NodePort:

| Service | URL | Port | Credentials |
|---------|-----|------|-------------|
| Keycloak Admin | http://MINIKUBE_IP:30080/admin | 30080 | admin/admin |
| Repository API | http://MINIKUBE_IP:31080/twirp/ | 31080 | - |
| Index API | http://MINIKUBE_IP:31082/twirp/ | 31082 | - |
| User API | http://MINIKUBE_IP:31083/twirp/ | 31083 | - |
| MinIO Console | http://MINIKUBE_IP:30901 | 30901 | minioadmin/minioadmin |

### Alternative: Port Forwarding

```bash
# Keycloak
kubectl port-forward -n elephant svc/keycloak 8080:8080

# Repository
kubectl port-forward -n elephant svc/repository 1080:1080

# Index
kubectl port-forward -n elephant svc/index 1082:1082

# User
kubectl port-forward -n elephant svc/user 1083:1083

# MinIO Console
kubectl port-forward -n elephant svc/minio 9001:9001
```

Then access at `http://localhost:PORT`

## What's Different from Production?

### Configuration

The Minikube setup uses Kustomize patches to modify the base manifests:

- **Storage**: Changes storage class from cloud providers to Minikube's `standard` (hostPath)
- **Resources**: Reduces CPU and memory limits for local development
- **Replicas**: Sets all deployments to 1 replica
- **Networking**: Converts ClusterIP services to NodePort for direct access

### Resource Limits

Minikube configuration reduces resources for local development:

| Service | Production | Minikube |
|---------|-----------|----------|
| PostgreSQL | 1Gi RAM | 512Mi RAM |
| OpenSearch | 2Gi RAM | 1Gi RAM |
| Repository | 512Mi RAM, 2 replicas | 256Mi RAM, 1 replica |
| Index | 512Mi RAM, 2 replicas | 256Mi RAM, 1 replica |
| User | 256Mi RAM, 2 replicas | 128Mi RAM, 1 replica |
| Keycloak | 1Gi RAM, 2 replicas | 512Mi RAM, 1 replica |

### Storage

- Uses Minikube's `standard` storage class (hostPath)
- Data persists across pod restarts
- Data lost if Minikube is deleted

### Networking

- NodePort services instead of LoadBalancer
- Direct access via Minikube IP
- No ingress controller (can be added)

## Operations

### Validate Deployment

Run the validation script to check all services:

```bash
cd elephant-handbook/kubernetes/minikube
./validate.sh
```

Output shows:
- Pod status (Running/Completed/Pending)
- Service accessibility via NodePort
- Database connectivity
- OpenSearch cluster health

### View Logs

```bash
# All pods
kubectl logs -n elephant -l app.kubernetes.io/part-of=elephant --tail=50

# Specific service
kubectl logs -n elephant -l app=elephant-repository -f

# PostgreSQL
kubectl logs -n elephant postgres-0 -f
```

### Access Database

```bash
# Connect to PostgreSQL
kubectl exec -it -n elephant postgres-0 -- psql -U postgres -d elephant

# Run query
kubectl exec -n elephant postgres-0 -- \
  psql -U postgres -d elephant -c "SELECT COUNT(*) FROM document;"
```

### Restart Service

```bash
# Restart deployment
kubectl rollout restart deployment elephant-repository -n elephant

# Delete pod (will be recreated)
kubectl delete pod -n elephant -l app=elephant-repository
```

### Scale Services

```bash
# Scale up
kubectl scale deployment elephant-repository -n elephant --replicas=2

# Scale down
kubectl scale deployment elephant-repository -n elephant --replicas=1
```

### Minikube Dashboard

```bash
# Open Kubernetes dashboard
minikube dashboard

# Or get URL
minikube dashboard --url
```

## Troubleshooting

### Minikube Won't Start

```bash
# Check Docker is running
docker ps

# Delete and recreate
minikube delete
minikube start --cpus=4 --memory=8192 --disk-size=40g

# Check logs
minikube logs
```

### Pods Stuck in Pending

```bash
# Check events
kubectl get events -n elephant --sort-by='.lastTimestamp'

# Check node resources
kubectl top nodes

# Describe pod
kubectl describe pod -n elephant <pod-name>
```

### OpenSearch Won't Start

```bash
# Check vm.max_map_count
minikube ssh 'sysctl vm.max_map_count'

# Should be 262144, if not:
minikube ssh 'sudo sysctl -w vm.max_map_count=262144'

# Restart OpenSearch
kubectl delete pod -n elephant opensearch-0
```

### Out of Resources

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n elephant

# Increase Minikube resources
minikube stop
minikube delete
minikube start --cpus=6 --memory=12288 --disk-size=60g
```

### Services Not Accessible

```bash
# Check service endpoints
kubectl get svc -n elephant

# Check Minikube IP
minikube ip

# Test connectivity
curl http://$(minikube ip):31080/healthz
```

### Database Connection Errors

```bash
# Check PostgreSQL is ready
kubectl exec -n elephant postgres-0 -- pg_isready

# Check connection from pod
kubectl run -it --rm debug --image=postgres:16-alpine --restart=Never -n elephant -- \
  psql -h postgres -U postgres -d elephant -c "SELECT 1;"
```

## Development Workflow

### 1. Make Changes to Manifests

```bash
# Edit manifests in kubernetes/base/
vim elephant-handbook/kubernetes/base/elephant-repository.yaml
```

### 2. Apply Changes

```bash
# Apply from minikube directory
kubectl apply -k elephant-handbook/kubernetes/minikube

# Or specific file
kubectl apply -f elephant-handbook/kubernetes/base/elephant-repository.yaml
```

### 3. Watch Rollout

```bash
kubectl rollout status deployment elephant-repository -n elephant
```

### 4. Test Changes

```bash
# Check logs
kubectl logs -n elephant -l app=elephant-repository -f

# Test API
curl http://$(minikube ip):31080/healthz
```

## Cleanup

### Delete Elephant (Keep Minikube)

```bash
kubectl delete namespace elephant
```

### Stop Minikube (Keep Data)

```bash
minikube stop
```

### Delete Everything

```bash
minikube delete
```

## Advanced Configuration

### Increase Resources

```bash
minikube start \
  --cpus=6 \
  --memory=12288 \
  --disk-size=60g
```

### Use Different Driver

```bash
# VirtualBox
minikube start --driver=virtualbox

# Hyperkit (macOS)
minikube start --driver=hyperkit

# KVM2 (Linux)
minikube start --driver=kvm2
```

### Enable Ingress

```bash
# Enable ingress addon
minikube addons enable ingress

# Create ingress resource
kubectl apply -f ingress.yaml
```

### Mount Local Directory

```bash
# Mount local code into Minikube
minikube mount /path/to/local/code:/mnt/code

# Use in pod
volumeMounts:
  - name: code
    mountPath: /app
volumes:
  - name: code
    hostPath:
      path: /mnt/code
```

## Performance Tips

### 1. Use Local Images

```bash
# Build image locally
eval $(minikube docker-env)
docker build -t elephant-repository:local .

# Use in deployment
image: elephant-repository:local
imagePullPolicy: Never
```

### 2. Reduce Replicas

All services run with 1 replica in Minikube by default.

### 3. Disable Unused Services

```bash
# Edit kustomization.yaml to comment out services
# resources:
#   - ../base/elephant-spell.yaml  # Disabled
```

### 4. Use Resource Limits

Already configured in `kustomization.yaml` patches.

## Comparison with Other Options

| Feature | Minikube | Docker Compose | AWS EKS |
|---------|----------|----------------|---------|
| Setup Time | 5-10 min | 2-5 min | 15-20 min |
| Resources | 8GB RAM | 4GB RAM | Cloud |
| Cost | Free | Free | $200-1500/month |
| Production-like | Yes | No | Yes |
| Kubernetes | Yes | No | Yes |
| Offline | Yes | Yes | No |
| Best For | K8s testing | Quick dev | Production |

## Next Steps

1. **Configure Keycloak**: Create realm, client, users
2. **Load Schemas**: Use eleconf to configure document types
3. **Test APIs**: Use curl or Postman
4. **Deploy Frontend**: Add elephant-chrome to cluster
5. **Enable Monitoring**: Deploy Prometheus and Grafana

## See Also

- [Kubernetes Base Manifests](../base/) - Production manifests
- [Docker Compose](../../docker-compose/) - Alternative local setup
- [AWS Terraform](../../terraform/aws/) - Cloud deployment
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
