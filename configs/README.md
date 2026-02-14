# Configuration Files

This directory contains ready-to-use configuration files for Elephant infrastructure.

## Directory Structure

```
configs/
├── grafana/
│   └── dashboards/          # Pre-built Grafana dashboards
│       ├── elephant-overview.json
│       ├── elephant-repository.json
│       └── elephant-frontend.json
├── prometheus/
│   ├── alerts.yml          # Alert rules
│   └── prometheus.yml      # Prometheus configuration
└── database/
    └── init.sql            # Initial database setup
```

## Usage

### Grafana Dashboards

Import dashboards via Grafana UI:
1. Go to Dashboards → Import
2. Upload JSON file or paste content
3. Select Prometheus data source

Or using provisioning:
```yaml
# grafana/provisioning/dashboards/elephant.yml
apiVersion: 1
providers:
  - name: 'Elephant'
    folder: 'Elephant'
    type: file
    options:
      path: /etc/grafana/dashboards/elephant
```

### Prometheus Alerts

Add to Prometheus configuration:
```yaml
rule_files:
  - /etc/prometheus/alerts.yml
```

Or mount in Docker:
```yaml
volumes:
  - ./configs/prometheus/alerts.yml:/etc/prometheus/alerts.yml
```

### Database Initialization

For Docker Compose:
```yaml
postgres:
  volumes:
    - ./configs/database/init.sql:/docker-entrypoint-initdb.d/init.sql
```

For manual setup:
```bash
psql -U postgres -d elephant -f configs/database/init.sql
```

## Customization

These are starting templates. Customize for your environment:

- **Alert thresholds**: Adjust based on your traffic patterns
- **Dashboard panels**: Add/remove based on what you monitor
- **Database schema**: Add organization-specific tables
