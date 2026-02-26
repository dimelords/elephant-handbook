# Minikube Quick Reference

One-page cheat sheet for Elephant on Minikube.

## Start/Stop

```bash
# Start everything
./start-minikube.sh

# Validate deployment
./validate.sh

# Stop Minikube (keep data)
minikube stop

# Delete everything
minikube delete
```

## Access Services

```bash
# Get Minikube IP
export MINIKUBE_IP=$(minikube ip)

# Service URLs
echo "Keycloak:   http://$MINIKUBE_IP:30080/admin"
echo "Repository: http://$MINIKUBE_IP:31080/twirp/"
echo "Index:      http://$MINIKUBE_IP:31082/twirp/"
echo "User:       http://$MINIKUBE_IP:31083/twirp/"
echo "MinIO:      http://$MINIKUBE_IP:30901"
```

## Common Commands

```bash
# View all pods
kubectl get pods -n elephant

# View logs
kubectl logs -n elephant -l app=elephant-repository -f

# Access database
kubectl exec -it -n elephant postgres-0 -- psql -U postgres -d elephant

# Restart service
kubectl rollout restart deployment elephant-repository -n elephant

# Port forward
kubectl port-forward -n elephant svc/repository 1080:1080

# Dashboard
minikube dashboard
```

## Troubleshooting

```bash
# Check events
kubectl get events -n elephant --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod -n elephant <pod-name>

# Check resources
kubectl top nodes
kubectl top pods -n elephant

# Fix OpenSearch
minikube ssh 'sudo sysctl -w vm.max_map_count=262144'

# Test connectivity
curl http://$(minikube ip):31080/healthz
```

## Credentials

| Service | Username | Password |
|---------|----------|----------|
| Keycloak | admin | admin |
| PostgreSQL | postgres | postgres |
| MinIO | minioadmin | minioadmin |

## Resource Usage

- CPUs: 4
- Memory: 8GB
- Disk: 40GB
- Pods: ~15
- Services: 8

## Ports

| Port | Service |
|------|---------|
| 30080 | Keycloak |
| 31080 | Repository |
| 31082 | Index |
| 31083 | User |
| 30901 | MinIO Console |

## Files

- `kustomization.yaml` - Kustomize config
- `start-minikube.sh` - Startup script
- `validate.sh` - Validation script
- `README.md` - Full documentation
- `SUMMARY.md` - Detailed summary
- `QUICKREF.md` - This file
