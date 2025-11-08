#!/bin/bash
# DEPRECATED: This script has been superseded by a user-level utility.
# Use: ~/.local/bin/get-tunnel-url
# Other related helpers:
# - Start/stop sing-box: ~/.local/bin/sing-on, ~/.local/bin/sing-off
# - Outline (Flatpak): flatpak run org.getoutline.OutlineClient
# - Nekoray (ZIP): ~/Applications/nekoray-4.0.1/run-nekoray.sh
echo "get-tunnel-info.sh is deprecated. Use ~/.local/bin/get-tunnel-url instead."
exit 0
################################################################################
# Cloudflare Tunnel Information Fetcher
#
# This script fetches your current Cloudflare Tunnel URL from the running
# cloudflared container and optionally updates monitoring configurations.
#
# Usage:
#   ./scripts/get-tunnel-info.sh [options]
#
# Options:
#   --remote    Fetch from remote EC2 instance via SSH
#   --update    Update Prometheus configs with tunnel URL
#   --json      Output in JSON format
#   --help      Show this help message
#
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
REMOTE_MODE=false
UPDATE_CONFIGS=false
JSON_OUTPUT=false
EC2_HOST="ubuntu@54.179.230.219"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Cloudflare Tunnel Information${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

show_help() {
    cat << EOF
Cloudflare Tunnel Information Fetcher

Usage: $0 [options]

Options:
    --remote        Fetch tunnel URL from remote EC2 instance
    --update        Update Prometheus blackbox configs with tunnel URL
    --json          Output results in JSON format
    --host HOST     Custom SSH host (default: ubuntu@54.179.230.219)
    --help          Show this help message

Examples:
    # Get tunnel URL from local Docker
    $0

    # Get tunnel URL from remote EC2
    $0 --remote

    # Fetch and update configs
    $0 --remote --update

    # Get JSON output
    $0 --remote --json

EOF
}

################################################################################
# Main Functions
################################################################################

fetch_tunnel_url_local() {
    print_info "Fetching tunnel URL from local Docker container..."

    if ! docker ps | grep -q cloudflared; then
        print_error "cloudflared container is not running"
        echo ""
        print_info "Start it with: cd docker-compose && docker-compose up -d cloudflared"
        return 1
    fi

    # Get tunnel URL from logs
    TUNNEL_URL=$(docker logs cloudflared 2>&1 | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1)

    if [ -z "$TUNNEL_URL" ]; then
        print_error "Could not find tunnel URL in cloudflared logs"
        echo ""
        print_info "The tunnel might still be initializing. Wait 10 seconds and try again."
        return 1
    fi

    echo "$TUNNEL_URL"
}

fetch_tunnel_url_remote() {
    print_info "Fetching tunnel URL from remote EC2 instance..."

    if ! command -v ssh &> /dev/null; then
        print_error "SSH command not found"
        return 1
    fi

    # Test SSH connection
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$EC2_HOST" "exit" 2>/dev/null; then
        print_error "Cannot connect to EC2 instance: $EC2_HOST"
        echo ""
        print_info "Make sure your SSH key is loaded: ssh-add ~/.ssh/your-key.pem"
        return 1
    fi

    print_success "Connected to EC2 instance"

    # Get tunnel URL from remote
    TUNNEL_URL=$(ssh "$EC2_HOST" "docker logs cloudflared 2>&1 | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1")

    if [ -z "$TUNNEL_URL" ]; then
        print_error "Could not find tunnel URL on remote instance"
        echo ""
        print_info "Check if cloudflared is running: ssh $EC2_HOST 'docker ps | grep cloudflared'"
        return 1
    fi

    echo "$TUNNEL_URL"
}

get_tunnel_status() {
    local tunnel_url=$1

    print_info "Testing tunnel connectivity..."

    # Test if tunnel is accessible
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$tunnel_url" | grep -q "200\|301\|302"; then
        print_success "Tunnel is accessible and responding"
        return 0
    else
        print_warning "Tunnel URL found but not responding (might still be initializing)"
        return 1
    fi
}

update_prometheus_config() {
    local tunnel_url=$1
    local config_file="$PROJECT_ROOT/docker-compose/config/prometheus/prometheus.yml"

    print_info "Updating Prometheus configuration..."

    if [ ! -f "$config_file" ]; then
        print_error "Prometheus config not found: $config_file"
        return 1
    fi

    # Create backup
    cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
    print_success "Created backup of prometheus.yml"

    # Check if tunnel URL already exists in config
    if grep -q "$tunnel_url" "$config_file"; then
        print_info "Tunnel URL already in config, skipping update"
        return 0
    fi

    # Update the config with tunnel URL (add to blackbox-http-public targets)
    # This is a simple approach - adds the URLs as comments to be manually uncommented
    local temp_file=$(mktemp)
    awk -v url="$tunnel_url" '
        /# Add your Cloudflare Tunnel URL here:/ {
            print
            print "          # - \"" url "\""
            print "          # - \"" url "/api/health\""
            print "          # - \"" url "/grafana\""
            next
        }
        { print }
    ' "$config_file" > "$temp_file"

    mv "$temp_file" "$config_file"

    print_success "Updated Prometheus config with tunnel URL"
    echo ""
    print_warning "The URLs have been added as comments. Edit prometheus.yml to uncomment them."
    print_info "File location: $config_file"
}

