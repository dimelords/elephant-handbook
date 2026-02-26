# Running Elephant on Minikube

This guide shows how to run the complete Elephant stack locally using Minikube for Kubernetes development and testing.

## Why Minikube?

Minikube is ideal for:
- Testing Kubernetes manifests locally
- Learning Kubernetes deployment
- Developing Helm charts
- Testing with a production-like environment
- CI/CD pipeline testing

## Prerequisites

### Install Required Tools

```bash
# Install Minikube
# macOS
brew install minikube

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install kubectl (if not already installed)
brew install kubectl  # macOS
# or follow: https://kubernetes.io/docs/tasks/tools/

# Verify installations
minikube version
kubectl version --client
```

### System Requirements

**Minimum**
- CPU: 4 cores
- Memory: 8 GB RAM
- Disk: 40 GB free space
- Docker or VirtualBox

**Recommended**
- CPU: 6 cores
- Memory: 12 GB RAM
- Disk: 60 GB free space
- Docker Desktop (faster than VirtualBox)

## Quick Start

### 1. Start Minikube

```bash
# Start with recommended resources
minikube start \
  --cpus=6 \
  --memory=12288 \
  --disk-size=60g \
  --driver=docker \
  --kubernetes-version=v1.28.0

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

### 2. Enable Required Addons

```bash
# Enable ingress controller
minikube addons enable ingress

# Enable metrics server (for HPA)
minikube addons enable metrics-server

# Enable storage provisioner (default)
minikube addons enable storage-provisioner

# Enable dashboard (optional)
minikube addons enable dashboard

# Verify addons
minikube addons list
```

### 3. Configure Local Docker Registry (Optional)

For using locally built images:

```bash
# Enable registry addon
minikube addons enable registry

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)

# Now you can build images directly in Minikube
cd /path/to/elephant-repository
docker build -t elephant-repository:dev .

# Verify image is available
docker images | grep elephant
```

### 4. Deploy Elephant

#### Option A: Use Kustomize (Recommended)

Create a Minikube-specific overlay:

```bash
# Create minikube overlay directory
mkdir -p kubernetes/overlays/minikube

# Create kustomization.yaml
cat > kubernetes/overlays/minikube/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: elephant

resources:
  - ../../base

# Reduce resources for local development
patches:
  - patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: elephant-repository
      spec:
        replicas: 1
        template:
          spec:
            containers:
              - name: repository
                resources:
                  requests:
                    cpu: 250m
                    memory: 256Mi
                  limits:
                    cpu: 1000m
                    memory: 1Gi
    target:
      kind: Deployment
      name: elephant-repository

  - patch: |-
      apiVersion: apps/v1
      kind: StatefulSet
      metadata:
        name: postgres
      spec:
        replicas: 1
        template:
          spec:
            containers:
              - name: postgres
                resources:
                  requests:
                    cpu: 250m
                    memory: 512Mi
                  limits:
                    cpu: 1000m
                    memory: 2Gi
        volumeClaimTemplates:
          - metadata:
              name: postgres-data
            spec:
              accessModes: ["ReadWriteOnce"]
              storageClassName: standard
              resources:
                requests:
                  storage: 10Gi
    target:
      kind: StatefulSet
      name: postgres

# Use local images (if built with eval $(minikube docker-env))
images:
  - name: ghcr.io/dimelords/elephant-repository
    newName: elephant-repository
    newTag: dev
  - name: ghcr.io/dimelords/elephant-index
    newName: elephant-index
    newTag: dev
  - name: ghcr.io/dimelords/elephant-user
    newName: elephant-user
    newTag: dev
EOF
```

Deploy:

```bash
# Create namespace
kubectl create namespace elephant

# Create secrets
kubectl create secret generic postgres-credentials \
  --from-literal=username=postgres \
  --from-literal=password=postgres \
  --namespace elephant

kubectl create secret generic s3-credentials \
  --from-literal=access-key-id=minioadmin \
  --from-literal=secret-access-key=minioadmin \
  --namespace elephant

