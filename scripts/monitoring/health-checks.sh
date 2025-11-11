#!/bin/bash
# scripts/monitoring/health-checks.sh
# Enhanced health monitoring script
# Extracted from: ansible/playbooks/05-monitoring.yml

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source configuration
source "$PROJECT_ROOT/config/environments/production.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]  $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]   $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]  $1${NC}"
}

log_info() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

log_highlight() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Global variables
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-30}"
HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-3}"
VERBOSE="${ENABLE_VERBOSE_OUTPUT:-false}"

# Check cluster connectivity
check_cluster_connectivity() {
    log " Checking cluster connectivity..."
    
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_info "Run: aws eks update-kubeconfig --region $AWS_REGION --name $PROJECT_NAME-cluster"
        return 1
    fi
    
    local cluster_info=$(kubectl cluster-info 2>/dev/null | head -1)
    log_success "Cluster connectivity: OK"
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "$cluster_info"
    fi
    
    return 0
}

# Check node health
check_node_health() {
    log "Checking node health..."
    
    local nodes_output=$(kubectl get nodes --no-headers 2>/dev/null)
    local total_nodes=$(echo "$nodes_output" | wc -l)
    local ready_nodes=$(echo "$nodes_output" | grep -c "Ready" || echo "0")
    local not_ready_nodes=$((total_nodes - ready_nodes))
    
    log_info "Total nodes: $total_nodes"
    log_info "Ready nodes: $ready_nodes"
    
    if [[ $not_ready_nodes -gt 0 ]]; then
        log_warning "Not ready nodes: $not_ready_nodes"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$nodes_output" | grep -v "Ready" || true
        fi
    fi
    
    if [[ $ready_nodes -gt 0 ]]; then
        log_success "Node health: OK ($ready_nodes/$total_nodes ready)"
        return 0
    else
        log_error "Node health: FAILED (no ready nodes)"
        return 1
    fi
}

# Check pod health
check_pod_health() {
    log "Checking pod health..."
    
    local pods_output=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null)
    local total_pods=$(echo "$pods_output" | wc -l)
    local running_pods=$(echo "$pods_output" | grep -c "Running" || echo "0")
    local pending_pods=$(echo "$pods_output" | grep -c "Pending" || echo "0")
    local failed_pods=$(echo "$pods_output" | grep -c -E "(Failed|Error|CrashLoopBackOff)" || echo "0")
    
    log_info "Total pods: $total_pods"
    log_info "Running pods: $running_pods"
    
    if [[ $pending_pods -gt 0 ]]; then
        log_warning "Pending pods: $pending_pods"
    fi
    
    if [[ $failed_pods -gt 0 ]]; then
        log_error "Failed pods: $failed_pods"
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Failed pods details:"
            echo "$pods_output" | grep -E "(Failed|Error|CrashLoopBackOff)" || true
        fi
        return 1
    fi
    
    log_success "Pod health: OK ($running_pods running, $pending_pods pending)"
    return 0
}

# Check service health
check_service_health() {
    log " Checking service health..."
    
    local services_output=$(kubectl get services --all-namespaces --no-headers 2>/dev/null)
    local total_services=$(echo "$services_output" | wc -l)
    local external_services=$(echo "$services_output" | grep -c "LoadBalancer\|NodePort" || echo "0")
    
    log_info "Total services: $total_services"
    log_info "External services: $external_services"
    
    # Check for services with external IPs
    if [[ $external_services -gt 0 ]]; then
        local pending_external=$(echo "$services_output" | grep -E "LoadBalancer.*<pending>" | wc -l || echo "0")
        if [[ $pending_external -gt 0 ]]; then
            log_warning "Services with pending external IPs: $pending_external"
        fi
    fi
    
    log_success "Service health: OK ($total_services total)"
    return 0
}

