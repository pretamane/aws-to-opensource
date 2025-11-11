#!/bin/bash

#  POST-AUTOSCALE NUCLEAR CLEANUP SCRIPT
# This script will DESTROY ALL AWS resources to stop billing
#   WARNING: This action is IRREVERSIBLE!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
}

# Configuration
REGION="ap-southeast-1"
PROJECT_NAME="realistic-demo-pretamane"

echo -e "${RED}"
echo " NUCLEAR AWS CLEANUP SCRIPT "
echo "=========================================="
echo -e "${NC}"
echo "This script will DESTROY ALL AWS resources found in your account."
echo "This action is IRREVERSIBLE and will stop all billing."
echo ""
echo -e "${YELLOW}Resources that will be destroyed:${NC}"
echo "• EKS Clusters (~$73/month)"
echo "• EC2 Instances (~$30/month each)"
echo "• OpenSearch Domains (~$30-50/month)"
echo "• EFS File Systems (~$0.30/GB/month)"
echo "• S3 Buckets (~$0.023/GB/month)"
echo "• DynamoDB Tables (~$0.25/GB/month)"
echo "• Lambda Functions (~$0.20/million requests)"
echo "• VPC Resources (~$45/month each)"
echo ""

# Safety confirmation
echo -e "${RED}  CRITICAL WARNING: This will destroy EVERYTHING! ${NC}"
echo ""
read -p "Type 'NUKE' to confirm you want to destroy all AWS resources: " confirmation

if [ "$confirmation" != "NUKE" ]; then
    log_error "Confirmation failed. Exiting for safety."
    exit 1
fi

echo ""
log " Starting nuclear cleanup of AWS resources..."
echo "=============================================="

# Function to check if resource exists before deletion
check_and_delete() {
    local resource_type="$1"
    local resource_id="$2"
    local delete_command="$3"
    
    if [ -n "$resource_id" ] && [ "$resource_id" != "None" ]; then
        log "Deleting $resource_type: $resource_id"
        eval "$delete_command" || log_warning "Failed to delete $resource_type: $resource_id"
    else
        log "No $resource_type found to delete"
    fi
}

# 1. Delete EKS Clusters
log "Step 1: Deleting EKS Clusters..."
echo "================================"
EKS_CLUSTERS=$(aws eks list-clusters --region $REGION --query 'clusters[]' --output text)
for cluster in $EKS_CLUSTERS; do
    if [[ "$cluster" == *"$PROJECT_NAME"* ]] || [[ "$cluster" == *"pretamane"* ]]; then
        log "Deleting EKS cluster: $cluster"
        aws eks delete-cluster --region $REGION --name "$cluster" || log_warning "Failed to delete cluster: $cluster"
    fi
done

# 2. Delete EC2 Instances
log "Step 2: Deleting EC2 Instances..."
echo "================================="
EC2_INSTANCES=$(aws ec2 describe-instances --region $REGION --query 'Reservations[*].Instances[?State.Name!=`terminated`].[InstanceId]' --output text)
for instance in $EC2_INSTANCES; do
    if [ -n "$instance" ]; then
        log "Terminating EC2 instance: $instance"
        aws ec2 terminate-instances --region $REGION --instance-ids "$instance" || log_warning "Failed to terminate instance: $instance"
    fi
done

# 3. Delete OpenSearch Domains
log "Step 3: Deleting OpenSearch Domains..."
echo "====================================="
OPENSEARCH_DOMAINS=$(aws opensearch list-domain-names --region $REGION --query 'DomainNames[].DomainName' --output text)
for domain in $OPENSEARCH_DOMAINS; do
    if [[ "$domain" == *"$PROJECT_NAME"* ]] || [[ "$domain" == *"pretamane"* ]]; then
        log "Deleting OpenSearch domain: $domain"
        aws opensearch delete-domain --region $REGION --domain-name "$domain" || log_warning "Failed to delete domain: $domain"
    fi
done

