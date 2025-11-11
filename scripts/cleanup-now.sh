#!/bin/bash
# cleanup-now.sh - Manual cleanup script for immediate teardown

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]  $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]   $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]  $1${NC}"
}

# Function to kill scheduled cleanup
kill_scheduled_cleanup() {
    if [ -f cleanup.pid ]; then
        CLEANUP_PID=$(cat cleanup.pid)
        if kill -0 $CLEANUP_PID 2>/dev/null; then
            log "Killing scheduled cleanup process (PID: $CLEANUP_PID)..."
            kill $CLEANUP_PID
            log_success "Scheduled cleanup cancelled"
        fi
        rm -f cleanup.pid
    fi
}

# Function to cleanup Kubernetes resources
cleanup_kubernetes() {
    log "Cleaning up Kubernetes resources..."
    
    # Delete application resources
    kubectl delete -f k8s/ --ignore-not-found=true || true
    
    # Wait for resources to be deleted
    log "Waiting for resources to be deleted..."
    sleep 10
    
    log_success "Kubernetes resources cleaned up"
}

# Function to cleanup Terraform infrastructure
cleanup_terraform() {
    log "Cleaning up Terraform infrastructure..."
    
    cd terraform
    
    # Destroy main infrastructure
    terraform destroy -auto-approve || true
    
    cd ..
    
    log_success "Terraform infrastructure cleaned up"
}

# Function to cleanup backend infrastructure
cleanup_backend() {
    log "Cleaning up backend infrastructure..."
    
    cd terraform/modules/backend
    
    # Destroy backend infrastructure
    terraform destroy -auto-approve || true
    
    cd ../..
    
    log_success "Backend infrastructure cleaned up"
}

# Function to show cost summary
show_cost_summary() {
    log " Cost Summary:"
    echo "=================="
    echo "Resources that were running:"
    echo "- EKS Cluster: ~$0.10/hour"
    echo "- EC2 instances (t3.small SPOT): ~$0.02/hour"
    echo "- Application Load Balancer: ~$0.02/hour"
    echo "- DynamoDB: Pay-per-request (minimal)"
    echo "- CloudWatch: Minimal cost"
    echo ""
    echo "Total estimated cost per hour: ~$0.15"
    echo "If running for 1 hour: ~$0.15"
    echo "If running for 2 hours: ~$0.30"
    echo ""
    log "Check your AWS billing dashboard for actual costs"
}

# Main cleanup function
main() {
    log " Starting immediate cleanup..."
    
    # Kill scheduled cleanup if running
    kill_scheduled_cleanup
    
    # Cleanup Kubernetes resources
    cleanup_kubernetes
    
    # Cleanup Terraform infrastructure
    cleanup_terraform
    
    # Cleanup backend infrastructure
    cleanup_backend
    
    # Clean up local files
    rm -f cleanup.sh cleanup.pid
    
    # Show cost summary
    show_cost_summary
    
    log_success " Cleanup completed successfully!"
    log "All AWS resources have been destroyed"
    log "Your AWS credits are safe! "
}

# Run main function
main "$@"
