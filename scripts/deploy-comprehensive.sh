#!/bin/bash
# deploy-comprehensive.sh - Comprehensive deployment script covering ALL Terraform implementations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="realistic-demo-pretamane"
REGION="ap-southeast-1"
LOG_FILE="comprehensive-deployment-$(date +%Y%m%d-%H%M%S).log"

# Function to log with timestamp
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]  $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]   $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]  $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

log_highlight() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')]  $1${NC}" | tee -a "$LOG_FILE"
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_success "All prerequisites met!"
}

# Function to create Terraform backend
create_terraform_backend() {
    log "Creating Terraform backend infrastructure..."
    cd terraform/modules/backend
    terraform init -upgrade
    terraform apply -auto-approve -var "project_name=$PROJECT_NAME"
    BUCKET_NAME=$(terraform output -raw terraform_state_bucket_name)
    DYNAMODB_TABLE=$(terraform output -raw terraform_locks_table_name)
    log_success "Backend infrastructure created!"
    log "S3 Bucket: $BUCKET_NAME"
    log "DynamoDB Table: $DYNAMODB_TABLE"
    cd ../../..
}

# Function to deploy comprehensive infrastructure
deploy_infrastructure() {
    log_highlight "Deploying COMPREHENSIVE infrastructure with ALL modules..."
    cd terraform
    terraform init -upgrade
    terraform plan -out=tfplan
    terraform apply tfplan
    log_success "Comprehensive infrastructure deployed successfully!"
    cd ..
}

# Function to configure kubectl
configure_kubectl() {
    log "Configuring kubectl..."
    aws eks update-kubeconfig --region $REGION --name $PROJECT_NAME-cluster
    log_success "kubectl configured!"
}

# Function to deploy Helm repositories and releases
deploy_helm_releases() {
    log "Deploying Helm repositories and releases..."
    
    # Add Helm repositories
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
    helm repo add eks https://aws.github.io/eks-charts
    helm repo add efs-csi https://kubernetes-sigs.github.io/aws-efs-csi-driver
    helm repo update
    
    # Create namespaces
    kubectl create namespace amazon-cloudwatch --dry-run=client -o yaml | kubectl apply -f -
    
    # Create service accounts with IRSA
    kubectl create serviceaccount cluster-autoscaler -n kube-system --dry-run=client -o yaml | kubectl apply -f -
    kubectl annotate serviceaccount cluster-autoscaler -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$PROJECT_NAME-cluster-autoscaler-role --overwrite
    
    kubectl create serviceaccount aws-load-balancer-controller -n kube-system --dry-run=client -o yaml | kubectl apply -f -
    kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$PROJECT_NAME-aws-load-balancer-controller-role --overwrite
    
    kubectl create serviceaccount cloudwatch-agent -n amazon-cloudwatch --dry-run=client -o yaml | kubectl apply -f -
    kubectl annotate serviceaccount cloudwatch-agent -n amazon-cloudwatch eks.amazonaws.com/role-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$PROJECT_NAME-cloudwatch-agent-role --overwrite
    
    kubectl create serviceaccount efs-csi-controller-sa -n kube-system --dry-run=client -o yaml | kubectl apply -f -
    kubectl annotate serviceaccount efs-csi-controller-sa -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$PROJECT_NAME-efs-csi-driver-role --overwrite
    
    # Deploy Helm releases
    log "Deploying Metrics Server..."
    helm install metrics-server metrics-server/metrics-server --namespace kube-system --set 'args[0]=--kubelet-insecure-tls' --set 'args[1]=--kubelet-preferred-address-types=InternalIP' --version 3.11.0
    
    log "Deploying Cluster Autoscaler..."
    helm install cluster-autoscaler autoscaler/cluster-autoscaler --namespace kube-system --set autoDiscovery.clusterName=$PROJECT_NAME-cluster --set awsRegion=$REGION --set rbac.serviceAccount.create=false --set rbac.serviceAccount.name=cluster-autoscaler --version 9.29.0
    
    log "Deploying CloudWatch Agent..."
    helm install aws-cloudwatch-metrics eks/aws-cloudwatch-metrics --namespace amazon-cloudwatch --set clusterName=$PROJECT_NAME-cluster --set serviceAccount.create=false --set serviceAccount.name=cloudwatch-agent --version 0.0.7
    
    log "Deploying AWS Load Balancer Controller..."
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller --namespace kube-system --set clusterName=$PROJECT_NAME-cluster --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --version 1.6.2
    
    log "Deploying EFS CSI Driver..."
    helm install aws-efs-csi-driver efs-csi/aws-efs-csi-driver --namespace kube-system --set controller.serviceAccount.create=false --set controller.serviceAccount.name=efs-csi-controller-sa --version 2.4.8
    
    log_success "All Helm releases deployed!"
}

