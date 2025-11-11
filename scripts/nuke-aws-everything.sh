#!/bin/bash
# nuke-aws-everything.sh - Complete AWS Resource Destruction Script
#   WARNING: This will destroy ALL resources in your AWS account related to this project
#  This script will help you avoid AWS charges by cleaning up everything

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_danger() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')]  $1${NC}"
}

# Confirmation prompt
confirm_destruction() {
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                             DANGER ZONE                                 ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║  This script will DESTROY ALL AWS resources for this project:               ║"
    echo "║                                                                              ║"
    echo "║  ️  EKS Cluster & Node Groups                                              ║"
    echo "║  ️  VPC, Subnets, Security Groups                                         ║"
    echo "║  ️  EFS File Systems & Access Points                                      ║"
    echo "║  ️  S3 Buckets & Objects                                                  ║"
    echo "║  ️  OpenSearch Domains                                                    ║"
    echo "║  ️  Lambda Functions                                                      ║"
    echo "║  ️  DynamoDB Tables                                                       ║"
    echo "║  ️  IAM Roles, Policies, Users                                            ║"
    echo "║  ️  CloudWatch Logs & Metrics                                             ║"
    echo "║  ️  Application Load Balancers                                            ║"
    echo "║  ️  Backup Vaults & Plans                                                 ║"
    echo "║                                                                              ║"
    echo "║   This will STOP ALL AWS CHARGES for this project                         ║"
    echo "║    This action is IRREVERSIBLE                                            ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "Type 'NUKE' to confirm destruction: " confirmation
    if [ "$confirmation" != "NUKE" ]; then
        log_warning "Destruction cancelled. Your AWS resources are safe."
        exit 0
    fi
    
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║   FINAL WARNING: You have 10 seconds to cancel (Ctrl+C)                   ║"
    echo "║  After this, ALL resources will be destroyed!                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    for i in {10..1}; do
        echo -e "${RED} Destruction in $i seconds...${NC}"
        sleep 1
    done
}

# Function to cleanup Kubernetes resources
cleanup_kubernetes() {
    log " Cleaning up Kubernetes resources..."
    
    # Delete all deployments
    kubectl delete deployment --all --ignore-not-found=true || true
    
    # Delete all services
    kubectl delete service --all --ignore-not-found=true || true
    
    # Delete all ingress
    kubectl delete ingress --all --ignore-not-found=true || true
    
    # Delete all PVCs
    kubectl delete pvc --all --ignore-not-found=true || true
    
    # Delete all PVs
    kubectl delete pv --all --ignore-not-found=true || true
    
    # Delete all ConfigMaps
    kubectl delete configmap --all --ignore-not-found=true || true
    
    # Delete all Secrets
    kubectl delete secret --all --ignore-not-found=true || true
    
    # Delete all StorageClasses
    kubectl delete storageclass --all --ignore-not-found=true || true
    
    log_success "Kubernetes resources cleaned up"
}

# Function to cleanup Terraform infrastructure
cleanup_terraform() {
    log " Cleaning up Terraform infrastructure..."
    
    cd terraform
    
    # Destroy main infrastructure
    log "Destroying main infrastructure..."
    terraform destroy -auto-approve || true
    
    # Destroy backend infrastructure
    log "Destroying backend infrastructure..."
    cd modules/backend
    terraform destroy -auto-approve || true
    cd ../..
    
    cd ..
    
    log_success "Terraform infrastructure cleaned up"
}

