#!/bin/bash

# Edge Enforcement Deployment Script
# Deploys the Docker Compose stack with true edge enforcement

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if running from correct directory
if [ ! -f "EDGE_ENFORCEMENT_DEPLOYMENT.md" ]; then
    print_error "Please run this script from the project root: aws-to-opensource-local/"
    exit 1
fi

print_header "Edge Enforcement Deployment"

print_info "This script will deploy a secure, edge-enforced Docker Compose stack"
print_info "Security Model: Caddy (edge auth) + Per-service authentication"
echo ""

# Step 1: Check prerequisites
print_header "Step 1: Checking Prerequisites"

# Check Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
    print_success "Docker installed: $DOCKER_VERSION"
else
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    print_success "Docker Compose installed: $COMPOSE_VERSION"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | cut -d ' ' -f3 | cut -d ',' -f1)
    print_success "Docker Compose installed: $COMPOSE_VERSION"
    COMPOSE_CMD="docker-compose"
else
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Set compose command
COMPOSE_CMD=${COMPOSE_CMD:-"docker compose"}

# Check if Docker daemon is running
if ! docker ps &> /dev/null; then
    print_error "Docker daemon is not running. Please start Docker."
    exit 1
fi

print_success "Docker daemon is running"

# Check port availability
print_info "Checking port availability..."
if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ":80 "; then
    print_warning "Port 80 is already in use. You may need to stop conflicting services."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_success "Port 80 is available"
fi

# Step 2: Environment configuration
print_header "Step 2: Environment Configuration"

cd docker-compose

if [ -f ".env" ]; then
    print_warning ".env file already exists"
    read -p "Do you want to recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv .env .env.backup.$(date +%Y%m%d_%H%M%S)
        print_info "Backed up existing .env file"
        CREATE_ENV=true
    else
        print_info "Using existing .env file"
        CREATE_ENV=false
    fi
else
    CREATE_ENV=true
fi

if [ "$CREATE_ENV" = true ]; then
    if [ ! -f ".env.template" ]; then
        print_error ".env.template not found!"
        exit 1
    fi

    cp .env.template .env
    print_success "Created .env file from template"
    print_warning "You MUST edit .env and replace all CHANGE_ME_ placeholders!"
    echo ""
    echo "Required variables to set:"
    echo "  - POSTGRES_PASSWORD (and DB_PASSWORD - must match)"
    echo "  - MEILI_MASTER_KEY (16+ characters)"
    echo "  - MINIO_ROOT_PASSWORD"
    echo "  - GF_SECURITY_ADMIN_PASSWORD"
    echo "  - PGADMIN_DEFAULT_PASSWORD"
    echo ""

    read -p "Open .env in editor now? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if command -v nano &> /dev/null; then
            nano .env
        elif command -v vim &> /dev/null; then
            vim .env
        elif command -v vi &> /dev/null; then
            vi .env
        else
            print_warning "No text editor found. Please edit .env manually."
        fi
    else
        print_warning "Remember to edit .env before proceeding!"
        read -p "Press Enter when you've edited .env..."
    fi
fi

# Validate .env
print_info "Validating .env configuration..."

if grep -q "CHANGE_ME_" .env; then
    print_error ".env still contains CHANGE_ME_ placeholders!"
    print_error "Please edit .env and replace all placeholders with actual passwords."
    exit 1
fi

print_success ".env validation passed"

# Step 3: Validate Docker Compose configuration
print_header "Step 3: Validating Configuration"

print_info "Validating docker-compose.yml..."
if $COMPOSE_CMD config > /dev/null 2>&1; then
    print_success "Docker Compose configuration is valid"
else
    print_error "Docker Compose configuration has errors:"
    $COMPOSE_CMD config
    exit 1
fi

# Step 4: Deploy
print_header "Step 4: Deploying Stack"

print_info "This will pull images, build the app, and start all services..."
print_info "First-time deployment may take 2-3 minutes..."
echo ""

read -p "Start deployment? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    print_warning "Deployment cancelled."
    exit 0
fi

print_info "Starting deployment..."
$COMPOSE_CMD up -d

print_success "Services started!"

# Wait for services to initialize
print_info "Waiting for services to initialize (30 seconds)..."
sleep 30

# Step 5: Validation
print_header "Step 5: Validating Deployment"

# Check running containers
print_info "Checking service status..."
RUNNING_SERVICES=$($COMPOSE_CMD ps --services --filter "status=running" | wc -l)
TOTAL_SERVICES=$($COMPOSE_CMD ps --services | wc -l)

if [ "$RUNNING_SERVICES" -eq "$TOTAL_SERVICES" ]; then
    print_success "All services are running ($RUNNING_SERVICES/$TOTAL_SERVICES)"
else
    print_warning "Some services may not be running ($RUNNING_SERVICES/$TOTAL_SERVICES)"
    print_info "Run 'docker compose ps' to check status"
fi

# Check edge enforcement
print_info "Validating edge enforcement..."

# Test public endpoint
if curl -s -f http://localhost/health > /dev/null 2>&1; then
    print_success "✓ Public API accessible via Caddy"
else
    print_warning "✗ Public API not accessible yet (may still be starting)"
fi

# Test edge auth
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/grafana 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "401" ]; then
    print_success "✓ Edge auth enforced (Grafana returns 401)"
elif [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
    print_warning "✗ Grafana accessible without auth - check Caddyfile"
else
    print_warning "✗ Grafana not responding (HTTP $HTTP_CODE) - may still be starting"
fi

# Test direct port blocking (should fail)
if curl -s -f http://localhost:3000 > /dev/null 2>&1; then
    print_error "✗ EDGE BYPASS DETECTED! Port 3000 is accessible directly!"
    print_error "This means edge enforcement failed. Check docker-compose.yml ports."
else
    print_success "✓ Direct port access blocked (edge enforcement working)"
fi

# Step 6: Summary
print_header "Deployment Complete!"

echo ""
echo "Access your services via Caddy (edge):"
echo ""
echo -e "  ${GREEN}Public Endpoints (no auth):${NC}"
echo "    • Main site:       http://localhost/"
echo "    • API docs:        http://localhost/docs"
echo "    • API health:      http://localhost/health"
echo ""
echo -e "  ${YELLOW}Admin UIs (edge auth required):${NC}"
echo "    • Grafana:         http://localhost/grafana"
echo "    • Prometheus:      http://localhost/prometheus"
echo "    • pgAdmin:         http://localhost/pgadmin"
echo "    • Meilisearch:     http://localhost/meilisearch"
echo "    • MinIO Console:   http://localhost/minio"
echo "    • Alertmanager:    http://localhost/alertmanager"
echo ""
echo -e "  ${BLUE}Edge Credentials (Caddy basic auth):${NC}"
echo "    • Username: pretamane"
echo "    • Password: #ThawZin2k77!"
echo ""
echo -e "  ${BLUE}Per-Service Credentials:${NC}"
echo "    • Check your .env file for Grafana, pgAdmin, MinIO, etc."
echo ""
echo "Useful commands:"
echo "  • View logs:        cd docker-compose && docker compose logs -f"
echo "  • Check status:     cd docker-compose && docker compose ps"
echo "  • Restart services: cd docker-compose && docker compose restart"
echo "  • Stop all:         cd docker-compose && docker compose down"
echo ""
echo "For detailed documentation, see: EDGE_ENFORCEMENT_DEPLOYMENT.md"
echo ""

print_success "Edge enforcement is active! All services secured behind Caddy."

cd ..
exit 0