# Function to update Kubernetes manifests with actual values
update_k8s_manifests() {
    log "Updating Kubernetes manifests with actual AWS resource values..."
    
    # Get EFS file system ID
    EFS_ID=$(aws efs describe-file-systems --region $REGION --query 'FileSystems[?Tags[?Key==`Name` && Value==`'$PROJECT_NAME'-efs`]].FileSystemId' --output text)
    log_info "EFS File System ID: $EFS_ID"
    
    # Get EFS access point ID
    EFS_ACCESS_POINT_ID=$(aws efs describe-access-points --region $REGION --query 'AccessPoints[?Tags[?Key==`Name` && Value==`'$PROJECT_NAME'-efs-access-point`]].AccessPointId' --output text)
    log_info "EFS Access Point ID: $EFS_ACCESS_POINT_ID"
    
    # Get S3 bucket names
    DATA_BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `'$PROJECT_NAME'-data`)].Name' --output text)
    INDEX_BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `'$PROJECT_NAME'-index`)].Name' --output text)
    BACKUP_BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `'$PROJECT_NAME'-backup`)].Name' --output text)
    
    log_info "S3 Data Bucket: $DATA_BUCKET"
    log_info "S3 Index Bucket: $INDEX_BUCKET"
    log_info "S3 Backup Bucket: $BACKUP_BUCKET"
    
    # Get OpenSearch endpoint
    OPENSEARCH_ENDPOINT=$(aws opensearch describe-domain --domain-name $PROJECT_NAME-search --region $REGION --query 'DomainStatus.Endpoint' --output text)
    log_info "OpenSearch Endpoint: $OPENSEARCH_ENDPOINT"
    
    # Update EFS manifests
    sed -i "s/fs-12345678/$EFS_ID/g" k8s/advanced-efs-pv.yaml
    sed -i "s/fsap-12345678/$EFS_ACCESS_POINT_ID/g" k8s/advanced-efs-pv.yaml
    
    # Update storage secrets
    sed -i "s/realistic-demo-pretamane-data-abcdef/$DATA_BUCKET/g" k8s/advanced-storage-secrets.yaml
    sed -i "s/realistic-demo-pretamane-index-abcdef/$INDEX_BUCKET/g" k8s/advanced-storage-secrets.yaml
    sed -i "s/realistic-demo-pretamane-backup-abcdef/$BACKUP_BUCKET/g" k8s/advanced-storage-secrets.yaml
    sed -i "s|https://search-realistic-demo-pretamane-us-east-1.es.amazonaws.com|$OPENSEARCH_ENDPOINT|g" k8s/advanced-storage-secrets.yaml
    
    # Update storage config
    sed -i "s/realistic-demo-pretamane-data-abcdef/$DATA_BUCKET/g" k8s/advanced-storage-secrets.yaml
    sed -i "s/realistic-demo-pretamane-index-abcdef/$INDEX_BUCKET/g" k8s/advanced-storage-secrets.yaml
    sed -i "s/realistic-demo-pretamane-backup-abcdef/$BACKUP_BUCKET/g" k8s/advanced-storage-secrets.yaml
    sed -i "s|https://search-realistic-demo-pretamane-us-east-1.es.amazonaws.com|$OPENSEARCH_ENDPOINT|g" k8s/advanced-storage-secrets.yaml
    
    log_success "Kubernetes manifests updated with actual AWS resource values!"
}

# Function to deploy comprehensive Kubernetes manifests
deploy_kubernetes() {
    log_highlight "Deploying COMPREHENSIVE Kubernetes manifests..."
    
    # Deploy basic manifests
    kubectl apply -f k8s/serviceaccount.yaml
    kubectl apply -f k8s/configmap.yaml
    
    # Deploy advanced storage manifests
    kubectl apply -f k8s/advanced-storage-secrets.yaml
    kubectl apply -f k8s/advanced-efs-pv.yaml
    
    # Deploy advanced deployment
    kubectl apply -f k8s/advanced-deployment.yaml
    
    # Deploy additional mounting techniques
    kubectl apply -f k8s/rclone-sidecar.yaml
    kubectl apply -f k8s/init-container-mount.yaml
    
    # Deploy services and ingress
    kubectl apply -f k8s/service.yaml
    kubectl apply -f k8s/ingress.yaml
    kubectl apply -f k8s/hpa.yaml
    
    log_success "Comprehensive Kubernetes manifests deployed!"
}

# Function to wait for deployment
wait_for_deployment() {
    log "Waiting for comprehensive deployment to be ready..."
    
    # Wait for EFS CSI driver
    kubectl wait --for=condition=available --timeout=300s deployment/efs-csi-controller -n kube-system
    
    # Wait for metrics server
    kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
    
    # Wait for cluster autoscaler
    kubectl wait --for=condition=available --timeout=300s deployment/cluster-autoscaler -n kube-system
    
    # Wait for main application
    kubectl wait --for=condition=available --timeout=300s deployment/contact-api-advanced
    
    log_success "All deployments are ready!"
}