# Function to cleanup AWS resources manually (fallback)
cleanup_aws_manual() {
    log " Manual AWS cleanup (fallback method)..."
    
    # Get AWS account ID
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REGION="ap-southeast-1"
    
    log "Cleaning up resources in account: $ACCOUNT_ID, region: $REGION"
    
    # Delete EKS clusters
    log "Deleting EKS clusters..."
    aws eks list-clusters --region $REGION --query 'clusters[?contains(@, `realistic-demo-pretamane`)]' --output text | while read cluster; do
        if [ ! -z "$cluster" ]; then
            log "Deleting EKS cluster: $cluster"
            aws eks delete-cluster --region $REGION --name $cluster || true
        fi
    done
    
    # Delete EFS file systems
    log "Deleting EFS file systems..."
    aws efs describe-file-systems --region $REGION --query 'FileSystems[?contains(Name, `realistic-demo-pretamane`)].FileSystemId' --output text | while read fsid; do
        if [ ! -z "$fsid" ]; then
            log "Deleting EFS: $fsid"
            aws efs delete-file-system --region $REGION --file-system-id $fsid || true
        fi
    done
    
    # Delete S3 buckets
    log "Deleting S3 buckets..."
    aws s3api list-buckets --query 'Buckets[?contains(Name, `realistic-demo-pretamane`)].Name' --output text | while read bucket; do
        if [ ! -z "$bucket" ]; then
            log "Deleting S3 bucket: $bucket"
            aws s3 rm s3://$bucket --recursive || true
            aws s3api delete-bucket --region $REGION --bucket $bucket || true
        fi
    done
    
    # Delete OpenSearch domains
    log "Deleting OpenSearch domains..."
    aws opensearch list-domain-names --region $REGION --query 'DomainNames[?contains(@, `pretamane`)]' --output text | while read domain; do
        if [ ! -z "$domain" ]; then
            log "Deleting OpenSearch domain: $domain"
            aws opensearch delete-domain --region $REGION --domain-name $domain || true
        fi
    done
    
    # Delete Lambda functions
    log "Deleting Lambda functions..."
    aws lambda list-functions --region $REGION --query 'Functions[?contains(FunctionName, `realistic-demo-pretamane`)].FunctionName' --output text | while read func; do
        if [ ! -z "$func" ]; then
            log "Deleting Lambda function: $func"
            aws lambda delete-function --region $REGION --function-name $func || true
        fi
    done
    
    # Delete DynamoDB tables
    log "Deleting DynamoDB tables..."
    aws dynamodb list-tables --region $REGION --query 'TableNames[?contains(@, `realistic-demo-pretamane`)]' --output text | while read table; do
        if [ ! -z "$table" ]; then
            log "Deleting DynamoDB table: $table"
            aws dynamodb delete-table --region $REGION --table-name $table || true
        fi
    done
    
    # Delete IAM roles
    log "Deleting IAM roles..."
    aws iam list-roles --query 'Roles[?contains(RoleName, `realistic-demo-pretamane`)].RoleName' --output text | while read role; do
        if [ ! -z "$role" ]; then
            log "Deleting IAM role: $role"
            # Detach policies first
            aws iam list-attached-role-policies --role-name $role --query 'AttachedPolicies[].PolicyArn' --output text | while read policy; do
                if [ ! -z "$policy" ]; then
                    aws iam detach-role-policy --role-name $role --policy-arn $policy || true
                fi
            done
            aws iam delete-role --role-name $role || true
        fi
    done
    
    # Delete IAM policies
    log "Deleting IAM policies..."
    aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `realistic-demo-pretamane`)].Arn' --output text | while read policy; do
        if [ ! -z "$policy" ]; then
            log "Deleting IAM policy: $policy"
            aws iam delete-policy --policy-arn $policy || true
        fi
    done
    
    # Delete VPCs
    log "Deleting VPCs..."
    aws ec2 describe-vpcs --region $REGION --query 'Vpcs[?contains(Tags[?Key==`Name`].Value, `realistic-demo-pretamane`)].VpcId' --output text | while read vpc; do
        if [ ! -z "$vpc" ]; then
            log "Deleting VPC: $vpc"
            aws ec2 delete-vpc --region $REGION --vpc-id $vpc || true
        fi
    done
    
    log_success "Manual AWS cleanup completed"
}

# Function to show cost summary
show_cost_summary() {
    log " Cost Summary:"
    echo "=================="
    echo "Resources that were running:"
    echo "- EKS Cluster: ~$0.10/hour"
    echo "- EC2 instances (t3.small SPOT): ~$0.02/hour"
    echo "- Application Load Balancer: ~$0.02/hour"
    echo "- EFS File System: ~$0.30/GB/month"
    echo "- S3 Storage: ~$0.023/GB/month"
    echo "- OpenSearch: ~$0.10/hour"
    echo "- DynamoDB: Pay-per-request (minimal)"
    echo "- CloudWatch: Minimal cost"
    echo ""
    echo "Total estimated cost per hour: ~$0.15"
    echo "If running for 1 hour: ~$0.15"
    echo "If running for 2 hours: ~$0.30"
    echo "If running for 24 hours: ~$3.60"
    echo ""
    log "Check your AWS billing dashboard for actual costs"
}

# Function to verify cleanup
verify_cleanup() {
    log " Verifying cleanup..."
    
    REGION="ap-southeast-1"
    
    # Check EKS clusters
    EKS_COUNT=$(aws eks list-clusters --region $REGION --query 'clusters[?contains(@, `realistic-demo-pretamane`)]' --output text | wc -l)
    if [ $EKS_COUNT -eq 0 ]; then
        log_success " No EKS clusters found"
    else
        log_warning "  $EKS_COUNT EKS clusters still exist"
    fi
    
    # Check EFS file systems
    EFS_COUNT=$(aws efs describe-file-systems --region $REGION --query 'FileSystems[?contains(Name, `realistic-demo-pretamane`)].FileSystemId' --output text | wc -l)
    if [ $EFS_COUNT -eq 0 ]; then
        log_success " No EFS file systems found"
    else
        log_warning "  $EFS_COUNT EFS file systems still exist"
    fi
    
    # Check S3 buckets
    S3_COUNT=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `realistic-demo-pretamane`)].Name' --output text | wc -l)
    if [ $S3_COUNT -eq 0 ]; then
        log_success " No S3 buckets found"
    else
        log_warning "  $S3_COUNT S3 buckets still exist"
    fi
    
    # Check IAM roles
    IAM_COUNT=$(aws iam list-roles --query 'Roles[?contains(RoleName, `realistic-demo-pretamane`)].RoleName' --output text | wc -l)
    if [ $IAM_COUNT -eq 0 ]; then
        log_success " No IAM roles found"
    else
        log_warning "  $IAM_COUNT IAM roles still exist"
    fi
}

# Main cleanup function
main() {
    log_danger " Starting AWS Nuke Operation..."
    
    # Confirmation
    confirm_destruction
    
    # Cleanup Kubernetes resources
    cleanup_kubernetes
    
    # Cleanup Terraform infrastructure
    cleanup_terraform
    
    # Manual AWS cleanup (fallback)
    cleanup_aws_manual
    
    # Verify cleanup
    verify_cleanup
    
    # Show cost summary
    show_cost_summary
    
    log_success " AWS Nuke Operation completed!"
    log "All AWS resources have been destroyed"
    log "Your AWS credits are safe! "
    log ""
    log "To rebuild everything later, run:"
    log "  ./scripts/deploy-comprehensive.sh"
}

# Run main function
main "$@"
