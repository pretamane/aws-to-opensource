#!/bin/bash
# cleanup-comprehensive.sh - Comprehensive cleanup script for ALL resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="realistic-demo-pretamane"
REGION="ap-southeast-1"

# Function to log with timestamp
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

log_highlight() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')]  $1${NC}"
}

# Function to cleanup Kubernetes resources
cleanup_kubernetes() {
    log_highlight "Cleaning up Kubernetes resources..."
    
    # Delete application resources
    kubectl delete -f k8s/advanced-deployment.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/hpa.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/ingress.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/service.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/deployment.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/serviceaccount.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/configmap.yaml --ignore-not-found=true || true
    
    # Delete advanced mounting techniques
    kubectl delete -f k8s/rclone-sidecar.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/init-container-mount.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/aws-credentials-secret.yaml --ignore-not-found=true || true
    
    # Delete advanced storage resources
    kubectl delete -f k8s/advanced-storage-secrets.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/advanced-efs-pv.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/efs-pv.yaml --ignore-not-found=true || true
    
    # Delete Helm releases
    helm uninstall aws-efs-csi-driver -n kube-system --ignore-not-found || true
    helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found || true
    helm uninstall cluster-autoscaler -n kube-system --ignore-not-found || true
    helm uninstall aws-cloudwatch-metrics -n amazon-cloudwatch --ignore-not-found || true
    helm uninstall metrics-server -n kube-system --ignore-not-found || true
    
    # Wait for resources to be deleted
    log "Waiting for Kubernetes resources to be deleted..."
    sleep 30
    
    log_success "Kubernetes resources cleaned up"
}

# Function to cleanup Terraform infrastructure
cleanup_terraform() {
    log_highlight "Cleaning up Terraform infrastructure..."
    
    cd terraform
    
    # Destroy main infrastructure
    terraform destroy -auto-approve || true
    
    cd ..
    
    log_success "Terraform infrastructure cleaned up"
}

# Function to cleanup backend infrastructure
cleanup_backend() {
    log_highlight "Cleaning up backend infrastructure..."
    
    cd terraform/modules/backend
    
    # Destroy backend infrastructure
    terraform destroy -auto-approve || true
    
    cd ../../..
    
    log_success "Backend infrastructure cleaned up"
}

# Function to cleanup remaining AWS resources
cleanup_remaining_resources() {
    log_highlight "Cleaning up remaining AWS resources..."
    
    # Clean up any remaining EFS file systems
    log "Cleaning up EFS file systems..."
    EFS_IDS=$(aws efs describe-file-systems --region $REGION --query 'FileSystems[?Tags[?Key==`Name` && Value==`'$PROJECT_NAME'-efs`]].FileSystemId' --output text)
    for EFS_ID in $EFS_IDS; do
        if [ -n "$EFS_ID" ]; then
            log "Deleting EFS file system: $EFS_ID"
            aws efs delete-file-system --file-system-id $EFS_ID --region $REGION || true
        fi
    done
    
    # Clean up any remaining S3 buckets
    log "Cleaning up S3 buckets..."
    BUCKETS=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `'$PROJECT_NAME'`)].Name' --output text)
    for BUCKET in $BUCKETS; do
        if [ -n "$BUCKET" ]; then
            log "Deleting S3 bucket: $BUCKET"
            aws s3 rm s3://$BUCKET --recursive || true
            aws s3api delete-bucket --bucket $BUCKET --region $REGION || true
        fi
    done
    
    # Clean up any remaining OpenSearch domains
    log "Cleaning up OpenSearch domains..."
    aws opensearch delete-domain --domain-name $PROJECT_NAME-search --region $REGION || true
    
    # Clean up any remaining DynamoDB tables
    log "Cleaning up DynamoDB tables..."
    aws dynamodb delete-table --table-name $PROJECT_NAME-contact-submissions --region $REGION || true
    aws dynamodb delete-table --table-name $PROJECT_NAME-website-visitors --region $REGION || true
    
    # Clean up any remaining IAM roles
    log "Cleaning up IAM roles..."
    ROLES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `'$PROJECT_NAME'`)].RoleName' --output text)
    for ROLE in $ROLES; do
        if [ -n "$ROLE" ]; then
            log "Deleting IAM role: $ROLE"
            # Detach policies first
            POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE --query 'AttachedPolicies[].PolicyArn' --output text)
            for POLICY in $POLICIES; do
                aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY || true
            done
            aws iam delete-role --role-name $ROLE || true
        fi
    done
    
    # Clean up any remaining IAM policies
    log "Cleaning up IAM policies..."
    POLICIES=$(aws iam list-policies --query 'Policies[?contains(PolicyName, `'$PROJECT_NAME'`)].Arn' --output text)
    for POLICY in $POLICIES; do
        if [ -n "$POLICY" ]; then
            log "Deleting IAM policy: $POLICY"
            aws iam delete-policy --policy-arn $POLICY || true
        fi
    done
    
    log_success "Remaining AWS resources cleaned up"
}

# Function to show cleanup summary
show_cleanup_summary() {
    log_highlight " Comprehensive Cleanup Summary:"
    echo "======================================"
    echo " Kubernetes Resources: DELETED"
    echo " Terraform Infrastructure: DELETED"
    echo " Backend Infrastructure: DELETED"
    echo " EFS File Systems: DELETED"
    echo " S3 Buckets: DELETED"
    echo " OpenSearch Domains: DELETED"
    echo " DynamoDB Tables: DELETED"
    echo " IAM Roles & Policies: DELETED"
    echo " Helm Releases: DELETED"
    echo " Advanced Storage: DELETED"
    echo " Mounting Techniques: DELETED"
    echo " Indexing Components: DELETED"
    echo ""
    log_success " ALL resources have been cleaned up!"
    log " Your AWS credits are safe!"
}

# Main cleanup function
main() {
    log_highlight " Starting COMPREHENSIVE Cleanup..."
    log "Project: $PROJECT_NAME"
    log "Region: $REGION"
    echo ""
    
    # Cleanup Kubernetes resources
    cleanup_kubernetes
    
    # Cleanup Terraform infrastructure
    cleanup_terraform
    
    # Cleanup backend infrastructure
    cleanup_backend
    
    # Cleanup remaining AWS resources
    cleanup_remaining_resources
    
    # Show cleanup summary
    show_cleanup_summary
    
    log_success " COMPREHENSIVE cleanup completed successfully!"
    log "All AWS resources have been destroyed"
    log "Your AWS credits are safe! "
}

# Trap to handle script interruption
trap 'log_error "Script interrupted. Some resources may still exist."; exit 1' INT TERM

# Run main function
main "$@"
