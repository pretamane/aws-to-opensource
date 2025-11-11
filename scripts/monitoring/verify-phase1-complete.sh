#!/bin/bash
# Phase 1 Verification Script
# Run this script ON THE EC2 INSTANCE to verify Phase 1 completion

echo "=========================================="
echo "Phase 1 Verification - Exporters & Targets"
echo "=========================================="
echo ""

# Check exporters are running
echo "[1/4] Checking exporters are running..."
EXPORTERS=$(docker ps | grep -E "node-exporter|cadvisor|blackbox-exporter" | wc -l)
if [ "$EXPORTERS" == "3" ]; then
    echo " All 3 exporters running"
    docker ps | grep -E "node-exporter|cadvisor|blackbox-exporter"
else
    echo " Expected 3 exporters, found $EXPORTERS"
fi
echo ""

# Test exporter endpoints
echo "[2/4] Testing exporter endpoints..."
echo "Node Exporter:"
docker exec prometheus wget -qO- http://node-exporter:9100/metrics 2>/dev/null | head -n 2 || echo "   Failed"
echo "cAdvisor:"
docker exec prometheus wget -qO- http://cadvisor:8080/metrics 2>/dev/null | head -n 2 || echo "   Failed"
echo "Blackbox Exporter:"
docker exec prometheus wget -qO- http://blackbox-exporter:9115/metrics 2>/dev/null | head -n 2 || echo "   Failed"
echo ""

# Check Prometheus targets
echo "[3/4] Checking Prometheus targets..."
TARGETS=$(docker exec prometheus wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null | python3 -c "import sys, json; print(len(json.load(sys.stdin)['data']['activeTargets']))" 2>/dev/null)
if [ ! -z "$TARGETS" ]; then
    echo " Prometheus has $TARGETS targets"
    echo ""
    echo "Target Status:"
    docker exec prometheus wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
targets = data['data']['activeTargets']
for t in targets:
    status = '' if t['health'] == 'up' else ''
    print(f\"  {status} {t['labels']['job']} - {t['health']}\")
"
else
    echo " Failed to query Prometheus targets"
fi
echo ""

# Test blackbox probe
echo "[4/4] Testing blackbox probe..."
PROBE_SUCCESS=$(docker exec prometheus wget -qO- "http://blackbox-exporter:9115/probe?target=http://caddy:80&module=http_2xx" 2>/dev/null | grep -c "probe_success 1" || echo "0")
if [ "$PROBE_SUCCESS" == "1" ]; then
    echo " Blackbox probe working"
else
    echo " Blackbox probe failed"
fi
echo ""

echo "=========================================="
echo "Phase 1 Verification Complete"
echo "=========================================="

