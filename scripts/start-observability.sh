#!/bin/bash
# Quick start script for Elephant Observability Stack

set -e

echo "🐘 Starting Elephant Observability Stack..."
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose not found. Please install Docker Compose."
    exit 1
fi

# Start the observability stack
echo "📊 Starting Grafana, Tempo, Loki, Prometheus, and Alloy..."
docker-compose up -d grafana tempo loki prometheus alloy

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 5

# Check if services are running
if ! docker-compose ps | grep -q "grafana.*Up"; then
    echo "❌ Grafana failed to start. Check logs with: docker-compose logs grafana"
    exit 1
fi

echo ""
echo "✅ Observability stack is ready!"
echo ""
echo "📍 Access points:"
echo "   Grafana:          http://localhost:3000"
echo "   Alloy (Faro):     http://localhost:12345/collect"
echo "   Prometheus:       http://localhost:9090"
echo "   Tempo:            http://localhost:3200"
echo "   Loki:             http://localhost:3100"
echo ""
echo "📚 Documentation: ./OBSERVABILITY.md"
echo ""
echo "🎯 Next steps:"
echo "   1. Start Elephant services: docker-compose up -d"
echo "   2. Open Grafana: http://localhost:3000"
echo "   3. View dashboard: Dashboards → Elephant → Elephant - Faro Overview"
echo ""