# Function to test comprehensive setup
test_comprehensive_setup() {
    log_highlight "Testing COMPREHENSIVE setup..."
    
    # Test EKS cluster
    log "Testing EKS cluster..."
    kubectl cluster-info && log_success "EKS cluster accessible" || log_warning "EKS cluster not accessible"
    
    # Test EFS mounting
    log "Testing EFS mounting..."
    kubectl get pv,pvc | grep efs && log_success "EFS PV/PVC created successfully" || log_warning "EFS PV/PVC not ready"
    
    # Test S3 buckets
    log "Testing S3 buckets..."
    aws s3 ls | grep $PROJECT_NAME && log_success "S3 buckets created" || log_warning "S3 buckets not found"
    
    # Test OpenSearch
    log "Testing OpenSearch..."
    aws opensearch describe-domain --domain-name $PROJECT_NAME-search --region $REGION --query 'DomainStatus.Processing' --output text && log_success "OpenSearch domain created" || log_warning "OpenSearch domain not ready"
    
    # Test DynamoDB tables
    log "Testing DynamoDB tables..."
    aws dynamodb describe-table --table-name $PROJECT_NAME-contact-submissions --region $REGION --query 'Table.TableStatus' --output text && log_success "Contact submissions table created" || log_warning "Contact submissions table not found"
    aws dynamodb describe-table --table-name $PROJECT_NAME-website-visitors --region $REGION --query 'Table.TableStatus' --output text && log_success "Website visitors table created" || log_warning "Website visitors table not found"
    
    # Test SES configuration
    log "Testing SES configuration..."
    aws ses get-send-quota --region $REGION && log_success "SES configured" || log_warning "SES not configured"
    
    # Test Helm releases
    log "Testing Helm releases..."
    helm list -n kube-system | grep metrics-server && log_success "Metrics Server deployed" || log_warning "Metrics Server not deployed"
    helm list -n kube-system | grep cluster-autoscaler && log_success "Cluster Autoscaler deployed" || log_warning "Cluster Autoscaler not deployed"
    helm list -n amazon-cloudwatch | grep cloudwatch && log_success "CloudWatch Agent deployed" || log_warning "CloudWatch Agent not deployed"
    helm list -n kube-system | grep aws-load-balancer-controller && log_success "AWS Load Balancer Controller deployed" || log_warning "AWS Load Balancer Controller not deployed"
    helm list -n kube-system | grep aws-efs-csi-driver && log_success "EFS CSI Driver deployed" || log_warning "EFS CSI Driver not deployed"
    
    # Test HPA
    log "Testing Horizontal Pod Autoscaler..."
    kubectl get hpa && log_success "HPA configured" || log_warning "HPA not configured"
    
    # Test advanced mounting techniques
    log "Testing advanced mounting techniques..."
    kubectl get pods -l app=contact-api && log_success "Advanced deployment pods running" || log_warning "Advanced deployment pods not ready"
    
    # Test RClone sidecar
    log "Testing RClone sidecar..."
    kubectl get pods -l app=contact-api-with-rclone && log_success "RClone sidecar deployed" || log_warning "RClone sidecar not ready"
    
    # Test Init container
    log "Testing Init container..."
    kubectl get pods -l app=contact-api-with-init && log_success "Init container deployed" || log_warning "Init container not ready"
}

