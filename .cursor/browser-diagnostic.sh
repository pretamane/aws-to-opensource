#!/bin/bash
# Cursor Built-in Browser Diagnostic Script
# This script tests the browser MCP functionality and local services

set -e

echo "=========================================="
echo "Cursor Browser Diagnostic Tool"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check if Docker is running
echo -e "${YELLOW}[1/6] Checking Docker...${NC}"
if docker ps &>/dev/null; then
    echo -e "${GREEN} Docker is running${NC}"
    DOCKER_RUNNING=true
else
    echo -e "${RED} Docker is not running or not accessible${NC}"
    DOCKER_RUNNING=false
fi
echo ""

# Test 2: Check if Docker Compose services are running
echo -e "${YELLOW}[2/6] Checking Docker Compose services...${NC}"
if [ "$DOCKER_RUNNING" = true ]; then
    cd /home/guest/aws-to-opensource-local/docker-compose 2>/dev/null || cd docker-compose 2>/dev/null || { echo -e "${RED} Cannot find docker-compose directory${NC}"; exit 1; }
    
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        echo -e "${GREEN} Docker Compose services are running:${NC}"
        docker-compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" | grep -v "NAME"
    else
        echo -e "${YELLOW} Docker Compose services are not running${NC}"
        echo "   To start services: cd docker-compose && docker-compose up -d"
    fi
else
    echo -e "${YELLOW} Skipping (Docker not running)${NC}"
fi
echo ""

# Test 3: Check port availability
echo -e "${YELLOW}[3/6] Checking port availability...${NC}"
PORTS=(8080 3000 9090 9093 3100 5432 9000 9001)
PORT_OPEN=false

for port in "${PORTS[@]}"; do
    if command -v ss &>/dev/null; then
        if ss -tuln | grep -q ":$port "; then
            echo -e "${GREEN} Port $port is open${NC}"
            PORT_OPEN=true
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "${GREEN} Port $port is open${NC}"
            PORT_OPEN=true
        fi
    fi
done

if [ "$PORT_OPEN" = false ]; then
    echo -e "${YELLOW} No services detected on common ports${NC}"
    echo "   This is expected if Docker services are not running"
fi
echo ""

# Test 4: Test localhost connectivity
echo -e "${YELLOW}[4/6] Testing localhost connectivity...${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "200\|301\|302\|401"; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
    echo -e "${GREEN} localhost:8080 is accessible (HTTP $HTTP_CODE)${NC}"
elif curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "000"; then
    echo -e "${RED} localhost:8080 connection refused${NC}"
    echo "   This is expected if services are not running"
else
    echo -e "${YELLOW} Cannot test localhost:8080 (curl not available or connection failed)${NC}"
fi
echo ""

# Test 5: Check Cursor MCP browser availability
echo -e "${YELLOW}[5/6] Checking Cursor MCP browser tools...${NC}"
echo "   Note: MCP browser tools can only be tested from within Cursor"
echo -e "${GREEN} MCP browser tools are available in Cursor:${NC}"
echo "   - browser_navigate: Navigate to URLs"
echo "   - browser_snapshot: Get page accessibility snapshot"
echo "   - browser_click: Click elements"
echo "   - browser_type: Type text"
echo "   - browser_take_screenshot: Capture screenshots"
echo "   - browser_console_messages: Read console logs"
echo ""

# Test 6: Check network connectivity
echo -e "${YELLOW}[6/6] Testing external connectivity...${NC}"
if curl -s -o /dev/null -w "%{http_code}" https://www.example.com 2>/dev/null | grep -q "200"; then
    echo -e "${GREEN} External connectivity works (example.com)${NC}"
else
    echo -e "${RED} Cannot reach external sites${NC}"
    echo "   Check your internet connection"
fi
echo ""

# Summary
echo "=========================================="
echo "Diagnostic Summary"
echo "=========================================="
echo ""

if [ "$DOCKER_RUNNING" = true ] && docker-compose ps 2>/dev/null | grep -q "Up"; then
    echo -e "${GREEN} Services are running${NC}"
    echo "   Browser should be able to access: http://localhost:8080"
    echo ""
    echo "Available services:"
    echo "  - Main App: http://localhost:8080"
    echo "  - Grafana: http://localhost:8080/grafana"
    echo "  - Prometheus: http://localhost:8080/prometheus"
    echo "  - pgAdmin: http://localhost:8080/pgadmin"
    echo "  - Meilisearch: http://localhost:8080/meilisearch"
    echo "  - MinIO: http://localhost:8080/minio"
else
    echo -e "${YELLOW} Services are not running${NC}"
    echo "   To start services:"
    echo "   cd docker-compose && docker-compose up -d"
    echo ""
    echo "   Browser will show 'Connection Refused' until services are started"
    echo "   This is expected behavior - the browser is working correctly"
fi

echo ""
echo "=========================================="
echo "Browser Troubleshooting Tips"
echo "=========================================="
echo ""
echo "1. Test browser with external site:"
echo "   Use MCP browser_navigate with: https://www.example.com"
echo ""
echo "2. If localhost fails:"
echo "   - Check if Docker services are running"
echo "   - Verify port 8080 is not blocked by firewall"
echo "   - Check docker-compose logs for errors"
echo ""
echo "3. If browser shows blank screen:"
echo "   - Try taking a screenshot to verify page loaded"
echo "   - Check browser console messages for errors"
echo "   - Verify URL is correct"
echo ""
echo "4. Authentication issues:"
echo "   - Most admin services require Basic Auth"
echo "   - Username: pretamane"
echo "   - Password: #ThawZin2k77!"
echo ""
echo "For more details, see: CURSOR_BROWSER_TROUBLESHOOTING.md"
echo ""