# 4. Delete EFS File Systems
log "Step 4: Deleting EFS File Systems..."
echo "==================================="
EFS_SYSTEMS=$(aws efs describe-file-systems --region $REGION --query 'FileSystems[?Name!=`null`].[FileSystemId,Name]' --output text)
while IFS=$'\t' read -r fs_id fs_name; do
    if [[ "$fs_name" == *"$PROJECT_NAME"* ]] || [[ "$fs_name" == *"pretamane"* ]]; then
        log "Deleting EFS file system: $fs_id ($fs_name)"
        aws efs delete-file-system --region $REGION --file-system-id "$fs_id" || log_warning "Failed to delete EFS: $fs_id"
    fi
done <<< "$EFS_SYSTEMS"

# 5. Delete S3 Buckets
log "Step 5: Deleting S3 Buckets..."
echo "============================="
S3_BUCKETS=$(aws s3 ls --region $REGION | grep -E "(pretamane|realistic-demo)" | awk '{print $3}')
for bucket in $S3_BUCKETS; do
    if [ -n "$bucket" ]; then
        log "Deleting S3 bucket: $bucket"
        # Delete all objects first
        aws s3 rm s3://"$bucket" --recursive || log_warning "Failed to delete objects from bucket: $bucket"
        # Delete the bucket
        aws s3 rb s3://"$bucket" || log_warning "Failed to delete bucket: $bucket"
    fi
done

# 6. Delete DynamoDB Tables
log "Step 6: Deleting DynamoDB Tables..."
echo "=================================="
DYNAMODB_TABLES=$(aws dynamodb list-tables --region $REGION --query 'TableNames[]' --output text)
for table in $DYNAMODB_TABLES; do
    if [[ "$table" == *"$PROJECT_NAME"* ]] || [[ "$table" == *"pretamane"* ]] || [[ "$table" == *"ContactSubmissions"* ]] || [[ "$table" == *"WebsiteVisitors"* ]] || [[ "$table" == *"terraform-locks"* ]]; then
        log "Deleting DynamoDB table: $table"
        aws dynamodb delete-table --region $REGION --table-name "$table" || log_warning "Failed to delete table: $table"
    fi
done

# 7. Delete Lambda Functions
log "Step 7: Deleting Lambda Functions..."
echo "==================================="
LAMBDA_FUNCTIONS=$(aws lambda list-functions --region $REGION --query 'Functions[].FunctionName' --output text)
for function in $LAMBDA_FUNCTIONS; do
    if [[ "$function" == *"$PROJECT_NAME"* ]] || [[ "$function" == *"pretamane"* ]]; then
        log "Deleting Lambda function: $function"
        aws lambda delete-function --region $REGION --function-name "$function" || log_warning "Failed to delete function: $function"
    fi
done