output_json() {
    local tunnel_url=$1
    local status=$2

    cat << EOF
{
  "tunnel_url": "$tunnel_url",
  "status": "$status",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "endpoints": {
    "main": "$tunnel_url",
    "api": "$tunnel_url/api/health",
    "grafana": "$tunnel_url/grafana",
    "prometheus": "$tunnel_url/prometheus",
    "pgadmin": "$tunnel_url/pgadmin",
    "minio": "$tunnel_url/minio-console"
  },
  "auth_required": [
    "$tunnel_url/grafana",
    "$tunnel_url/prometheus",
    "$tunnel_url/pgadmin"
  ],
  "credentials": {
    "username": "pretamane",
    "password": "*** (check .env file)"
  }
}
EOF
}

output_human() {
    local tunnel_url=$1

    echo ""
    print_success "Cloudflare Tunnel URL Found!"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Tunnel URL: ${NC}$tunnel_url"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${BLUE}📍 Available Endpoints:${NC}"
    echo ""
    echo "  🌐 Main Site:         $tunnel_url"
    echo "  📊 API Docs:          $tunnel_url/api/docs"
    echo "  💚 Health Check:      $tunnel_url/api/health"
    echo ""

    echo -e "${YELLOW}🔒 Protected Endpoints (Basic Auth Required):${NC}"
    echo "  Username: pretamane"
    echo "  Password: (check your .env file)"
    echo ""
    echo "  📈 Grafana:           $tunnel_url/grafana"
    echo "  📊 Prometheus:        $tunnel_url/prometheus"
    echo "  🗄️  pgAdmin:           $tunnel_url/pgadmin"
    echo "  💾 MinIO Console:     (access via port 9001)"
    echo ""

    echo -e "${BLUE}🧪 Quick Tests:${NC}"
    echo ""
    echo "  # Test main site"
    echo "  curl $tunnel_url"
    echo ""
    echo "  # Test API health"
    echo "  curl $tunnel_url/api/health"
    echo ""
    echo "  # Test Grafana (with auth)"
    echo "  curl -u pretamane:'YOUR_PASSWORD' $tunnel_url/grafana"
    echo ""

    echo -e "${BLUE}📝 Notes:${NC}"
    echo "  • This URL changes when cloudflared restarts"
    echo "  • For a permanent URL, set up a custom domain"
    echo "  • Direct IP access (54.179.230.219) should be blocked"
    echo "  • All traffic is encrypted via Cloudflare"
    echo ""

    print_warning "IMPORTANT: Save this URL for future access!"
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remote)
                REMOTE_MODE=true
                shift
                ;;
            --update)
                UPDATE_CONFIGS=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --host)
                EC2_HOST="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
    done

    # Print header (only in human-readable mode)
    if [ "$JSON_OUTPUT" = false ]; then
        print_header
        echo ""
    fi

    # Fetch tunnel URL
    if [ "$REMOTE_MODE" = true ]; then
        TUNNEL_URL=$(fetch_tunnel_url_remote)
    else
        TUNNEL_URL=$(fetch_tunnel_url_local)
    fi

    # Check if we got a URL
    if [ -z "$TUNNEL_URL" ]; then
        exit 1
    fi

    # Test tunnel status
    if get_tunnel_status "$TUNNEL_URL"; then
        STATUS="online"
    else
        STATUS="offline"
    fi

    # Update configs if requested
    if [ "$UPDATE_CONFIGS" = true ] && [ "$JSON_OUTPUT" = false ]; then
        echo ""
        update_prometheus_config "$TUNNEL_URL"
    fi

    # Output results
    if [ "$JSON_OUTPUT" = true ]; then
        output_json "$TUNNEL_URL" "$STATUS"
    else
        output_human "$TUNNEL_URL"
    fi
}

# Run main function
main "$@"
