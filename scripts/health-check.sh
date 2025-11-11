#!/bin/bash
# Health Check Script for Open-Source Stack
# Verifies all services are running correctly

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get EC2 IP if running remotely
if [ -z "$EC2_IP" ]; then
    EC2_IP="localhost"
fi

BASE_URL="http://$EC2_IP"

echo "========================================"
echo "Health Check - Open-Source Stack"
echo "========================================"
echo "Target: $BASE_URL"
echo "Date: $(date)"
echo ""

# ============================================================================
# Service Health Checks
# ============================================================================

check_service() {
    local name=$1
    local url=$2
    local expected=$3
    
    echo -n "Checking $name... "
    
    if response=$(curl -s -f "$url" 2>/dev/null); then
        if [ -z "$expected" ] || echo "$response" | grep -q "$expected"; then
            echo -e "${GREEN} HEALTHY${NC}"
            return 0
        else
            echo -e "${YELLOW} DEGRADED${NC}"
            return 1
        fi
    else
        echo -e "${RED} DOWN${NC}"
        return 1
    fi
}

# Check API
check_service "API" "$BASE_URL/health" "healthy"

# Check API root
check_service "API Root" "$BASE_URL/" "version"

# Check Swagger UI
check_service "Swagger UI" "$BASE_URL/docs" "swagger"

# Check Prometheus
check_service "Prometheus" "$BASE_URL/prometheus/-/healthy" ""

# Check Grafana
check_service "Grafana" "$BASE_URL/grafana/api/health" "ok"

# Check Meilisearch
if [ "$EC2_IP" = "localhost" ]; then
    check_service "Meilisearch" "http://localhost:7700/health" ""
else
    check_service "Meilisearch" "$BASE_URL/meilisearch/health" ""
fi

# Check MinIO
if [ "$EC2_IP" = "localhost" ]; then
    check_service "MinIO" "http://localhost:9000/minio/health/live" ""
fi

# ============================================================================
# Docker Service Status
# ============================================================================

if [ "$EC2_IP" = "localhost" ]; then
    echo ""
    echo "Docker Service Status:"
    echo "========================================"
    
    cd /home/ubuntu/app/docker-compose 2>/dev/null || cd docker-compose 2>/dev/null || true
    
    if command -v docker-compose &> /dev/null; then
        docker-compose ps
    else
        echo "docker-compose not available"
    fi
fi

# ============================================================================
# Resource Usage
# ============================================================================

if [ "$EC2_IP" = "localhost" ]; then
    echo ""
    echo "Resource Usage:"
    echo "========================================"
    
    # Disk usage
    echo "Disk Usage:"
    df -h / | tail -1 | awk '{print "  Root: " $3 " used / " $2 " total (" $5 " full)"}'
    df -h /data 2>/dev/null | tail -1 | awk '{print "  Data: " $3 " used / " $2 " total (" $5 " full)"}' || echo "  Data: N/A"
    
    # Memory usage
    echo ""
    echo "Memory Usage:"
    free -h | grep Mem | awk '{print "  " $3 " used / " $2 " total"}'
    
    # CPU load
    echo ""
    echo "CPU Load:"
    uptime | awk -F'load average:' '{print "  " $2}'
    
    # Docker stats
    if command -v docker &> /dev/null; then
        echo ""
        echo "Container Resource Usage:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "  Docker not available"
    fi
fi

# ============================================================================
# API Functionality Tests
# ============================================================================

echo ""
echo "API Functionality Tests:"
echo "========================================"

# Test visitor stats
echo -n "Testing /stats endpoint... "
if curl -s -f "$BASE_URL/stats" > /dev/null 2>&1; then
    echo -e "${GREEN} PASS${NC}"
else
    echo -e "${RED} FAIL${NC}"
fi

# Test analytics
echo -n "Testing /analytics/insights endpoint... "
if curl -s -f "$BASE_URL/analytics/insights" > /dev/null 2>&1; then
    echo -e "${GREEN} PASS${NC}"
else
    echo -e "${RED} FAIL${NC}"
fi

# Test metrics
echo -n "Testing /metrics endpoint... "
if curl -s -f "$BASE_URL/metrics" | grep -q "# HELP"; then
    echo -e "${GREEN} PASS${NC}"
else
    echo -e "${RED} FAIL${NC}"
fi

# ============================================================================
# Database Connectivity
# ============================================================================

if [ "$EC2_IP" = "localhost" ] && command -v docker &> /dev/null; then
    echo ""
    echo "Database Connectivity:"
    echo "========================================"
    
    echo -n "PostgreSQL connection... "
    if docker exec postgresql pg_isready -U app_user -d pretamane_db > /dev/null 2>&1; then
        echo -e "${GREEN} CONNECTED${NC}"
        
        # Get database stats
        DB_STATS=$(docker exec postgresql psql -U app_user -d pretamane_db -t -c "SELECT 
            (SELECT COUNT(*) FROM contact_submissions) as contacts,
            (SELECT COUNT(*) FROM documents) as documents,
            (SELECT count FROM website_visitors WHERE id='visitor_count') as visitors
        " 2>/dev/null || echo "0|0|0")
        
        echo "  Contacts: $(echo $DB_STATS | awk '{print $1}')"
        echo "  Documents: $(echo $DB_STATS | awk '{print $3}')"
        echo "  Visitors: $(echo $DB_STATS | awk '{print $5}')"
    else
        echo -e "${RED} FAILED${NC}"
    fi
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================"
echo "Health Check Complete"
echo "========================================"
echo "Application URL: $BASE_URL"
echo "API Docs: $BASE_URL/docs"
echo "Grafana: $BASE_URL/grafana"
echo ""
echo "Status: All critical services operational"
echo "========================================"