kubectl create secret generic postgres-connection \
  --from-literal=connection-string='postgres://postgres:postgres@postgres:5432/elephant?sslmode=disable' \
  --namespace elephant

# Deploy
kubectl apply -k kubernetes/overlays/minikube

# Watch deployment
kubectl get pods -n elephant -w
```

#### Option B: Simplified Development Stack

Create a simplified deployment for development:

```bash
cat > minikube-elephant.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: elephant
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init
  namespace: elephant
data:
  init.sql: |
    CREATE DATABASE elephant;
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: elephant
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - name: POSTGRES_PASSWORD
              value: postgres
            - name: POSTGRES_DB
              value: elephant
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: elephant
spec:
  ports:
    - port: 5432
  selector:
    app: postgres
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: elephant
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
        - name: minio
          image: minio/minio:latest
          args:
            - server
            - /data
            - --console-address
            - ":9001"
          env:
            - name: MINIO_ROOT_USER
              value: minioadmin
            - name: MINIO_ROOT_PASSWORD
              value: minioadmin
          ports:
            - containerPort: 9000
            - containerPort: 9001
          volumeMounts:
            - name: minio-data
              mountPath: /data
      volumes:
        - name: minio-data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: elephant
spec:
  ports:
    - port: 9000
      name: api
    - port: 9001
      name: console
  selector:
    app: minio
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opensearch
  namespace: elephant
spec:
  replicas: 1
  selector:
    matchLabels:
      app: opensearch
  template:
    metadata:
      labels:
        app: opensearch
    spec:
      containers:
        - name: opensearch
          image: opensearchproject/opensearch:2.11.0
          env:
            - name: discovery.type
              value: single-node
            - name: DISABLE_SECURITY_PLUGIN
              value: "true"
            - name: OPENSEARCH_JAVA_OPTS
              value: "-Xms512m -Xmx512m"
          ports:
            - containerPort: 9200
          volumeMounts:
            - name: opensearch-data
              mountPath: /usr/share/opensearch/data
      volumes:
        - name: opensearch-data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: opensearch
  namespace: elephant
spec:
  ports:
    - port: 9200
  selector:
    app: opensearch
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elephant-repository
  namespace: elephant
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elephant-repository
  template:
    metadata:
      labels:
        app: elephant-repository
    spec:
      containers:
        - name: repository
          image: ghcr.io/dimelords/elephant-repository:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 1080
          env:
            - name: CONN_STRING
              value: "postgres://postgres:postgres@postgres:5432/elephant?sslmode=disable"
            - name: S3_ENDPOINT
              value: "http://minio:9000/"
            - name: S3_BUCKET
              value: "elephant-archive"
            - name: S3_ACCESS_KEY_ID
              value: "minioadmin"
            - name: S3_ACCESS_KEY_SECRET
              value: "minioadmin"
            - name: LOG_LEVEL
              value: "debug"
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 1000m
              memory: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: elephant-repository
  namespace: elephant
spec:
  type: NodePort
  ports:
    - port: 1080
      targetPort: 1080
      nodePort: 31080
  selector:
    app: elephant-repository
EOF

# Deploy
kubectl apply -f minikube-elephant.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app=postgres -n elephant --timeout=300s
kubectl wait --for=condition=ready pod -l app=elephant-repository -n elephant --timeout=300s
```

### 5. Access Services

#### Using NodePort

```bash
# Get Minikube IP
minikube ip

# Access services
# Repository: http://$(minikube ip):31080
# Or use minikube service command
minikube service elephant-repository -n elephant --url
```

#### Using Port Forwarding

```bash
# Repository
kubectl port-forward -n elephant svc/elephant-repository 1080:1080

# PostgreSQL (for debugging)
kubectl port-forward -n elephant svc/postgres 5432:5432

# MinIO console
kubectl port-forward -n elephant svc/minio 9001:9001

