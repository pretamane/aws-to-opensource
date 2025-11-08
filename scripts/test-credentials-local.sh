#!/bin/bash
# Script to test new credentials locally

set -e

cd /home/guest/aws-to-opensource/docker-compose

echo "Testing new credentials locally..."
echo ""
echo "WARNING: This will recreate all services and delete existing data!"
echo "Only use this for local testing."
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1: Stopping existing services..."
docker-compose down -v

echo ""
echo "Step 2: Starting services with new credentials..."
docker-compose up -d

echo ""
echo "Step 3: Waiting for services to start (30 seconds)..."
sleep 30

echo ""
echo "Step 4: Checking service status..."
docker-compose ps

echo ""
echo "Step 5: Testing connections..."

echo -n "  PostgreSQL... "
if docker-compose exec -T postgresql psql -U pretamane -d pretamane_db -c "SELECT 1;" > /dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED"
fi

echo -n "  MinIO... "
if curl -s http://localhost:9001 > /dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED"
fi

echo -n "  Grafana... "
if curl -s -u pretamane:'#ThawZin2k77!' http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED"
fi

echo -n "  Meilisearch... "
if curl -s -H "Authorization: Bearer pretamane_2k77_master_key_secure" http://localhost:7700/health > /dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED"
fi

echo -n "  FastAPI... "
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED"
fi

echo ""
echo "Testing complete!"
echo ""
echo "Access URLs (local):"
echo "  API:       http://localhost:8000"
echo "  API Docs:  http://localhost:8000/docs"
echo "  Grafana:   http://localhost:3000 (pretamane / #ThawZin2k77!)"
echo "  pgAdmin:   http://localhost:5050 (pretamane@localhost.com / #ThawZin2k77!)"
echo "  MinIO:     http://localhost:9001 (pretamane / #ThawZin2k77!)"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
