# Observability Overview

## Introduction

Elephant uses a comprehensive observability stack to monitor system health, performance, and user experience. The stack consists of:

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Grafana Faro**: Frontend observability and Real User Monitoring (RUM)
- **Loki** (optional): Log aggregation
- **OpenTelemetry** (future): Distributed tracing

## Observability Philosophy

### The Three Pillars

**1. Metrics** (What is happening)
- System health (CPU, memory, requests)
- Business metrics (documents created, searches)
- Performance metrics (latency, throughput)

**2. Logs** (Why it's happening)
- Error messages and stack traces
- Audit trails
- Debug information

**3. Traces** (How it's happening)
- Request flow across services
- Performance bottlenecks
- Service dependencies

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend (Browser)                    │
│                                                          │
│  ┌────────────────┐        ┌──────────────────┐        │
│  │ elephant-chrome│───────►│  Grafana Faro    │        │
│  │                │        │   (RUM Agent)    │        │
│  └────────────────┘        └─────────┬────────┘        │
└───────────────────────────────────────┼──────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────┐
                        │    Faro Collector         │
                        │  (metrics, logs, traces)  │
                        └────────────┬──────────────┘
                                     │
        ┌────────────────────────────┼────────────────────┐
        │                            │                    │
        ▼                            ▼                    ▼
┌───────────────┐          ┌─────────────────┐   ┌──────────────┐
│   Prometheus  │          │      Loki       │   │    Tempo     │
│   (Metrics)   │          │     (Logs)      │   │   (Traces)   │
└───────┬───────┘          └────────┬────────┘   └──────┬───────┘
        │                           │                    │
        │                           │                    │
        └───────────────────────────┼────────────────────┘
                                    │
                                    ▼
                        ┌───────────────────────┐
                        │      Grafana          │
                        │  (Visualization)      │
                        └───────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                    Backend Services                      │
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ repository  │  │    index    │  │    user     │    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
│         │                │                 │            │
│         └────────────────┼─────────────────┘            │
│                          │                              │
│                  /metrics endpoint                      │
└──────────────────────────┼──────────────────────────────┘
                           │
                           ▼
                   ┌──────────────┐
                   │  Prometheus  │
                   │   (Scraper)  │
                   └──────────────┘
```

## Metrics Collection

### Backend Metrics (Prometheus)

All Go services expose Prometheus metrics at `/metrics`:

**Standard Metrics**
- `http_requests_total` - Total HTTP requests by method, path, status
- `http_request_duration_seconds` - Request latency histogram
- `http_requests_in_flight` - Current active requests

**Business Metrics**
- `documents_created_total` - Documents created
- `documents_updated_total` - Documents updated
- `document_versions_total` - Total versions created
- `archive_operations_total` - S3 archive operations
- `event_log_position` - Current event log position
- `index_lag_seconds` - Time lag between repository and index

**Resource Metrics**
- `go_goroutines` - Number of goroutines
- `go_memstats_alloc_bytes` - Allocated memory
- `process_cpu_seconds_total` - CPU usage

### Example Instrumentation

```go
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    documentsCreated = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "documents_created_total",
            Help: "Total number of documents created",
        },
        []string{"type", "unit"},
    )

    requestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "http_request_duration_seconds",
            Help: "HTTP request latency",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path", "status"},
    )
)

// In handler
start := time.Now()
documentsCreated.WithLabelValues(docType, unit).Inc()
duration := time.Since(start).Seconds()
requestDuration.WithLabelValues("POST", "/documents", "200").Observe(duration)
```

### Frontend Metrics (Grafana Faro)

Faro collects:

**Performance Metrics**
- Page load time
- Time to First Byte (TTFB)
- First Contentful Paint (FCP)
- Largest Contentful Paint (LCP)
- Cumulative Layout Shift (CLS)
- API call latency

**User Experience**
- Session duration
- Page views
- Navigation paths
- User interactions

**Errors**
- JavaScript errors
- API errors
- Network errors

## Logging

### Structured Logging

All services use structured JSON logging:

```go
import "go.uber.org/zap"

logger, _ := zap.NewProduction()
defer logger.Sync()