# OpenSearch
kubectl port-forward -n elephant svc/opensearch 9200:9200
```

#### Using Minikube Tunnel (LoadBalancer)

```bash
# In a separate terminal, start tunnel
minikube tunnel

# Now LoadBalancer services will get external IPs
kubectl get svc -n elephant
```

### 6. Access Kubernetes Dashboard

```bash
# Start dashboard
minikube dashboard

# Or get URL
minikube dashboard --url
```

## Building Images Locally

### Option 1: Use Minikube's Docker Daemon

```bash
# Point Docker to Minikube's daemon
eval $(minikube docker-env)

# Build images
cd /path/to/elephant-repository
docker build -t elephant-repository:dev .

cd /path/to/elephant-index
docker build -t elephant-index:dev .

cd /path/to/elephant-user
docker build -t elephant-user:dev .

# List images (should show in Minikube)
docker images | grep elephant

# Reset Docker to your host (when done)
eval $(minikube docker-env -u)
```

### Option 2: Push to Minikube Registry

```bash
# Enable registry
minikube addons enable registry

# Get registry address
kubectl get svc -n kube-system registry

# Tag and push
docker tag elephant-repository:dev localhost:5000/elephant-repository:dev
docker push localhost:5000/elephant-repository:dev

# Use in manifests
# image: localhost:5000/elephant-repository:dev
```

### Option 3: Use Image Load

```bash
# Build image normally
docker build -t elephant-repository:dev .

# Load into Minikube
minikube image load elephant-repository:dev

# Or save and import
docker save elephant-repository:dev | minikube image load -
```

## Testing and Development Workflow

### 1. Make Code Changes

```bash
# Edit code in elephant-repository
vim cmd/elephant-repository/main.go
```

### 2. Rebuild and Redeploy

```bash
# Use Minikube's Docker
eval $(minikube docker-env)

# Rebuild
docker build -t elephant-repository:dev .

# Force pod restart
kubectl rollout restart deployment elephant-repository -n elephant

# Watch logs
kubectl logs -f deployment/elephant-repository -n elephant
```

### 3. Test Changes

```bash
# Get service URL
export REPO_URL=$(minikube service elephant-repository -n elephant --url)

# Test API
curl $REPO_URL/healthz

# Get mock token
curl -X POST $REPO_URL/token \
  -d grant_type=password \
  -d 'username=Dev User' \
  -d 'scope=doc_read doc_write'
```

## Debugging

### View Logs

```bash
# All pods in namespace
kubectl logs -f --all-containers=true -n elephant

# Specific pod
kubectl logs -f elephant-repository-xxx -n elephant

# Previous container (after crash)
kubectl logs elephant-repository-xxx -n elephant --previous

# Tail logs
kubectl logs --tail=50 -f deployment/elephant-repository -n elephant
```

### Exec into Pods

```bash
# Repository pod
kubectl exec -it deployment/elephant-repository -n elephant -- /bin/sh

# PostgreSQL
kubectl exec -it statefulset/postgres -n elephant -- psql -U postgres -d elephant
```

### Describe Resources

```bash
# Pod details
kubectl describe pod elephant-repository-xxx -n elephant

# Deployment events
kubectl describe deployment elephant-repository -n elephant

# Service endpoints
kubectl describe svc elephant-repository -n elephant
```

### Check Events

```bash
# All events in namespace
kubectl get events -n elephant --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n elephant -w
```

## Common Issues

### Pods Stuck in Pending

```bash
# Check node resources
kubectl describe node minikube

# Check storage
kubectl get pv
kubectl get pvc -n elephant

# If storage issue, delete and recreate PVC
kubectl delete pvc postgres-data-postgres-0 -n elephant
```

### ImagePullBackOff

```bash
# Check if image exists
eval $(minikube docker-env)
docker images | grep elephant

# Use imagePullPolicy: IfNotPresent or Never for local images
kubectl patch deployment elephant-repository -n elephant -p '{"spec":{"template":{"spec":{"containers":[{"name":"repository","imagePullPolicy":"Never"}]}}}}'
```

### Service Not Accessible

```bash
# Check service
kubectl get svc -n elephant