# Check ingress health
check_ingress_health() {
    log " Checking ingress health..."
    
    local ingresses=$(kubectl get ingress --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [[ $ingresses -eq 0 ]]; then
        log_warning "No ingresses found"
        return 0
    fi
    
    log_info "Total ingresses: $ingresses"
    
    # Check for ingresses with addresses
    local ingress_details=$(kubectl get ingress --all-namespaces -o wide --no-headers 2>/dev/null)
    local ready_ingresses=$(echo "$ingress_details" | grep -v "<none>" | wc -l || echo "0")
    
    if [[ $ready_ingresses -gt 0 ]]; then
        log_success "Ingress health: OK ($ready_ingresses/$ingresses ready)"
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Ingress endpoints:"
            echo "$ingress_details" | grep -v "<none>" | while read -r line; do
                local namespace=$(echo "$line" | awk '{print $1}')
                local name=$(echo "$line" | awk '{print $2}')
                local address=$(echo "$line" | awk '{print $4}')
                log_info "  $namespace/$name: $address"
            done
        fi
    else
        log_warning "Ingress health: No ready ingresses"
    fi
    
    return 0
}

# Check application endpoints
check_application_endpoints() {
    log " Checking application endpoints..."
    
    # Get application URLs from ingresses
    local app_urls=$(kubectl get ingress --all-namespaces -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[0].hostname}{"\n"}{end}' 2>/dev/null | grep -v "^$" || echo "")
    
    if [[ -z "$app_urls" ]]; then
        log_warning "No application URLs found"
        return 0
    fi
    
    local healthy_endpoints=0
    local total_endpoints=0
    
    while IFS= read -r url; do
        if [[ -n "$url" ]]; then
            ((total_endpoints++))
            
            log_info "Testing endpoint: http://$url"
            
            # Test health endpoint
            if curl -s --max-time "$HEALTH_CHECK_TIMEOUT" "http://$url/health" &>/dev/null; then
                log_success "  Health check: OK"
                ((healthy_endpoints++))
            else
                log_warning "  Health check: FAILED"
            fi
            
            # Test main endpoint
            if curl -s --max-time "$HEALTH_CHECK_TIMEOUT" "http://$url" &>/dev/null; then
                log_success "  Main endpoint: OK"
            else
                log_warning "  Main endpoint: FAILED"
            fi
        fi
    done <<< "$app_urls"
    
    if [[ $total_endpoints -gt 0 ]]; then
        log_success "Application endpoints: $healthy_endpoints/$total_endpoints healthy"
    fi
    
    return 0
}

# Check resource usage
check_resource_usage() {
    log " Checking resource usage..."
    
    # Check if metrics-server is available
    if ! kubectl top nodes &>/dev/null; then
        log_warning "Metrics server not available, skipping resource usage check"
        return 0
    fi
    
    # Node resource usage
    log_info "Node resource usage:"
    local node_metrics=$(kubectl top nodes --no-headers 2>/dev/null)
    if [[ -n "$node_metrics" ]]; then
        echo "$node_metrics" | while read -r line; do
            local node=$(echo "$line" | awk '{print $1}')
            local cpu=$(echo "$line" | awk '{print $2}')
            local memory=$(echo "$line" | awk '{print $4}')
            log_info "  $node: CPU $cpu, Memory $memory"
        done
    fi
    
    # Pod resource usage (top 5)
    log_info "Top pod resource usage:"
    local pod_metrics=$(kubectl top pods --all-namespaces --no-headers 2>/dev/null | sort -k3 -nr | head -5)
    if [[ -n "$pod_metrics" ]]; then
        echo "$pod_metrics" | while read -r line; do
            local namespace=$(echo "$line" | awk '{print $1}')
            local pod=$(echo "$line" | awk '{print $2}')
            local cpu=$(echo "$line" | awk '{print $3}')
            local memory=$(echo "$line" | awk '{print $4}')
            log_info "  $namespace/$pod: CPU $cpu, Memory $memory"
        done
    fi
    
    log_success "Resource usage check completed"
    return 0
}

# Check storage health
check_storage_health() {
    log " Checking storage health..."
    
    # Check persistent volumes
    local pvs=$(kubectl get pv --no-headers 2>/dev/null | wc -l || echo "0")
    local bound_pvs=$(kubectl get pv --no-headers 2>/dev/null | grep -c "Bound" || echo "0")
    
    log_info "Persistent volumes: $bound_pvs/$pvs bound"
    
    # Check persistent volume claims
    local pvcs=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    local bound_pvcs=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | grep -c "Bound" || echo "0")
    
    log_info "Persistent volume claims: $bound_pvcs/$pvcs bound"
    
    # Check storage classes
    local storage_classes=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l || echo "0")
    log_info "Storage classes: $storage_classes"
    
    if [[ "$VERBOSE" == "true" && $storage_classes -gt 0 ]]; then
        log_info "Available storage classes:"
        kubectl get storageclass --no-headers 2>/dev/null | while read -r line; do
            local name=$(echo "$line" | awk '{print $1}')
            local provisioner=$(echo "$line" | awk '{print $2}')
            log_info "  $name ($provisioner)"
        done
    fi
    
    log_success "Storage health: OK"
    return 0
}