# 8. Delete VPC Resources
log "Step 8: Deleting VPC Resources..."
echo "================================="
VPC_IDS=$(aws ec2 describe-vpcs --region $REGION --query 'Vpcs[?Tags[?Key==`Name` && contains(Value, `pretamane`)]].VpcId' --output text)
for vpc_id in $VPC_IDS; do
    if [ -n "$vpc_id" ]; then
        log "Deleting VPC: $vpc_id"
        
        # Delete NAT Gateways
        NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text)
        for nat_gw in $NAT_GATEWAYS; do
            log "Deleting NAT Gateway: $nat_gw"
            aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id "$nat_gw" || log_warning "Failed to delete NAT Gateway: $nat_gw"
        done
        
        # Delete Internet Gateways
        IGW_IDS=$(aws ec2 describe-internet-gateways --region $REGION --filter "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text)
        for igw_id in $IGW_IDS; do
            log "Detaching and deleting Internet Gateway: $igw_id"
            aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" || log_warning "Failed to detach IGW: $igw_id"
            aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id "$igw_id" || log_warning "Failed to delete IGW: $igw_id"
        done
        
        # Delete Subnets
        SUBNET_IDS=$(aws ec2 describe-subnets --region $REGION --filter "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text)
        for subnet_id in $SUBNET_IDS; do
            log "Deleting Subnet: $subnet_id"
            aws ec2 delete-subnet --region $REGION --subnet-id "$subnet_id" || log_warning "Failed to delete subnet: $subnet_id"
        done
        
        # Delete Route Tables (except main)
        ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --region $REGION --filter "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
        for rt_id in $ROUTE_TABLE_IDS; do
            log "Deleting Route Table: $rt_id"
            aws ec2 delete-route-table --region $REGION --route-table-id "$rt_id" || log_warning "Failed to delete route table: $rt_id"
        done
        
        # Delete Security Groups (except default)
        SECURITY_GROUP_IDS=$(aws ec2 describe-security-groups --region $REGION --filter "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
        for sg_id in $SECURITY_GROUP_IDS; do
            log "Deleting Security Group: $sg_id"
            aws ec2 delete-security-group --region $REGION --group-id "$sg_id" || log_warning "Failed to delete security group: $sg_id"
        done
        
        # Finally delete the VPC
        aws ec2 delete-vpc --region $REGION --vpc-id "$vpc_id" || log_warning "Failed to delete VPC: $vpc_id"
    fi
done

# 9. Delete IAM Roles and Policies
log "Step 9: Cleaning up IAM Resources..."
echo "==================================="
IAM_ROLES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `pretamane`) || contains(RoleName, `realistic-demo`)].RoleName' --output text)
for role in $IAM_ROLES; do
    if [ -n "$role" ]; then
        log "Deleting IAM Role: $role"
        # Detach policies first
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text)
        for policy_arn in $ATTACHED_POLICIES; do
            aws iam detach-role-policy --role-name "$role" --policy-arn "$policy_arn" || log_warning "Failed to detach policy: $policy_arn"
        done
        # Delete the role
        aws iam delete-role --role-name "$role" || log_warning "Failed to delete role: $role"
    fi
done

# 10. Final verification
log "Step 10: Final Resource Check..."
echo "==============================="
log "Checking for remaining resources..."

# Check EKS
REMAINING_EKS=$(aws eks list-clusters --region $REGION --query 'clusters[]' --output text | grep -E "(pretamane|realistic-demo)" || true)
if [ -n "$REMAINING_EKS" ]; then
    log_warning "Remaining EKS clusters: $REMAINING_EKS"
else
    log_success "No EKS clusters remaining"
fi

# Check EC2
REMAINING_EC2=$(aws ec2 describe-instances --region $REGION --query 'Reservations[*].Instances[?State.Name!=`terminated`].[InstanceId]' --output text | grep -v "None" || true)
if [ -n "$REMAINING_EC2" ]; then
    log_warning "Remaining EC2 instances: $REMAINING_EC2"
else
    log_success "No EC2 instances remaining"
fi

# Check S3
REMAINING_S3=$(aws s3 ls --region $REGION | grep -E "(pretamane|realistic-demo)" || true)
if [ -n "$REMAINING_S3" ]; then
    log_warning "Remaining S3 buckets:"
    echo "$REMAINING_S3"
else
    log_success "No S3 buckets remaining"
fi

# Summary
echo ""
echo -e "${GREEN} NUCLEAR CLEANUP COMPLETED! ${NC}"
echo "=================================="
log_success "All AWS resources have been destroyed"
log_success "Your AWS credits are now safe! "
echo ""
log "Resources destroyed:"
echo "• EKS Clusters"
echo "• EC2 Instances" 
echo "• OpenSearch Domains"
echo "• EFS File Systems"
echo "• S3 Buckets"
echo "• DynamoDB Tables"
echo "• Lambda Functions"
echo "• VPC Resources"
echo "• IAM Roles and Policies"
echo ""
log_warning "Note: Some resources may take a few minutes to fully terminate"
log_warning "Check AWS Console to verify all resources are deleted"
echo ""
log "To rebuild everything later, run:"
log "  ./scripts/deploy-comprehensive.sh"
echo ""
echo -e "${GREEN} Your AWS credits are now protected! ${NC}"
