# Configuration Files

This directory contains ready-to-use configuration files for Elephant infrastructure.

## Directory Structure

```
configs/
├── observability/           # Monitoring and observability stack
│   ├── grafana/
│   │   ├── dashboards/     # Pre-built Grafana dashboards
│   │   └── provisioning/   # Grafana provisioning configs
│   ├── prometheus/
│   │   ├── alerts.yml      # Alert rules
│   │   └── prometheus.yml  # Prometheus configuration
│   ├── tempo/              # Distributed tracing config
│   ├── loki/               # Log aggregation config
│   └── alloy/              # Faro receiver config
├── opensearch/
│   ├── Dockerfile          # Custom OpenSearch with ICU plugin
│   └── README.md           # OpenSearch configuration docs
└── database/
    ├── init.sql            # Initial database setup
    └── README.md           # Database configuration docs
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
  - ./configs/observability/prometheus/alerts.yml:/etc/prometheus/alerts.yml
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