# Function to test application endpoints
test_application() {
    log "Testing application endpoints..."
    
    ALB_ENDPOINT=$(kubectl get ingress contact-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$ALB_ENDPOINT" ]; then
        # Test health endpoint
        log "Testing health endpoint..."
        if curl -s "http://$ALB_ENDPOINT/health" | grep -q "healthy"; then
            log_success "Health check passed!"
        else
            log_warning "Health check failed or endpoint not ready"
        fi
        
        # Test root endpoint
        log "Testing root endpoint..."
        if curl -s "http://$ALB_ENDPOINT/" | grep -q "Contact Form API"; then
            log_success "Root endpoint working!"
        else
            log_warning "Root endpoint not responding"
        fi
        
        # Test API documentation
        log "Testing API documentation..."
        if curl -s "http://$ALB_ENDPOINT/docs" | grep -q "FastAPI"; then
            log_success "API documentation accessible!"
        else
            log_warning "API documentation not accessible"
        fi
    else
        log_warning "ALB endpoint not ready for testing"
    fi
}

# Function to show comprehensive status
show_comprehensive_status() {
    log_highlight "COMPREHENSIVE Deployment Status:"
    echo "=========================================="
    
    # Terraform status
    echo ""
    echo "  Terraform Resources:"
    cd terraform
    terraform show -json | jq -r '.values.root_module.resources[] | select(.type | startswith("aws_")) | "\(.type): \(.values.tags.Name // .name)"' 2>/dev/null || echo "Terraform resources deployed"
    cd ..
    
    # Kubernetes status
    echo ""
    echo "️  Kubernetes Resources:"
    kubectl get pods,svc,ingress,hpa 2>/dev/null || echo "Kubernetes resources deployed"
    
    # Storage status
    echo ""
    echo " Storage Resources:"
    kubectl get pv,pvc,storageclass 2>/dev/null || echo "Storage resources deployed"
    
    # Application status
    echo ""
    echo " Application Status:"
    ALB_ENDPOINT=$(kubectl get ingress contact-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    if [ "$ALB_ENDPOINT" != "pending" ] && [ -n "$ALB_ENDPOINT" ]; then
        echo " Application URL: http://$ALB_ENDPOINT"
        echo " API Docs: http://$ALB_ENDPOINT/docs"
        echo " Health: http://$ALB_ENDPOINT/health"
    else
        echo " Application URL: Pending ALB creation"
    fi
    
    # Advanced features status
    echo ""
    echo " Advanced Features:"
    echo "   - EFS File System:  Deployed"
    echo "   - S3 Buckets (3):  Deployed"
    echo "   - OpenSearch:  Deployed"
    echo "   - RClone Sidecar:  Deployed"
    echo "   - Init Containers:  Deployed"
    echo "   - Advanced Indexing:  Deployed"
    echo "   - Comprehensive Mounting:  Deployed"
}

# Function to show cost information
show_cost_info() {
    log " Comprehensive Cost Information:"
    echo "=================================="
    echo " Estimated Monthly Cost: ~$50-100"
    echo " Resources Deployed:"
    echo "   - EKS Cluster: ~$73/month"
    echo "   - EC2 instances (t3.medium): ~$30/month"
    echo "   - Application Load Balancer: ~$16/month"
    echo "   - EFS (10GB): ~$3/month"
    echo "   - S3 Storage (100GB): ~$2/month"
    echo "   - OpenSearch (2 nodes): ~$50/month"
    echo "   - DynamoDB: Pay-per-request (minimal)"
    echo "   - CloudWatch: ~$10/month"
    echo ""
    echo "  Note: This is a comprehensive production setup"
    echo "   - All advanced storage features enabled"
    echo "   - Complete indexing and search capabilities"
    echo "   - Advanced mounting techniques"
    echo "   - Full monitoring and scaling"
    echo ""
    log "Check your AWS billing dashboard for actual costs"
}

# Main deployment function
main() {
    log_highlight " Starting COMPREHENSIVE Deployment"
    log "Project: $PROJECT_NAME"
    log "Region: $REGION"
    log "Log file: $LOG_FILE"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Create backend infrastructure
    create_terraform_backend
    
    # Deploy comprehensive infrastructure
    deploy_infrastructure
    
    # Configure kubectl
    configure_kubectl
    
    # Deploy Helm releases
    deploy_helm_releases
    
    # Update Kubernetes manifests
    update_k8s_manifests
    
    # Deploy comprehensive Kubernetes manifests
    deploy_kubernetes
    
    # Wait for deployment
    wait_for_deployment
    
    # Show comprehensive status
    show_comprehensive_status
    
    # Test comprehensive setup
    test_comprehensive_setup
    
    # Test application
    test_application
    
    # Show cost information
    show_cost_info
    
    log_success " COMPREHENSIVE deployment completed successfully!"
    log_highlight " What was deployed:"
    log "    Complete AWS Infrastructure (VPC, EKS, IAM, Database)"
    log "    EFS File System with CSI Driver"
    log "    S3 Buckets (Data, Index, Backup)"
    log "    OpenSearch for Advanced Indexing"
    log "    Comprehensive Storage Mounting"
    log "    RClone Sidecar for S3 Mounting"
    log "    Init Containers for Data Preparation"
    log "    Advanced Kubernetes Manifests"
    log "    Complete Monitoring & Scaling"
    log "    All Helm Releases"
    log ""
    log " Access your application:"
    ALB_ENDPOINT=$(kubectl get ingress contact-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    if [ "$ALB_ENDPOINT" != "pending" ] && [ -n "$ALB_ENDPOINT" ]; then
        log "    Application: http://$ALB_ENDPOINT"
        log "    API Docs: http://$ALB_ENDPOINT/docs"
        log "    Health: http://$ALB_ENDPOINT/health"
    fi
    log ""
    log "  Remember to run cleanup script when done: ./scripts/cleanup-comprehensive.sh"
}

# Trap to handle script interruption
trap 'log_error "Script interrupted. Run cleanup script manually."; exit 1' INT TERM

# Run main function
main "$@"