logger.Info("document created",
    zap.String("uuid", doc.UUID),
    zap.String("type", doc.Type),
    zap.Int("version", doc.Version),
    zap.String("user", user.ID),
)
```

Log output:
```json
{
  "level": "info",
  "ts": 1707900000.123,
  "msg": "document created",
  "uuid": "doc-123",
  "type": "core/article",
  "version": 5,
  "user": "user-456"
}
```

### Log Levels

- **DEBUG**: Detailed information for troubleshooting
- **INFO**: General informational messages
- **WARN**: Warning messages, something unexpected
- **ERROR**: Error messages, operation failed
- **FATAL**: Critical errors, service cannot continue

### Log Aggregation with Loki

Loki collects logs from all services:

```yaml
# Promtail configuration
clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: elephant-services
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        target_label: 'container'
```

## Dashboards

### Pre-built Grafana Dashboards

Available in `configs/grafana/dashboards/`:

**1. Elephant Overview**
- System health across all services
- Request rate and latency
- Error rate
- Resource usage

**2. Repository Service**
- Document operations (create, update, read, delete)
- Version creation rate
- Event log position
- Archive operations
- PostgreSQL connection pool

**3. Index Service**
- Indexing lag
- Search queries per second
- Index operations
- OpenSearch cluster health

**4. User Service**
- User events
- Inbox messages
- Active users

**5. Frontend Performance**
- Page load times
- API call latency
- JavaScript errors
- User sessions

### Example Dashboard JSON

```json
{
  "dashboard": {
    "title": "Elephant Repository",
    "panels": [
      {
        "title": "Documents Created",
        "targets": [
          {
            "expr": "rate(documents_created_total[5m])"
          }
        ]
      },
      {
        "title": "Request Latency p95",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ]
      }
    ]
  }
}
```

## Alerting

### Alert Rules (Prometheus)

```yaml
# alerts.yml
groups:
  - name: elephant
    interval: 30s
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate on {{ $labels.service }}"
          description: "Error rate is {{ $value }} requests/sec"

      # High latency
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1.0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency on {{ $labels.service }}"
          description: "P95 latency is {{ $value }}s"

      # Index lag
      - alert: IndexLagging
        expr: index_lag_seconds > 300
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Search index is lagging"
          description: "Index is {{ $value }}s behind repository"

      # Service down
      - alert: ServiceDown
        expr: up{job="elephant"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.service }} is down"
          description: "Service has been down for 2 minutes"
```

### Alert Channels

Configure alert destinations:

```yaml
# Alertmanager configuration
route:
  group_by: ['alertname']
  receiver: 'team-notifications'

receivers:
  - name: 'team-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/...'
        channel: '#elephant-alerts'
        title: 'Elephant Alert'
    email_configs:
      - to: 'ops@example.com'
        from: 'alertmanager@example.com'
    pagerduty_configs:
      - service_key: '...'
```

## Grafana Faro Setup

### Frontend Integration

```typescript
// src/observability/faro.ts
import { initializeFaro } from '@grafana/faro-web-sdk';

export function initObservability() {
  initializeFaro({
    url: 'https://faro-collector.example.com/collect',
    app: {
      name: 'elephant-chrome',
      version: '1.0.0',
      environment: 'production',
    },
    instrumentations: {
      fetch: true,
      xhr: true,
      console: true,
      errors: true,
      webVitals: true,
    },
  });
}
```

### Custom Events

```typescript
import { faro } from '@grafana/faro-web-sdk';

// Track custom events
faro.api.pushEvent('document_saved', {
  documentType: 'core/article',
  duration: 1250,
});

// Track errors
faro.api.pushError(new Error('Failed to save document'));

// Track measurements
faro.api.pushMeasurement({
  type: 'search_query',
  values: {
    duration: 250,
    results: 42,
  },
});
```

## Distributed Tracing (Future)

OpenTelemetry integration planned for distributed tracing:

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/trace"
)

func handleRequest(ctx context.Context, req *Request) {
    tracer := otel.Tracer("elephant-repository")
    ctx, span := tracer.Start(ctx, "handleRequest")
    defer span.End()

    // Nested spans
    ctx, dbSpan := tracer.Start(ctx, "database.query")
    result := db.Query(ctx, query)
    dbSpan.End()

    ctx, s3Span := tracer.Start(ctx, "s3.upload")
    s3.Upload(ctx, data)
    s3Span.End()
}
```

## Cost Optimization

### Metrics Retention

Configure retention policies to manage costs:

```yaml
# Prometheus retention
storage:
  tsdb:
    retention.time: 15d
    retention.size: 50GB
```

### Sampling

For high-traffic systems, use sampling:

```go
// Sample 10% of traces
sampler := trace.TraceIDRatioBased(0.1)
```

### Log Level in Production

Use INFO or WARN level in production to reduce log volume:

```bash
LOG_LEVEL=info
```

## Runbooks

Each alert should have a runbook:

### HighErrorRate Runbook

1. Check service logs for error patterns
2. Review recent deployments
3. Check database connectivity
4. Verify external service status
5. Scale service if needed

### IndexLagging Runbook

1. Check OpenSearch cluster health
2. Review index service logs
3. Verify event log accessibility
4. Check network latency
5. Consider reindexing if lag is severe

## Best Practices

1. **Dashboard Organization**: Group by service and audience (dev, ops, business)
2. **Alert Fatigue**: Only alert on actionable issues
3. **SLOs**: Define Service Level Objectives for critical paths
4. **Gradual Rollout**: Enable new monitoring incrementally
5. **Documentation**: Keep runbooks up to date
6. **Regular Review**: Review and update dashboards quarterly
7. **Cost Awareness**: Monitor and optimize observability costs

## Next Steps

- [Prometheus Setup](prometheus.md)
- [Grafana Configuration](grafana.md)
- [Grafana Faro Integration](faro.md)
- [Logging Strategy](logging.md)
- [Alert Configuration](alerting.md)
