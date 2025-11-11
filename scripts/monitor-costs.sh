#!/bin/bash
# monitor-costs.sh - Monitor AWS costs for the deployment

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

# Function to check running resources
check_running_resources() {
    log "Checking running AWS resources..."
    
    echo ""
    echo " EKS Clusters:"
    aws eks list-clusters --region ap-southeast-1 --query 'clusters[?contains(@, `realistic-demo-pretamane`)]' --output table 2>/dev/null || echo "No EKS clusters found"
    
    echo ""
    echo " EC2 Instances:"
    aws ec2 describe-instances --region ap-southeast-1 --filters "Name=tag:Name,Values=*realistic-demo-pretamane*" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table 2>/dev/null || echo "No EC2 instances found"
    
    echo ""
    echo " Load Balancers:"
    aws elbv2 describe-load-balancers --region ap-southeast-1 --query 'LoadBalancers[?contains(LoadBalancerName, `realistic-demo-pretamane`) || contains(LoadBalancerName, `k8s-`)].[LoadBalancerName,State.Code,Type]' --output table 2>/dev/null || echo "No load balancers found"
    
    echo ""
    echo " DynamoDB Tables:"
    aws dynamodb list-tables --region ap-southeast-1 --query 'TableNames[?contains(@, `realistic-demo-pretamane`)]' --output table 2>/dev/null || echo "No DynamoDB tables found"
    
    echo ""
    echo " S3 Buckets:"
    aws s3 ls --region ap-southeast-1 | grep realistic-demo-pretamane || echo "No S3 buckets found"
}

# Function to estimate costs
estimate_costs() {
    log "Estimating current costs..."
    
    echo ""
    echo " Cost Estimation (per hour):"
    echo "=============================="
    
    # Count EKS clusters
    EKS_COUNT=$(aws eks list-clusters --region ap-southeast-1 --query 'clusters[?contains(@, `realistic-demo-pretamane`)] | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$EKS_COUNT" -gt 0 ]; then
        echo "EKS Cluster: $0.10/hour"
    fi
    
    # Count running EC2 instances
    EC2_COUNT=$(aws ec2 describe-instances --region ap-southeast-1 --filters "Name=tag:Name,Values=*realistic-demo-pretamane*" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].InstanceId | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$EC2_COUNT" -gt 0 ]; then
        echo "EC2 Instances ($EC2_COUNT x t3.small SPOT): $0.02/hour each"
    fi
    
    # Count load balancers
    ALB_COUNT=$(aws elbv2 describe-load-balancers --region ap-southeast-1 --query 'LoadBalancers[?contains(LoadBalancerName, `realistic-demo-pretamane`) || contains(LoadBalancerName, `k8s-`)] | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$ALB_COUNT" -gt 0 ]; then
        echo "Application Load Balancer: $0.02/hour"
    fi
    
    # DynamoDB (pay-per-request)
    DYNAMODB_COUNT=$(aws dynamodb list-tables --region ap-southeast-1 --query 'TableNames[?contains(@, `realistic-demo-pretamane`)] | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$DYNAMODB_COUNT" -gt 0 ]; then
        echo "DynamoDB Tables: Pay-per-request (minimal cost)"
    fi
    
    echo ""
    echo "Total estimated cost per hour: ~$0.15"
}

# Function to show billing information
show_billing_info() {
    log "Billing Information:"
    
    echo ""
    echo " How to check your actual costs:"
    echo "=================================="
    echo "1. AWS Console → Billing & Cost Management"
    echo "2. Go to 'Cost Explorer'"
    echo "3. Set date range to 'Last 24 hours'"
    echo "4. Filter by service (EKS, EC2, ELB, DynamoDB)"
    echo ""
    echo " Direct link: https://console.aws.amazon.com/billing/home#/costexplorer"
    echo ""
    echo "  Note: Costs may take up to 24 hours to appear in billing"
}

# Function to show cleanup instructions
show_cleanup_instructions() {
    log "Cleanup Instructions:"
    
    echo ""
    echo " To clean up resources immediately:"
    echo "====================================="
    echo "1. Run: ./scripts/cleanup-now.sh"
    echo "2. Or manually:"
    echo "   - Delete EKS cluster"
    echo "   - Terminate EC2 instances"
    echo "   - Delete load balancers"
    echo "   - Delete DynamoDB tables"
    echo "   - Delete S3 buckets"
    echo ""
    echo " Automatic cleanup:"
    echo "===================="
    if [ -f cleanup.pid ]; then
        CLEANUP_PID=$(cat cleanup.pid)
        if kill -0 $CLEANUP_PID 2>/dev/null; then
            echo " Automatic cleanup is scheduled (PID: $CLEANUP_PID)"
            echo "   To cancel: kill $CLEANUP_PID"
        else
            echo " Automatic cleanup process not running"
        fi
    else
        echo " No automatic cleanup scheduled"
    fi
}

# Main function
main() {
    log " AWS Cost Monitor for realistic-demo-pretamane"
    echo "=============================================="
    
    # Check running resources
    check_running_resources
    
    # Estimate costs
    estimate_costs
    
    # Show billing information
    show_billing_info
    
    # Show cleanup instructions
    show_cleanup_instructions
    
    echo ""
    log " Tips to minimize costs:"
    echo "========================="
    echo "1. Use SPOT instances (already configured)"
    echo "2. Use pay-per-request DynamoDB (already configured)"
    echo "3. Clean up resources when done testing"
    echo "4. Monitor costs regularly"
    echo "5. Set up billing alerts in AWS Console"
}

# Run main function
main "$@"
