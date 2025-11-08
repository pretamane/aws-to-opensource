#  AWS Deployment Guide with Automatic Cleanup

This guide will help you deploy your EKS infrastructure to AWS for testing with automatic cleanup after 1 hour to prevent burning your AWS credits.

##  Important: Cost Management

**Estimated Cost**: ~$0.15/hour
- EKS Cluster: $0.10/hour
- EC2 instances (t3.small SPOT): $0.02/hour
- Application Load Balancer: $0.02/hour
- DynamoDB: Pay-per-request (minimal)
- CloudWatch: Minimal cost

**Total for 1 hour**: ~$0.15
**Total for 2 hours**: ~$0.30

##  Quick Start

### 1. Prerequisites Check
```bash
# Check if you have the required tools
aws --version
terraform --version
kubectl version --client
```

### 2. Deploy with Automatic Cleanup
```bash
# Run the deployment script (includes 1-hour auto-cleanup)
./deploy-with-cleanup.sh
```

### 3. Monitor Your Deployment
```bash
# Check deployment status
kubectl get pods,svc,ingress,hpa

# Monitor costs
./monitor-costs.sh

# Test your application
curl http://YOUR_ALB_ENDPOINT/health
```

### 4. Clean Up (if needed before 1 hour)
```bash
# Immediate cleanup
./cleanup-now.sh
```

##  What Gets Deployed

### Infrastructure (Terraform)
-  **EKS Cluster** (1.28) with OIDC provider
-  **VPC** with public subnets
-  **DynamoDB Tables** for contacts and visitors
-  **SES Configuration** for email notifications
-  **IAM Roles** with proper permissions
-  **S3 Bucket** for Terraform state
-  **DynamoDB Table** for state locking

### Application (Kubernetes)
-  **FastAPI Application** with contact form
-  **Service** (NodePort)
-  **Ingress** with ALB
-  **HPA** for auto-scaling (1-5 replicas)
-  **Service Account** with IRSA

### Monitoring & Scaling
-  **Metrics Server** for HPA
-  **Cluster Autoscaler** (1-3 nodes)
-  **CloudWatch Container Insights**
-  **AWS Load Balancer Controller**

##  Deployment Process

The deployment script will:

1. **Check Prerequisites** - AWS CLI, Terraform, kubectl
2. **Create Backend** - S3 bucket and DynamoDB for Terraform state
3. **Deploy Infrastructure** - EKS, VPC, DynamoDB, SES, IAM
4. **Deploy Application** - FastAPI app to EKS
5. **Setup Cleanup** - Automatic teardown after 1 hour
6. **Test Application** - Verify endpoints are working

##  Monitoring Your Deployment

### Check Application Status
```bash
# Get application URL
kubectl get ingress contact-api-ingress

# Test health endpoint
curl http://YOUR_ALB_ENDPOINT/health

# View API documentation
open http://YOUR_ALB_ENDPOINT/docs
```

### Monitor Resources
```bash
# Check pods
kubectl get pods

# Check services
kubectl get svc

# Check HPA
kubectl get hpa

# Check nodes
kubectl get nodes
```

### Monitor Costs
```bash
# Run cost monitor
./monitor-costs.sh

# Check AWS billing dashboard
# https://console.aws.amazon.com/billing/home#/costexplorer
```

##  Cleanup Options

### Automatic Cleanup (Recommended)
-  **Scheduled**: Runs automatically after 1 hour
-  **Complete**: Removes all resources
-  **Safe**: Prevents credit burning

### Manual Cleanup
```bash
# Immediate cleanup
./cleanup-now.sh

# Or cancel scheduled cleanup
kill $(cat cleanup.pid)
```

### What Gets Cleaned Up
-  Kubernetes resources (pods, services, ingress)
-  EKS cluster and node groups
-  EC2 instances
-  Application Load Balancer
-  DynamoDB tables
-  S3 buckets
-  IAM roles and policies

##  Troubleshooting

### Common Issues

#### 1. AWS Credentials Not Configured
```bash
aws configure
# Enter your Access Key ID, Secret Access Key, and region
```

#### 2. Terraform Backend Already Exists
```bash
# If S3 bucket already exists, you may need to:
cd terraform/modules/backend
terraform import aws_s3_bucket.terraform_state BUCKET_NAME
```

#### 3. EKS Cluster Not Ready
```bash
# Wait for cluster to be ready
kubectl wait --for=condition=ready node --all --timeout=300s
```

#### 4. ALB Not Created
```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Debug Commands
```bash
# Check Terraform state
cd terraform && terraform show

# Check Kubernetes resources
kubectl get all --all-namespaces

# Check AWS resources
aws eks list-clusters --region ap-southeast-1
aws ec2 describe-instances --region ap-southeast-1
```

##  Testing Your Application

### 1. Health Check
```bash
curl http://YOUR_ALB_ENDPOINT/health
```

### 2. API Documentation
```bash
# Open in browser
open http://YOUR_ALB_ENDPOINT/docs
```

### 3. Submit Contact Form
```bash
curl -X POST http://YOUR_ALB_ENDPOINT/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "This is a test message",
    "company": "Test Company",
    "service": "Web Development"
  }'
```

### 4. Check Statistics
```bash
curl http://YOUR_ALB_ENDPOINT/stats
```

##  Cost Optimization Tips

1. **Use SPOT Instances**  (Already configured)
2. **Pay-per-Request DynamoDB**  (Already configured)
3. **Automatic Cleanup**  (1-hour timer)
4. **Monitor Costs**  (Cost monitoring script)
5. **Set Billing Alerts** (In AWS Console)

##  Security Features

-  **IAM Roles** with least privilege
-  **IRSA** for secure service accounts
-  **VPC** with proper networking
-  **Encryption** at rest and in transit
-  **Input Validation** with Pydantic
-  **CORS** configuration

##  Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Cost Management](https://aws.amazon.com/aws-cost-management/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

##  Support

If you encounter issues:

1. Check the deployment logs
2. Run the troubleshooting commands
3. Check AWS CloudWatch logs
4. Verify all prerequisites are met
5. Ensure AWS credentials have sufficient permissions

##  Success!

Once deployed, you'll have:
-  Production-ready EKS cluster
-  Scalable FastAPI application
-  Comprehensive monitoring
-  Automatic cleanup protection
-  Cost-optimized infrastructure

**Remember**: Cleanup runs automatically after 1 hour to protect your AWS credits! 
