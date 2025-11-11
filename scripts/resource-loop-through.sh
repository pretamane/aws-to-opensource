#!/bin/bash

#  AWS Resource Deep Probe & NUKE Script
# Comprehensive inspection AND DELETION of ALL AWS services across ALL regions
# Prioritizes high-cost services that can spike charges if left undetected
# Enhanced to cover realistic-demo-pretamane architecture completely

# Removed 'set -e' to allow script to continue even when resources are not found

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Deletion mode flag
DELETE_MODE=${1:-"scan"}  # "scan" or "nuke"

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

log_critical() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')]  $1${NC}"
}

log_info() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

# Get all enabled regions
get_enabled_regions() {
    log " Discovering all enabled AWS regions..."
    aws ec2 describe-regions --query 'Regions[].RegionName' --output text | tr '\t' '\n' | sort
}

# High-cost services to prioritize
HIGH_COST_SERVICES=(
    "EC2" "EKS" "RDS" "Redshift" "ElastiCache" "OpenSearch" "Elasticsearch"
    "Lambda" "ECS" "Fargate" "Batch" "EMR" "SageMaker" "Comprehend"
    "Transcribe" "Translate" "Polly" "Rekognition" "Textract"
    "CloudFront" "API Gateway" "AppSync" "EventBridge" "SQS" "SNS"
    "Kinesis" "DynamoDB" "DocumentDB" "Neptune" "Timestream"
    "EFS" "FSx" "Storage Gateway" "DataSync" "Transfer Family"
    "Direct Connect" "VPN" "NAT Gateway" "Load Balancer" "Global Accelerator"
    "Route 53" "CloudFormation" "Systems Manager" "Config" "CloudTrail"
    "GuardDuty" "Security Hub" "Inspector" "Macie" "WAF"
    "Secrets Manager" "KMS" "Certificate Manager" "IAM" "Organizations"
    "Cost Explorer" "Budgets" "Trusted Advisor" "Support"
)