# Check Helm releases
check_helm_releases() {
    log "️  Checking Helm releases..."
    
    if ! command -v helm &>/dev/null; then
        log_warning "Helm not installed, skipping Helm release check"
        return 0
    fi
    
    local releases=$(helm list --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [[ $releases -eq 0 ]]; then
        log_warning "No Helm releases found"
        return 0
    fi
    
    log_info "Total Helm releases: $releases"
    
    local deployed_releases=$(helm list --all-namespaces --no-headers 2>/dev/null | grep -c "deployed" || echo "0")
    local failed_releases=$(helm list --all-namespaces --no-headers 2>/dev/null | grep -c "failed" || echo "0")
    
    log_info "Deployed releases: $deployed_releases"
    
    if [[ $failed_releases -gt 0 ]]; then
        log_error "Failed releases: $failed_releases"
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Failed releases:"
            helm list --all-namespaces --no-headers 2>/dev/null | grep "failed" | while read -r line; do
                local name=$(echo "$line" | awk '{print $1}')
                local namespace=$(echo "$line" | awk '{print $2}')
                log_error "  $namespace/$name"
            done
        fi
        return 1
    fi
    
    log_success "Helm releases: OK ($deployed_releases deployed)"
    return 0
}

# Check AWS resources
check_aws_resources() {
    log "️  Checking AWS resources..."
    
    # Check EKS cluster
    local cluster_status=$(aws eks describe-cluster --name "$PROJECT_NAME-cluster" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "$cluster_status" == "ACTIVE" ]]; then
        log_success "EKS cluster: ACTIVE"
    elif [[ "$cluster_status" == "NOT_FOUND" ]]; then
        log_warning "EKS cluster: NOT FOUND"
    else
        log_warning "EKS cluster: $cluster_status"
    fi
    
    # Check node groups
    local node_groups=$(aws eks list-nodegroups --cluster-name "$PROJECT_NAME-cluster" --query 'nodegroups' --output text 2>/dev/null | wc -w || echo "0")
    log_info "EKS node groups: $node_groups"
    
    # Check load balancers
    local load_balancers=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-`) || contains(Tags[?Key==`kubernetes.io/cluster/'"$PROJECT_NAME"'-cluster`].Value, `owned`)].LoadBalancerName' --output text 2>/dev/null | wc -w || echo "0")
    log_info "Application load balancers: $load_balancers"
    
    return 0
}

# Generate health report
generate_health_report() {
    local report_file="health-report-$(date +%Y%m%d-%H%M%S).json"
    
    log " Generating health report: $report_file"
    
    # Collect basic metrics
    local cluster_info=$(kubectl cluster-info 2>/dev/null | head -1 || echo "Not available")
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    local pods=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    local running_pods=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    local services=$(kubectl get services --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    local ingresses=$(kubectl get ingress --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    local helm_releases=$(helm list --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    
    # Create JSON report
    cat > "$report_file" << EOF
{
  "timestamp": "$(date --iso-8601=seconds)",
  "project": "$PROJECT_NAME",
  "environment": "$ENVIRONMENT",
  "cluster": {
    "info": "$cluster_info",
    "nodes": {
      "total": $nodes,
      "ready": $ready_nodes
    },
    "pods": {
      "total": $pods,
      "running": $running_pods
    },
    "services": $services,
    "ingresses": $ingresses
  },
  "helm": {
    "releases": $helm_releases
  },
  "health_status": "$(if [[ $ready_nodes -gt 0 && $running_pods -gt 0 ]]; then echo "healthy"; else echo "unhealthy"; fi)"
}
EOF
    
    log_success "Health report generated: $report_file"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Report contents:"
        cat "$report_file" | jq . 2>/dev/null || cat "$report_file"
    fi
}

# Main health check function
run_all_health_checks() {
    log_highlight " Running Comprehensive Health Checks"
    echo ""
    
    local failed_checks=0
    local total_checks=0
    
    # Run all health checks
    local checks=(
        "check_cluster_connectivity"
        "check_node_health"
        "check_pod_health"
        "check_service_health"
        "check_ingress_health"
        "check_application_endpoints"
        "check_resource_usage"
        "check_storage_health"
        "check_helm_releases"
        "check_aws_resources"
    )
    
    for check in "${checks[@]}"; do
        ((total_checks++))
        echo ""
        if ! $check; then
            ((failed_checks++))
        fi
    done
    
    echo ""
    
    # Generate report
    generate_health_report
    
    echo ""
    
    # Summary
    if [[ $failed_checks -eq 0 ]]; then
        log_success "All health checks passed! ($total_checks/$total_checks)"
        return 0
    else
        log_error " $failed_checks/$total_checks health checks failed"
        return 1
    fi
}

# Usage information
show_usage() {
    cat << EOF
 Enhanced Health Monitoring Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --verbose          Enable verbose output
    --timeout SECONDS  Set health check timeout (default: $HEALTH_CHECK_TIMEOUT)
    --retries COUNT    Set retry count (default: $HEALTH_CHECK_RETRIES)
    --help             Show this help message

EXAMPLES:
    $0                 # Run all health checks
    $0 --verbose       # Run with verbose output
    $0 --timeout 60    # Use 60 second timeout

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE="true"
                log_info "Verbose mode enabled"
                shift
                ;;
            --timeout)
                if [[ -n "${2:-}" ]]; then
                    HEALTH_CHECK_TIMEOUT="$2"
                    log_info "Health check timeout set to: $HEALTH_CHECK_TIMEOUT seconds"
                    shift 2
                else
                    log_error "--timeout requires a value"
                    exit 1
                fi
                ;;
            --retries)
                if [[ -n "${2:-}" ]]; then
                    HEALTH_CHECK_RETRIES="$2"
                    log_info "Health check retries set to: $HEALTH_CHECK_RETRIES"
                    shift 2
                else
                    log_error "--retries requires a value"
                    exit 1
                fi
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    parse_arguments "$@"
    run_all_health_checks
}

# Run main function with all arguments
main "$@"