# Check endpoints
kubectl get endpoints elephant-repository -n elephant

# If using tunnel
sudo minikube tunnel  # May need sudo for LoadBalancer

# Or use port-forward
kubectl port-forward -n elephant svc/elephant-repository 1080:1080
```

### Out of Resources

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n elephant

# Resize Minikube
minikube stop
minikube delete
minikube start --cpus=8 --memory=16384
```

## Persistence

### Data Survives Pod Restarts

StatefulSets and PersistentVolumeClaims ensure data persists:

```bash
# List PVCs
kubectl get pvc -n elephant

# Describe PVC
kubectl describe pvc postgres-data-postgres-0 -n elephant
```

### Data Survives Minikube Restarts

PersistentVolumes are stored in Minikube's Docker container:

```bash
# Stop (data preserved)
minikube stop

# Start again
minikube start

# Pods will reconnect to existing volumes
```

### Clean Up Data

```bash
# Delete PVCs (removes data)
kubectl delete pvc --all -n elephant

# Or delete entire namespace (nuclear option)
kubectl delete namespace elephant
```

## Monitoring

### Install Prometheus + Grafana

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Default credentials: admin / prom-operator

# Import Elephant dashboards
kubectl create configmap elephant-dashboards \
  --from-file=../../configs/observability/grafana/dashboards/ \
  -n monitoring
```

### Resource Monitoring

```bash
# Node resources
kubectl top node

# Pod resources
kubectl top pods -n elephant

# Continuous monitoring
watch kubectl top pods -n elephant
```

## Cleanup

### Delete Elephant Namespace

```bash
kubectl delete namespace elephant
```

### Stop Minikube

```bash
minikube stop
```

### Delete Minikube Cluster

```bash
minikube delete
```

## Minikube vs Docker Compose

| Feature | Minikube | Docker Compose |
|---------|----------|----------------|
| **Closer to Production** | ✅ Kubernetes native | ❌ Different orchestration |
| **Learning Curve** | Higher | Lower |
| **Resource Usage** | Higher (~4-6 GB) | Lower (~2-3 GB) |
| **Startup Time** | Slower (~2-3 min) | Faster (~30 sec) |
| **Scaling Testing** | ✅ HPA, replicas | ❌ Limited |
| **Service Discovery** | ✅ K8s DNS | Docker networks |
| **Ingress/Load Balancer** | ✅ Native support | ❌ Requires workarounds |
| **Best For** | K8s development, CI/CD testing | Quick local dev |

## When to Use Minikube

Use Minikube when:
- Testing Kubernetes manifests
- Developing Helm charts
- Testing scaling and HA
- Preparing for production deployment
- Learning Kubernetes

Use Docker Compose when:
- Quick local development
- Simpler setup needed
- Lower resource requirements
- Not using Kubernetes in production

## Advanced: Multi-Node Cluster

```bash
# Start with multiple nodes (experimental)
minikube start --nodes=3 --cpus=8 --memory=16384

# Verify nodes
kubectl get nodes

# Test pod distribution
kubectl get pods -n elephant -o wide
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test on Minikube

on: [push, pull_request]

jobs:
  minikube-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Start Minikube
        uses: medyagh/setup-minikube@latest
        with:
          cpus: 4
          memory: 8192

      - name: Deploy Elephant
        run: |
          kubectl apply -f minikube-elephant.yaml
          kubectl wait --for=condition=ready pod -l app=elephant-repository -n elephant --timeout=300s

      - name: Run Tests
        run: |
          kubectl run test --image=curlimages/curl:latest --rm -it --restart=Never -- \
            curl http://elephant-repository.elephant:1080/healthz
```

## Further Reading

- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Elephant Kubernetes Guide](../../kubernetes/README.md)
- [Docker Compose Development](docker-compose.md)