# Function to check EC2 instances
check_ec2_instances() {
    local region=$1
    log " Checking EC2 instances in $region..."
    
    local instances=$(aws ec2 describe-instances \
        --region $region \
        --query 'Reservations[*].Instances[?State.Name!=`terminated`].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$instances" ] && [ "$instances" != "None" ]; then
        log_critical " ACTIVE EC2 INSTANCES FOUND in $region:"
        echo "$instances" | while read -r instance_id state instance_type name; do
            if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
                log_critical "   $instance_id | $state | $instance_type | $name"
            fi
        done
        return 1
    else
        log_success " No active EC2 instances in $region"
        return 0
    fi
}

# Function to check EKS clusters
check_eks_clusters() {
    local region=$1
    log " Checking EKS clusters in $region..."
    
    local clusters=$(aws eks list-clusters --region $region --query 'clusters[]' --output text 2>/dev/null || echo "")
    
    if [ -n "$clusters" ] && [ "$clusters" != "None" ]; then
        log_critical " ACTIVE EKS CLUSTERS FOUND in $region:"
        echo "$clusters" | while read -r cluster; do
            if [ -n "$cluster" ] && [ "$cluster" != "None" ]; then
                log_critical "   $cluster"
            fi
        done
        return 1
    else
        log_success " No EKS clusters in $region"
        return 0
    fi
}

# Function to check RDS instances
check_rds_instances() {
    local region=$1
    log " Checking RDS instances in $region..."
    
    local instances=$(aws rds describe-db-instances --region $region --query 'DBInstances[?DBInstanceStatus!=`deleted`].[DBInstanceIdentifier,DBInstanceStatus,DBInstanceClass,Engine]' --output text 2>/dev/null || echo "")
    
    if [ -n "$instances" ] && [ "$instances" != "None" ]; then
        log_critical " ACTIVE RDS INSTANCES FOUND in $region:"
        echo "$instances" | while read -r instance_id status instance_class engine; do
            if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
                log_critical "   $instance_id | $status | $instance_class | $engine"
            fi
        done
        return 1
    else
        log_success " No active RDS instances in $region"
        return 0
    fi
}

# Function to check OpenSearch domains
check_opensearch_domains() {
    local region=$1
    log " Checking OpenSearch domains in $region..."
    
    local domains=$(aws opensearch list-domain-names --region $region --query 'DomainNames[].DomainName' --output text 2>/dev/null || echo "")
    
    if [ -n "$domains" ] && [ "$domains" != "None" ]; then
        log_critical " ACTIVE OPENSEARCH DOMAINS FOUND in $region:"
        echo "$domains" | while read -r domain; do
            if [ -n "$domain" ] && [ "$domain" != "None" ]; then
                log_critical "   $domain"
            fi
        done
        return 1
    else
        log_success " No OpenSearch domains in $region"
        return 0
    fi
}

# Function to check Lambda functions
check_lambda_functions() {
    local region=$1
    log " Checking Lambda functions in $region..."
    
    local functions=$(aws lambda list-functions --region $region --query 'Functions[].FunctionName' --output text 2>/dev/null || echo "")
    
    if [ -n "$functions" ] && [ "$functions" != "None" ]; then
        log_warning "  Lambda functions found in $region:"
        echo "$functions" | while read -r function; do
            if [ -n "$function" ] && [ "$function" != "None" ]; then
                log_warning "   $function"
            fi
        done
        return 1
    else
        log_success " No Lambda functions in $region"
        return 0
    fi
}

# Function to check EFS file systems
check_efs_filesystems() {
    local region=$1
    log " Checking EFS file systems in $region..."
    
    local filesystems=$(aws efs describe-file-systems --region $region --query 'FileSystems[?LifeCycleState==`available`].[FileSystemId,Name,LifeCycleState]' --output text 2>/dev/null || echo "")
    
    if [ -n "$filesystems" ] && [ "$filesystems" != "None" ]; then
        log_critical " ACTIVE EFS FILE SYSTEMS FOUND in $region:"
        echo "$filesystems" | while read -r fs_id name state; do
            if [ -n "$fs_id" ] && [ "$fs_id" != "None" ]; then
                log_critical "   $fs_id | $name | $state"
            fi
        done
        return 1
    else
        log_success " No active EFS file systems in $region"
        return 0
    fi
}

# Function to check S3 buckets
check_s3_buckets() {
    local region=$1
    log " Checking S3 buckets in $region..."
    
    local buckets=$(aws s3api list-buckets --region $region --query 'Buckets[].Name' --output text 2>/dev/null || echo "")
    
    if [ -n "$buckets" ] && [ "$buckets" != "None" ]; then
        log_warning "  S3 buckets found in $region:"
        echo "$buckets" | while read -r bucket; do
            if [ -n "$bucket" ] && [ "$bucket" != "None" ]; then
                # Check bucket size
                local size=$(aws s3 ls s3://$bucket --recursive --summarize --region $region 2>/dev/null | grep "Total Size" | awk '{print $3}' || echo "0")
                if [ "$size" != "0" ] && [ -n "$size" ]; then
                    log_warning "   $bucket (Size: $size bytes)"
                else
                    log_info "   $bucket (Empty)"
                fi
            fi
        done
        return 1
    else
        log_success " No S3 buckets in $region"
        return 0
    fi
}

# Function to check DynamoDB tables
check_dynamodb_tables() {
    local region=$1
    log " Checking DynamoDB tables in $region..."
    
    local tables=$(aws dynamodb list-tables --region $region --query 'TableNames[]' --output text 2>/dev/null || echo "")
    
    if [ -n "$tables" ] && [ "$tables" != "None" ]; then
        log_warning "  DynamoDB tables found in $region:"
        echo "$tables" | while read -r table; do
            if [ -n "$table" ] && [ "$table" != "None" ]; then
                log_warning "   $table"
            fi
        done
        return 1
    else
        log_success " No DynamoDB tables in $region"
        return 0
    fi
}

# Function to check Load Balancers
check_load_balancers() {
    local region=$1
    log " Checking Load Balancers in $region..."
    
    # Application Load Balancers
    local albs=$(aws elbv2 describe-load-balancers --region $region --query 'LoadBalancers[?State.Code==`active`].[LoadBalancerName,Type,State.Code]' --output text 2>/dev/null || echo "")
    
    # Classic Load Balancers
    local clbs=$(aws elb describe-load-balancers --region $region --query 'LoadBalancerDescriptions[?State==`active`].[LoadBalancerName,State]' --output text 2>/dev/null || echo "")
    
    local found_any=false
    
    if [ -n "$albs" ] && [ "$albs" != "None" ]; then
        log_critical " ACTIVE APPLICATION LOAD BALANCERS FOUND in $region:"
        echo "$albs" | while read -r name type state; do
            if [ -n "$name" ] && [ "$name" != "None" ]; then
                log_critical "   $name | $type | $state"
            fi
        done
        found_any=true
    fi
    
    if [ -n "$clbs" ] && [ "$clbs" != "None" ]; then
        log_critical " ACTIVE CLASSIC LOAD BALANCERS FOUND in $region:"
        echo "$clbs" | while read -r name state; do
            if [ -n "$name" ] && [ "$name" != "None" ]; then
                log_critical "   $name | $state"
            fi
        done
        found_any=true
    fi
    
    if [ "$found_any" = false ]; then
        log_success " No active Load Balancers in $region"
        return 0
    else
        return 1
    fi
}

# Function to check NAT Gateways
check_nat_gateways() {
    local region=$1
    log " Checking NAT Gateways in $region..."
    
    local nat_gateways=$(aws ec2 describe-nat-gateways --region $region --query 'NatGateways[?State==`available`].[NatGatewayId,State]' --output text 2>/dev/null || echo "")
    
    if [ -n "$nat_gateways" ] && [ "$nat_gateways" != "None" ]; then
        log_critical " ACTIVE NAT GATEWAYS FOUND in $region:"
        echo "$nat_gateways" | while read -r nat_id state; do
            if [ -n "$nat_id" ] && [ "$nat_id" != "None" ]; then
                log_critical "   $nat_id | $state"
            fi
        done
        return 1
    else
        log_success " No active NAT Gateways in $region"
        return 0
    fi
}

# Function to check Redshift clusters
check_redshift_clusters() {
    local region=$1
    log " Checking Redshift clusters in $region..."
    
    local clusters=$(aws redshift describe-clusters --region $region --query 'Clusters[?ClusterStatus!=`deleted`].[ClusterIdentifier,ClusterStatus,NodeType]' --output text 2>/dev/null || echo "")
    
    if [ -n "$clusters" ] && [ "$clusters" != "None" ]; then
        log_critical " ACTIVE REDSHIFT CLUSTERS FOUND in $region:"
        echo "$clusters" | while read -r cluster_id status node_type; do
            if [ -n "$cluster_id" ] && [ "$cluster_id" != "None" ]; then
                log_critical "   $cluster_id | $status | $node_type"
            fi
        done
        return 1
    else
        log_success " No active Redshift clusters in $region"
        return 0
    fi
}

# Function to check ElastiCache clusters
check_elasticache_clusters() {
    local region=$1
    log " Checking ElastiCache clusters in $region..."
    
    local clusters=$(aws elasticache describe-cache-clusters --region $region --query 'CacheClusters[?CacheClusterStatus!=`deleted`].[CacheClusterId,CacheClusterStatus,CacheNodeType]' --output text 2>/dev/null || echo "")
    
    if [ -n "$clusters" ] && [ "$clusters" != "None" ]; then
        log_critical " ACTIVE ELASTICACHE CLUSTERS FOUND in $region:"
        echo "$clusters" | while read -r cluster_id status node_type; do
            if [ -n "$cluster_id" ] && [ "$cluster_id" != "None" ]; then
                log_critical "   $cluster_id | $status | $node_type"
            fi
        done
        return 1
    else
        log_success " No active ElastiCache clusters in $region"
        return 0
    fi
}

# Function to check SageMaker resources
check_sagemaker_resources() {
    local region=$1
    log " Checking SageMaker resources in $region..."
    
    # Check SageMaker endpoints
    local endpoints=$(aws sagemaker list-endpoints --region $region --query 'Endpoints[?EndpointStatus!=`Deleting`].[EndpointName,EndpointStatus]' --output text 2>/dev/null || echo "")
    
    # Check SageMaker notebook instances
    local notebooks=$(aws sagemaker list-notebook-instances --region $region --query 'NotebookInstances[?NotebookInstanceStatus!=`Deleting`].[NotebookInstanceName,NotebookInstanceStatus]' --output text 2>/dev/null || echo "")
    
    local found_any=false
    
    if [ -n "$endpoints" ] && [ "$endpoints" != "None" ]; then
        log_critical " ACTIVE SAGEMAKER ENDPOINTS FOUND in $region:"
        echo "$endpoints" | while read -r name status; do
            if [ -n "$name" ] && [ "$name" != "None" ]; then
                log_critical "   $name | $status"
            fi
        done
        found_any=true
    fi
    
    if [ -n "$notebooks" ] && [ "$notebooks" != "None" ]; then
        log_critical " ACTIVE SAGEMAKER NOTEBOOKS FOUND in $region:"
        echo "$notebooks" | while read -r name status; do
            if [ -n "$name" ] && [ "$name" != "None" ]; then
                log_critical "   $name | $status"
            fi
        done
        found_any=true
    fi
    
    if [ "$found_any" = false ]; then
        log_success " No active SageMaker resources in $region"
        return 0
    else
        return 1
    fi
}

# Function to check ECS services and Fargate tasks
check_ecs_services() {
    local region=$1
    log " Checking ECS services and Fargate tasks in $region..."
    
    local clusters=$(aws ecs list-clusters --region $region --query 'clusterArns[]' --output text 2>/dev/null || echo "")
    local found_any=false
    
    if [ -n "$clusters" ] && [ "$clusters" != "None" ]; then
        log_critical " ACTIVE ECS CLUSTERS FOUND in $region:"
        echo "$clusters" | while read -r cluster_arn; do
            if [ -n "$cluster_arn" ] && [ "$cluster_arn" != "None" ]; then
                local cluster_name=$(echo $cluster_arn | cut -d'/' -f2)
                log_critical "   ECS Cluster: $cluster_name"
                
                # Check services in this cluster
                local services=$(aws ecs list-services --region $region --cluster $cluster_name --query 'serviceArns[]' --output text 2>/dev/null || echo "")
                if [ -n "$services" ] && [ "$services" != "None" ]; then
                    log_critical "     Services: $services"
                fi
                
                # Check running tasks
                local tasks=$(aws ecs list-tasks --region $region --cluster $cluster_name --query 'taskArns[]' --output text 2>/dev/null || echo "")
                if [ -n "$tasks" ] && [ "$tasks" != "None" ]; then
                    log_critical "     Running Tasks: $tasks"
                fi
            fi
        done
        found_any=true
    fi
    
    # Check for standalone Fargate tasks (not in clusters)
    local fargate_tasks=$(aws ecs list-tasks --region $region --launch-type FARGATE --query 'taskArns[]' --output text 2>/dev/null || echo "")
    if [ -n "$fargate_tasks" ] && [ "$fargate_tasks" != "None" ]; then
        log_critical " STANDALONE FARGATE TASKS FOUND in $region:"
        echo "$fargate_tasks" | while read -r task_arn; do
            if [ -n "$task_arn" ] && [ "$task_arn" != "None" ]; then
                log_critical "   Fargate Task: $task_arn"
                # Get task details
                local task_details=$(aws ecs describe-tasks --region $region --tasks $task_arn --query 'tasks[0].{LastStatus:lastStatus,DesiredStatus:desiredStatus,PlatformVersion:platformVersion}' --output table 2>/dev/null || echo "")
                if [ -n "$task_details" ]; then
                    echo "$task_details"
                fi
            fi
        done
        found_any=true
    fi
    
    if [ "$found_any" = false ]; then
        log_success " No ECS clusters or Fargate tasks in $region"
        return 0
    else
        return 1
    fi
}

# Function to check CloudFront distributions
check_cloudfront_distributions() {
    log " Checking CloudFront distributions (Global)..."
    
    local distributions=$(aws cloudfront list-distributions --query 'DistributionList.Items[?Status==`Deployed`].[Id,DomainName,Status]' --output text 2>/dev/null || echo "")
    
    if [ -n "$distributions" ] && [ "$distributions" != "None" ]; then
        log_critical " ACTIVE CLOUDFRONT DISTRIBUTIONS FOUND:"
        echo "$distributions" | while read -r id domain status; do
            if [ -n "$id" ] && [ "$id" != "None" ]; then
                log_critical "   $id | $domain | $status"
            fi
        done
        return 1
    else
        log_success " No active CloudFront distributions"
        return 0
    fi
}

# Function to check Route 53 hosted zones
check_route53_zones() {
    log " Checking Route 53 hosted zones (Global)..."
    
    local zones=$(aws route53 list-hosted-zones --query 'HostedZones[].Id' --output text 2>/dev/null || echo "")
    
    if [ -n "$zones" ] && [ "$zones" != "None" ]; then
        log_warning "  Route 53 hosted zones found:"
        echo "$zones" | while read -r zone_id; do
            if [ -n "$zone_id" ] && [ "$zone_id" != "None" ]; then
                log_warning "   $zone_id"
            fi
        done
        return 1
    else
        log_success " No Route 53 hosted zones"
        return 0
    fi
}

# Function to check for hidden Kubernetes/container resources
check_hidden_kubernetes_resources() {
    local region=$1
    log " Checking for hidden Kubernetes/container resources in $region..."
    
    local found_any=false
    
    # Check for EC2 instances that might be running Kubernetes manually
    local k8s_instances=$(aws ec2 describe-instances --region $region \
        --filters "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[].Instances[?contains(KeyName, `kube`) || contains(KeyName, `eks`) || contains(Tags[?Key==`Name`].Value, `kube`) || contains(Tags[?Key==`Name`].Value, `eks`) || contains(Tags[?Key==`Name`].Value, `kubernetes`) || contains(Tags[?Key==`kubernetes.io/cluster`].Value, `owned`)].{InstanceId:InstanceId,State:State.Name,InstanceType:InstanceType,Name:Tags[?Key==`Name`].Value|[0],LaunchTime:LaunchTime}' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$k8s_instances" ] && [ "$k8s_instances" != "None" ]; then
        log_critical " KUBERNETES-RELATED EC2 INSTANCES FOUND in $region:"
        echo "$k8s_instances" | while read -r instance_id state instance_type name launch_time; do
            if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
                log_critical "   $instance_id | $state | $instance_type | $name | $launch_time"
            fi
        done
        found_any=true
    fi
    
    # Check for Auto Scaling Groups that might be related to Kubernetes
    local k8s_asgs=$(aws autoscaling describe-auto-scaling-groups --region $region \
        --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `kube`) || contains(AutoScalingGroupName, `eks`) || contains(AutoScalingGroupName, `kubernetes`)].{AutoScalingGroupName:AutoScalingGroupName,DesiredCapacity:DesiredCapacity,MinSize:MinSize,MaxSize:MaxSize,Instances:length(Instances)}' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$k8s_asgs" ] && [ "$k8s_asgs" != "None" ]; then
        log_critical " KUBERNETES-RELATED AUTO SCALING GROUPS FOUND in $region:"
        echo "$k8s_asgs" | while read -r asg_name desired min max instances; do
            if [ -n "$asg_name" ] && [ "$asg_name" != "None" ]; then
                log_critical "   $asg_name | Desired:$desired | Min:$min | Max:$max | Instances:$instances"
            fi
        done
        found_any=true
    fi
    
    # Check for Load Balancers that might be related to Kubernetes
    local k8s_lbs=$(aws elbv2 describe-load-balancers --region $region \
        --query 'LoadBalancers[?contains(LoadBalancerName, `kube`) || contains(LoadBalancerName, `eks`) || contains(LoadBalancerName, `kubernetes`) || contains(Tags[?Key==`kubernetes.io/service-name`].Value, `service`)].{LoadBalancerName:LoadBalancerName,Type:Type,State:State.Code,DNSName:DNSName}' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$k8s_lbs" ] && [ "$k8s_lbs" != "None" ]; then
        log_critical " KUBERNETES-RELATED LOAD BALANCERS FOUND in $region:"
        echo "$k8s_lbs" | while read -r name type state dns; do
            if [ -n "$name" ] && [ "$name" != "None" ]; then
                log_critical "   $name | $type | $state | $dns"
            fi
        done
        found_any=true
    fi
    
    # Check for Security Groups that might be related to Kubernetes
    local k8s_sgs=$(aws ec2 describe-security-groups --region $region \
        --filters "Name=group-name,Values=*kube*,*eks*,*kubernetes*" \
        --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,Description:Description}' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$k8s_sgs" ] && [ "$k8s_sgs" != "None" ]; then
        log_warning "  KUBERNETES-RELATED SECURITY GROUPS FOUND in $region:"
        echo "$k8s_sgs" | while read -r group_id group_name description; do
            if [ -n "$group_id" ] && [ "$group_id" != "None" ]; then
                log_warning "   $group_id | $group_name | $description"
            fi
        done
        found_any=true
    fi
    
    # Check for VPCs that might be related to Kubernetes
    local k8s_vpcs=$(aws ec2 describe-vpcs --region $region \
        --filters "Name=tag:Name,Values=*kube*,*eks*,*kubernetes*" \
        --query 'Vpcs[].{VpcId:VpcId,State:State,CidrBlock:CidrBlock}' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$k8s_vpcs" ] && [ "$k8s_vpcs" != "None" ]; then
        log_warning "  KUBERNETES-RELATED VPCs FOUND in $region:"
        echo "$k8s_vpcs" | while read -r vpc_id state cidr; do
            if [ -n "$vpc_id" ] && [ "$vpc_id" != "None" ]; then
                log_warning "   $vpc_id | $state | $cidr"
            fi
        done
        found_any=true
    fi
    
    # Check for CloudFormation stacks that might contain Kubernetes resources
    local k8s_stacks=$(aws cloudformation list-stacks --region $region \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --query 'StackSummaries[?contains(StackName, `kube`) || contains(StackName, `eks`) || contains(StackName, `kubernetes`)].{StackName:StackName,StackStatus:StackStatus,CreationTime:CreationTime}' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$k8s_stacks" ] && [ "$k8s_stacks" != "None" ]; then
        log_warning "  KUBERNETES-RELATED CLOUDFORMATION STACKS FOUND in $region:"
        echo "$k8s_stacks" | while read -r stack_name status creation_time; do
            if [ -n "$stack_name" ] && [ "$stack_name" != "None" ]; then
                log_warning "   $stack_name | $status | $creation_time"
            fi
        done
        found_any=true
    fi
    
    if [ "$found_any" = false ]; then
        log_success " No hidden Kubernetes/container resources in $region"
        return 0
    else
        return 1
    fi
}

# Function to check for EKS-related billing remnants
check_eks_billing_remnants() {
    local region=$1
    log " Checking for EKS billing remnants in $region..."
    
    local found_any=false
    
    # Check for EKS-related CloudWatch log groups
    local eks_logs=$(aws logs describe-log-groups --region $region \
        --query 'logGroups[?contains(logGroupName, `/aws/eks`) || contains(logGroupName, `eks`)].{LogGroupName:logGroupName,StoredBytes:storedBytes,RetentionInDays:retentionInDays}' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$eks_logs" ] && [ "$eks_logs" != "None" ]; then
        log_critical " EKS-RELATED CLOUDWATCH LOG GROUPS FOUND in $region:"
        echo "$eks_logs" | while read -r log_group stored_bytes retention; do
            if [ -n "$log_group" ] && [ "$log_group" != "None" ]; then
                log_critical "   $log_group | Stored: $stored_bytes bytes | Retention: $retention days"
            fi
        done
        found_any=true
    fi
    
    # Check for EKS-related ENI (Elastic Network Interfaces)
    local eks_enis=$(aws ec2 describe-network-interfaces --region $region \
        --filters "Name=description,Values=*eks*,*EKS*,*kubernetes*" \
        --query 'NetworkInterfaces[].{NetworkInterfaceId:NetworkInterfaceId,Status:Status,Description:Description,PrivateIpAddress:PrivateIpAddress}' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$eks_enis" ] && [ "$eks_enis" != "None" ]; then
        log_critical " EKS-RELATED NETWORK INTERFACES FOUND in $region:"
        echo "$eks_enis" | while read -r eni_id status description private_ip; do
            if [ -n "$eni_id" ] && [ "$eni_id" != "None" ]; then
                log_critical "   $eni_id | $status | $description | $private_ip"
            fi
        done
        found_any=true
    fi
    
    # Check for EKS service-linked roles (global, but check here for completeness)
    local eks_roles=$(aws iam list-roles --query 'Roles[?contains(RoleName, `EKS`) || contains(RoleName, `eks`)].{RoleName:RoleName,CreateDate:CreateDate}' --output text 2>/dev/null || echo "")
    
    if [ -n "$eks_roles" ] && [ "$eks_roles" != "None" ]; then
        log_critical " EKS SERVICE-LINKED ROLES FOUND (Global):"
        echo "$eks_roles" | while read -r role_name create_date; do
            if [ -n "$role_name" ] && [ "$role_name" != "None" ]; then
                log_critical "   $role_name | Created: $create_date"
            fi
        done
        found_any=true
    fi
    
    if [ "$found_any" = false ]; then
        log_success " No EKS billing remnants in $region"
        return 0
    else
        return 1
    fi
}

# Function to check for expensive instance types
check_expensive_instances() {
    local region=$1
    log " Checking for expensive instance types in $region..."
    
    # Define expensive instance types (these can cost $1+/hour)
    local expensive_types="c7i.8xlarge,c7i.4xlarge,c7i.2xlarge,m7i.8xlarge,m7i.4xlarge,m7i.2xlarge,r7i.8xlarge,r7i.4xlarge,r7i.2xlarge,p4d.24xlarge,p3.8xlarge,p3.2xlarge,g5.48xlarge,g5.24xlarge,g5.12xlarge"
    
    local expensive_instances=$(aws ec2 describe-instances --region $region \
        --filters "Name=instance-state-name,Values=running,stopped,pending" \
        --query "Reservations[].Instances[?contains('$expensive_types', InstanceType)].{InstanceId:InstanceId,State:State.Name,InstanceType:InstanceType,Name:Tags[?Key==\`Name\`].Value|[0],LaunchTime:LaunchTime}" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$expensive_instances" ] && [ "$expensive_instances" != "None" ]; then
        log_critical " EXPENSIVE INSTANCE TYPES FOUND in $region (>$1/hour):"
        echo "$expensive_instances" | while read -r instance_id state instance_type name launch_time; do
            if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
                log_critical "   $instance_id | $state | $instance_type | $name | $launch_time"
            fi
        done
        return 1
    else
        log_success " No expensive instance types in $region"
        return 0
    fi
}

# Function to check IAM resources
check_iam_resources() {
    log " Checking IAM resources (Global)..."
    
    # Check IAM users
    local users=$(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null || echo "")
    
    # Check IAM roles
    local roles=$(aws iam list-roles --query 'Roles[].RoleName' --output text 2>/dev/null || echo "")
    
    # Check IAM policies
    local policies=$(aws iam list-policies --scope Local --query 'Policies[].PolicyName' --output text 2>/dev/null || echo "")
    
    local found_any=false
    
    if [ -n "$users" ] && [ "$users" != "None" ]; then
        log_info "ℹ️  IAM users found:"
        echo "$users" | while read -r user; do
            if [ -n "$user" ] && [ "$user" != "None" ]; then
                log_info "   $user"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "DELETING IAM user: $user"
                    aws iam delete-user --user-name "$user" 2>/dev/null || log_error "Failed to delete user $user"
                fi
            fi
        done
        found_any=true
    fi
    
    if [ -n "$roles" ] && [ "$roles" != "None" ]; then
        log_info "ℹ️  IAM roles found:"
        echo "$roles" | while read -r role; do
            if [ -n "$role" ] && [ "$role" != "None" ]; then
                log_info "   $role"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    # Skip AWS service-linked roles
                    if [[ ! "$role" =~ ^AWSServiceRole ]]; then
                        log_critical "DELETING IAM role: $role"
                        # Detach policies first
                        aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | while read -r policy_arn; do
                            if [ -n "$policy_arn" ]; then
                                aws iam detach-role-policy --role-name "$role" --policy-arn "$policy_arn" 2>/dev/null
                            fi
                        done
                        # Delete inline policies
                        aws iam list-role-policies --role-name "$role" --query 'PolicyNames[]' --output text 2>/dev/null | while read -r policy_name; do
                            if [ -n "$policy_name" ]; then
                                aws iam delete-role-policy --role-name "$role" --policy-name "$policy_name" 2>/dev/null
                            fi
                        done
                        aws iam delete-role --role-name "$role" 2>/dev/null || log_error "Failed to delete role $role"
                    fi
                fi
            fi
        done
        found_any=true
    fi
    
    if [ -n "$policies" ] && [ "$policies" != "None" ]; then
        log_info "ℹ️  IAM policies found:"
        echo "$policies" | while read -r policy; do
            if [ -n "$policy" ] && [ "$policy" != "None" ]; then
                log_info "   $policy"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "DELETING IAM policy: $policy"
                    # Get policy ARN
                    local policy_arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$policy'].Arn" --output text 2>/dev/null)
                    if [ -n "$policy_arn" ]; then
                        # Delete all policy versions except default
                        aws iam list-policy-versions --policy-arn "$policy_arn" --query 'Versions[?!IsDefaultVersion].VersionId' --output text 2>/dev/null | while read -r version_id; do
                            if [ -n "$version_id" ]; then
                                aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$version_id" 2>/dev/null
                            fi
                        done
                        aws iam delete-policy --policy-arn "$policy_arn" 2>/dev/null || log_error "Failed to delete policy $policy"
                    fi
                fi
            fi
        done
        found_any=true
    fi
    
    if [ "$found_any" = false ]; then
        log_success " No IAM resources found"
        return 0
    else
        return 1
    fi
}

# Function to check ECR repositories
check_ecr_repositories() {
    local region=$1
    log " Checking ECR repositories in $region..."
    
    local repos=$(aws ecr describe-repositories --region $region --query 'repositories[].repositoryName' --output text 2>/dev/null || echo "")
    
    if [ -n "$repos" ] && [ "$repos" != "None" ]; then
        log_critical " ECR REPOSITORIES FOUND in $region:"
        echo "$repos" | while read -r repo; do
            if [ -n "$repo" ] && [ "$repo" != "None" ]; then
                log_critical "   $repo"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "DELETING ECR repository: $repo"
                    aws ecr delete-repository --region $region --repository-name "$repo" --force 2>/dev/null || log_error "Failed to delete ECR repo $repo"
                fi
            fi
        done
        return 1
    else
        log_success " No ECR repositories in $region"
        return 0
    fi
}

# Function to check Backup vaults and recovery points
check_backup_resources() {
    local region=$1
    log " Checking AWS Backup resources in $region..."
    
    local found_any=false
    
    # Check backup vaults
    local vaults=$(aws backup list-backup-vaults --region $region --query 'BackupVaultList[].BackupVaultName' --output text 2>/dev/null || echo "")
    
    if [ -n "$vaults" ] && [ "$vaults" != "None" ]; then
        log_critical " BACKUP VAULTS FOUND in $region:"
        echo "$vaults" | while read -r vault; do
            if [ -n "$vault" ] && [ "$vault" != "None" ]; then
                log_critical "   $vault"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    # Delete recovery points first
                    log_critical "Deleting recovery points in vault: $vault"
                    aws backup list-recovery-points-by-backup-vault --region $region --backup-vault-name "$vault" --query 'RecoveryPoints[].RecoveryPointArn' --output text 2>/dev/null | while read -r recovery_point; do
                        if [ -n "$recovery_point" ]; then
                            aws backup delete-recovery-point --region $region --backup-vault-name "$vault" --recovery-point-arn "$recovery_point" 2>/dev/null || log_error "Failed to delete recovery point"
                        fi
                    done
                    sleep 5  # Wait for recovery points to be deleted
                    log_critical "DELETING backup vault: $vault"
                    aws backup delete-backup-vault --region $region --backup-vault-name "$vault" 2>/dev/null || log_error "Failed to delete vault $vault"
                fi
            fi
        done
        found_any=true
    fi
    
    # Check backup plans
    local plans=$(aws backup list-backup-plans --region $region --query 'BackupPlansList[].BackupPlanId' --output text 2>/dev/null || echo "")
    
    if [ -n "$plans" ] && [ "$plans" != "None" ]; then
        log_critical " BACKUP PLANS FOUND in $region:"
        echo "$plans" | while read -r plan_id; do
            if [ -n "$plan_id" ] && [ "$plan_id" != "None" ]; then
                log_critical "   $plan_id"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "DELETING backup plan: $plan_id"
                    aws backup delete-backup-plan --region $region --backup-plan-id "$plan_id" 2>/dev/null || log_error "Failed to delete backup plan $plan_id"
                fi
            fi
        done
        found_any=true
    fi
    
    if [ "$found_any" = false ]; then
        log_success " No backup resources in $region"
        return 0
    else
        return 1
    fi
}

# Function to check Internet Gateways
check_internet_gateways() {
    local region=$1
    log " Checking Internet Gateways in $region..."
    
    local igws=$(aws ec2 describe-internet-gateways --region $region --query 'InternetGateways[?Attachments[0].State==`available`].[InternetGatewayId,Tags[?Key==`Name`].Value|[0]]' --output text 2>/dev/null || echo "")
    
    if [ -n "$igws" ] && [ "$igws" != "None" ]; then
        log_critical " INTERNET GATEWAYS FOUND in $region:"
        echo "$igws" | while read -r igw_id name; do
            if [ -n "$igw_id" ] && [ "$igw_id" != "None" ]; then
                log_critical "   $igw_id | $name"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    # Detach from VPC first
                    local vpc_id=$(aws ec2 describe-internet-gateways --region $region --internet-gateway-ids "$igw_id" --query 'InternetGateways[0].Attachments[0].VpcId' --output text 2>/dev/null)
                    if [ -n "$vpc_id" ] && [ "$vpc_id" != "None" ]; then
                        log_critical "Detaching IGW $igw_id from VPC $vpc_id"
                        aws ec2 detach-internet-gateway --region $region --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" 2>/dev/null
                    fi
                    log_critical "DELETING Internet Gateway: $igw_id"
                    aws ec2 delete-internet-gateway --region $region --internet-gateway-id "$igw_id" 2>/dev/null || log_error "Failed to delete IGW $igw_id"
                fi
            fi
        done
        return 1
    else
        log_success " No Internet Gateways in $region"
        return 0
    fi
}

# Function to check Route Tables
check_route_tables() {
    local region=$1
    log " Checking Route Tables in $region..."
    
    local route_tables=$(aws ec2 describe-route-tables --region $region --query 'RouteTables[?Associations[0].Main==`false`].[RouteTableId,Tags[?Key==`Name`].Value|[0]]' --output text 2>/dev/null || echo "")
    
    if [ -n "$route_tables" ] && [ "$route_tables" != "None" ]; then
        log_warning "  Custom Route Tables found in $region:"
        echo "$route_tables" | while read -r rt_id name; do
            if [ -n "$rt_id" ] && [ "$rt_id" != "None" ]; then
                log_warning "   $rt_id | $name"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "DELETING Route Table: $rt_id"
                    # Disassociate subnets first
                    aws ec2 describe-route-tables --region $region --route-table-ids "$rt_id" --query 'RouteTables[0].Associations[].RouteTableAssociationId' --output text 2>/dev/null | while read -r assoc_id; do
                        if [ -n "$assoc_id" ] && [[ "$assoc_id" != rtbassoc-* ]]; then
                            aws ec2 disassociate-route-table --region $region --association-id "$assoc_id" 2>/dev/null
                        fi
                    done
                    aws ec2 delete-route-table --region $region --route-table-id "$rt_id" 2>/dev/null || log_error "Failed to delete route table $rt_id"
                fi
            fi
        done
        return 1
    else
        log_success " No custom Route Tables in $region"
        return 0
    fi
}

# Function to check Subnets
check_subnets() {
    local region=$1
    log " Checking Subnets in $region..."
    
    local subnets=$(aws ec2 describe-subnets --region $region --query 'Subnets[].[SubnetId,Tags[?Key==`Name`].Value|[0],AvailabilityZone]' --output text 2>/dev/null || echo "")
    
    if [ -n "$subnets" ] && [ "$subnets" != "None" ]; then
        log_warning "  Subnets found in $region:"
        echo "$subnets" | while read -r subnet_id name az; do
            if [ -n "$subnet_id" ] && [ "$subnet_id" != "None" ]; then
                log_warning "   $subnet_id | $name | $az"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "DELETING Subnet: $subnet_id"
                    aws ec2 delete-subnet --region $region --subnet-id "$subnet_id" 2>/dev/null || log_error "Failed to delete subnet $subnet_id"
                fi
            fi
        done
        return 1
    else
        log_success " No Subnets in $region"
        return 0
    fi
}

# Function to check VPCs
check_vpcs() {
    local region=$1
    log " Checking VPCs in $region..."
    
    local vpcs=$(aws ec2 describe-vpcs --region $region --query 'Vpcs[?!IsDefault].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock]' --output text 2>/dev/null || echo "")
    
    if [ -n "$vpcs" ] && [ "$vpcs" != "None" ]; then
        log_critical " CUSTOM VPCs FOUND in $region:"
        echo "$vpcs" | while read -r vpc_id name cidr; do
            if [ -n "$vpc_id" ] && [ "$vpc_id" != "None" ]; then
                log_critical "   $vpc_id | $name | $cidr"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "DELETING VPC dependencies for: $vpc_id"
                    # Delete all dependencies first (done by other functions)
                    # This will be called last
                    log_critical "DELETING VPC: $vpc_id"
                    aws ec2 delete-vpc --region $region --vpc-id "$vpc_id" 2>/dev/null || log_error "Failed to delete VPC $vpc_id (may have dependencies)"
                fi
            fi
        done
        return 1
    else
        log_success " No custom VPCs in $region"
        return 0
    fi
}

# Function to check EBS Volumes
check_ebs_volumes() {
    local region=$1
    log " Checking EBS Volumes in $region..."
    
    local volumes=$(aws ec2 describe-volumes --region $region --query 'Volumes[].[VolumeId,State,Size,Tags[?Key==`Name`].Value|[0]]' --output text 2>/dev/null || echo "")
    
    if [ -n "$volumes" ] && [ "$volumes" != "None" ]; then
        log_warning "  EBS Volumes found in $region:"
        echo "$volumes" | while read -r volume_id state size name; do
            if [ -n "$volume_id" ] && [ "$volume_id" != "None" ]; then
                log_warning "   $volume_id | $state | ${size}GB | $name"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "DELETING EBS Volume: $volume_id"
                    aws ec2 delete-volume --region $region --volume-id "$volume_id" 2>/dev/null || log_error "Failed to delete volume $volume_id (may be attached)"
                fi
            fi
        done
        return 1
    else
        log_success " No EBS Volumes in $region"
        return 0
    fi
}

# Function to check EBS Snapshots
check_ebs_snapshots() {
    local region=$1
    log " Checking EBS Snapshots in $region..."
    
    local snapshots=$(aws ec2 describe-snapshots --region $region --owner-ids self --query 'Snapshots[].[SnapshotId,State,VolumeSize]' --output text 2>/dev/null || echo "")
    
    if [ -n "$snapshots" ] && [ "$snapshots" != "None" ]; then
        log_warning "  EBS Snapshots found in $region:"
        echo "$snapshots" | while read -r snapshot_id state size; do
            if [ -n "$snapshot_id" ] && [ "$snapshot_id" != "None" ]; then
                log_warning "   $snapshot_id | $state | ${size}GB"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "DELETING EBS Snapshot: $snapshot_id"
                    aws ec2 delete-snapshot --region $region --snapshot-id "$snapshot_id" 2>/dev/null || log_error "Failed to delete snapshot $snapshot_id"
                fi
            fi
        done
        return 1
    else
        log_success " No EBS Snapshots in $region"
        return 0
    fi
}

# Function to check Elastic IPs
check_elastic_ips() {
    local region=$1
    log " Checking Elastic IPs in $region..."
    
    local eips=$(aws ec2 describe-addresses --region $region --query 'Addresses[].[AllocationId,PublicIp]' --output text 2>/dev/null || echo "")
    
    if [ -n "$eips" ] && [ "$eips" != "None" ]; then
        log_critical " ELASTIC IPs FOUND in $region:"
        echo "$eips" | while read -r allocation_id public_ip; do
            if [ -n "$allocation_id" ] && [ "$allocation_id" != "None" ]; then
                log_critical "   $allocation_id | $public_ip"
                
                if [ "$DELETE_MODE" = "nuke" ]; then
                    log_critical "RELEASING Elastic IP: $allocation_id"
                    aws ec2 release-address --region $region --allocation-id "$allocation_id" 2>/dev/null || log_error "Failed to release EIP $allocation_id"
                fi
            fi
        done
        return 1
    else
        log_success " No Elastic IPs in $region"
        return 0
    fi
}

# Function to check a specific region
check_region() {
    local region=$1
    local total_issues=0
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN} DEEP PROBING REGION: $region${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    # CRITICAL: Check for expensive instances first (like the c7i.8xlarge we found)
    check_expensive_instances $region || ((total_issues++))
    
    # High-cost services
    check_ec2_instances $region || ((total_issues++))
    check_eks_clusters $region || ((total_issues++))
    check_rds_instances $region || ((total_issues++))
    check_redshift_clusters $region || ((total_issues++))
    check_elasticache_clusters $region || ((total_issues++))
    check_opensearch_domains $region || ((total_issues++))
    check_sagemaker_resources $region || ((total_issues++))
    check_efs_filesystems $region || ((total_issues++))
    check_load_balancers $region || ((total_issues++))
    check_nat_gateways $region || ((total_issues++))
    
    # Medium-cost services
    check_lambda_functions $region || ((total_issues++))
    check_ecs_services $region || ((total_issues++))
    check_s3_buckets $region || ((total_issues++))
    check_dynamodb_tables $region || ((total_issues++))
    
    # COMPREHENSIVE: Check for hidden Kubernetes/container resources
    check_hidden_kubernetes_resources $region || ((total_issues++))
    
    # COMPREHENSIVE: Check for EKS billing remnants
    check_eks_billing_remnants $region || ((total_issues++))
    
    # NEW: Additional infrastructure components
    check_ecr_repositories $region || ((total_issues++))
    check_backup_resources $region || ((total_issues++))
    check_elastic_ips $region || ((total_issues++))
    check_ebs_volumes $region || ((total_issues++))
    check_ebs_snapshots $region || ((total_issues++))
    
    # NEW: Network infrastructure (delete in reverse dependency order)
    if [ "$DELETE_MODE" = "nuke" ]; then
        # Delete in correct order for VPC cleanup
        check_internet_gateways $region || ((total_issues++))
        check_nat_gateways $region || ((total_issues++))  # Already checked above, but important for order
        check_route_tables $region || ((total_issues++))
        check_subnets $region || ((total_issues++))
        check_vpcs $region || ((total_issues++))  # Must be last
    else
        check_internet_gateways $region || ((total_issues++))
        check_route_tables $region || ((total_issues++))
        check_subnets $region || ((total_issues++))
        check_vpcs $region || ((total_issues++))
    fi
    
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    if [ $total_issues -eq 0 ]; then
        log_success " Region $region is CLEAN - No cost-incurring resources found!"
    else
        log_critical " Region $region has $total_issues types of resources that may incur costs!"
    fi
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    return $total_issues
}

# Main function
main() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║              AWS RESOURCE DEEP PROBE & NUKE SCRIPT                      ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║  MODE: ${DELETE_MODE}                                                        ║"
    echo "║  This script will scan ALL AWS regions for cost-incurring resources         ║"
    if [ "$DELETE_MODE" = "nuke" ]; then
    echo "║   NUKE MODE ENABLED - ALL RESOURCES WILL BE DELETED!                    ║"
    fi
    echo "║                                                                              ║"
    echo "║   HIGH PRIORITY (High Cost):                                              ║"
    echo "║     • EC2 Instances        • EKS Clusters        • RDS Instances            ║"
    echo "║     • Redshift Clusters    • ElastiCache        • OpenSearch Domains       ║"
    echo "║     • SageMaker Resources  • EFS File Systems   • Load Balancers           ║"
    echo "║     • NAT Gateways         • EXPENSIVE INSTANCES (>$1/hour)               ║"
    echo "║                                                                              ║"
    echo "║    MEDIUM PRIORITY (Medium Cost):                                         ║"
    echo "║     • Lambda Functions     • ECS Services       • S3 Buckets               ║"
    echo "║     • DynamoDB Tables      • CloudFront         • Route 53                 ║"
    echo "║     • Fargate Tasks        • ECS Clusters       • ECR Repositories         ║"
    echo "║                                                                              ║"
    echo "║   COMPREHENSIVE DEEP PROBE (Hidden Billing Sources):                     ║"
    echo "║     • Hidden K8s Resources • EKS Billing Remnants • CloudWatch Logs        ║"
    echo "║     • K8s-related ASGs     • K8s-related LBs     • K8s-related VPCs        ║"
    echo "║     • EKS Service Roles    • Network Interfaces  • CloudFormation Stacks   ║"
    echo "║                                                                              ║"
    echo "║   NEW COVERAGE (realistic-demo-pretamane architecture):                  ║"
    echo "║     • ECR Repositories     • Backup Vaults/Plans • Elastic IPs             ║"
    echo "║     • EBS Volumes/Snapshots• Internet Gateways   • Route Tables            ║"
    echo "║     • Subnets              • Custom VPCs         • IAM Policies/Roles      ║"
    echo "║                                                                              ║"
    echo "║  ℹ️  LOW PRIORITY (Low Cost):                                               ║"
    echo "║     • IAM Resources        • Security Groups     • Other Services           ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [ "$DELETE_MODE" = "nuke" ]; then
        echo ""
        echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                            DANGER ZONE                                   ║${NC}"
        echo -e "${RED}║                                                                              ║${NC}"
        echo -e "${RED}║  You are about to DELETE ALL AWS resources across ALL regions!              ║${NC}"
        echo -e "${RED}║  This action is IRREVERSIBLE and will:                                      ║${NC}"
        echo -e "${RED}║    1. Delete ALL EC2 instances, EKS clusters, databases                      ║${NC}"
        echo -e "${RED}║    2. Delete ALL S3 buckets and their contents                              ║${NC}"
        echo -e "${RED}║    3. Delete ALL Lambda functions, DynamoDB tables                          ║${NC}"
        echo -e "${RED}║    4. Delete ALL VPCs, subnets, and networking components                   ║${NC}"
        echo -e "${RED}║    5. Delete ALL IAM roles, policies, and ECR repositories                  ║${NC}"
        echo -e "${RED}║                                                                              ║${NC}"
        echo -e "${RED}║  Type 'NUKE' to confirm, or anything else to cancel:                        ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -r confirmation
        
        if [ "$confirmation" != "NUKE" ]; then
            echo ""
            log_warning "Deletion cancelled by user. Switching to scan mode."
            DELETE_MODE="scan"
        else
            echo ""
            log_critical " NUKE MODE CONFIRMED - Starting deletion in 10 seconds..."
            log_critical "Press Ctrl+C now to abort!"
            for i in {10..1}; do
                echo -ne "\r${RED}Deletion starting in $i seconds...${NC}"
                sleep 1
            done
            echo ""
            log_critical " BEGINNING TOTAL AWS RESOURCE DELETION "
            echo ""
        fi
    fi
    
    log " Starting comprehensive AWS resource scan..."
    
    # Get AWS account info
    local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
    log " AWS Account ID: $account_id"
    
    # Check global services first
    log " Checking global services..."
    local global_issues=0
    check_cloudfront_distributions || ((global_issues++))
    check_route53_zones || ((global_issues++))
    check_iam_resources || ((global_issues++))
    
    # Get all enabled regions
    local regions=$(get_enabled_regions)
    local total_regions=$(echo "$regions" | wc -l)
    local total_issues=0
    local regions_with_issues=0
    
    log " Found $total_regions enabled regions to scan"
    
    # Check each region
    echo "$regions" | while read -r region; do
        if [ -n "$region" ]; then
            check_region "$region"
            if [ $? -gt 0 ]; then
                ((regions_with_issues++))
                ((total_issues += $?))
            fi
        fi
    done
    
    # Final summary
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                             SCAN SUMMARY                                 ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║  Total Regions Scanned: $total_regions${NC}"
    echo -e "${PURPLE}║  Regions with Issues: $regions_with_issues${NC}"
    echo -e "${PURPLE}║  Total Resource Types with Issues: $total_issues${NC}"
    echo -e "${PURPLE}║                                                                              ║${NC}"
    
    if [ $total_issues -eq 0 ]; then
        echo -e "${PURPLE}║   RESULT: Your AWS account is CLEAN! No cost-incurring resources found! ║${NC}"
        log_success " Your AWS credits are safe! No resources found that could incur charges."
    else
        echo -e "${PURPLE}║   RESULT: Found resources that may incur costs! Review the output above. ║${NC}"
        log_critical " Found $total_issues types of resources that may incur costs!"
        log_critical " Review the output above and consider deleting unused resources."
    fi
    
    echo -e "${PURPLE}║                                                                              ║${NC}"
    echo -e "${PURPLE}║   TIP: Run this script regularly to catch unexpected charges early!        ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    # Cost optimization recommendations
    echo ""
    log_info " Cost Optimization Recommendations:"
    log_info "   • Set up AWS Budgets with alerts"
    log_info "   • Enable AWS Cost Explorer for detailed analysis"
    log_info "   • Use AWS Trusted Advisor for cost optimization suggestions"
    log_info "   • Consider using AWS Free Tier eligible services"
    log_info "   • Implement automated cleanup scripts for temporary resources"
    
    echo ""
    log " Deep probe scan completed!"
    
    if [ $total_issues -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Show usage if requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "AWS Resource Deep Probe & Nuke Script"
    echo ""
    echo "Usage:"
    echo "  $0                # Scan mode - only check for resources"
    echo "  $0 scan           # Scan mode - only check for resources"
    echo "  $0 nuke           # NUKE mode - DELETE ALL resources (requires confirmation)"
    echo ""
    echo "Examples:"
    echo "  $0                # Safe scan of all resources"
    echo "  $0 nuke           # Delete everything (will ask for confirmation)"
    echo ""
    exit 0
fi

# Run main function
main "$@"
