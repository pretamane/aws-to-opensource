# EKS Monitoring and Scaling Setup

This document describes the comprehensive monitoring and scaling setup for the EKS cluster.

##  Components Included

### 1. **Metrics Server**
- **Purpose**: Provides resource metrics (CPU, memory) for HPA
- **Deployment**: Via Helm chart `metrics-server`
- **Namespace**: `kube-system`
- **Version**: 3.11.0

### 2. **Horizontal Pod Autoscaler (HPA)**
- **Purpose**: Automatically scales pods based on CPU/memory usage
- **Configuration**: 
  - Min replicas: 1
  - Max replicas: 5
  - CPU target: 70%
  - Memory target: 80%
- **File**: `k8s/hpa.yaml`

### 3. **Cluster Autoscaler**
- **Purpose**: Automatically scales nodes based on pod scheduling needs
- **Configuration**:
  - Min nodes: 1
  - Max nodes: 3
  - Instance type: t3.small
- **IAM**: Dedicated IAM role with autoscaling permissions
- **Deployment**: Via Helm chart `cluster-autoscaler`

### 4. **CloudWatch Container Insights**
- **Purpose**: Comprehensive monitoring and logging
- **Features**:
  - Container metrics
  - Log aggregation
  - Performance insights
  - Cost monitoring
- **Namespace**: `amazon-cloudwatch`
- **IAM**: Dedicated IAM role with CloudWatch permissions

### 5. **AWS Load Balancer Controller**
- **Purpose**: Manages Application Load Balancers for ingress
- **Features**:
  - Automatic ALB creation
  - SSL termination
  - Path-based routing
- **IAM**: Dedicated IAM role with ELB permissions

##  IAM Roles and Permissions

### Service Accounts with IRSA (IAM Roles for Service Accounts):

1. **cluster-autoscaler** (kube-system)
   - Permissions: AutoScaling, EC2 operations
   - Role: `realistic-demo-pretamane-cluster-autoscaler-role`

2. **cloudwatch-agent** (amazon-cloudwatch)
   - Permissions: CloudWatch metrics and logs
   - Role: `realistic-demo-pretamane-cloudwatch-agent-role`

3. **aws-load-balancer-controller** (kube-system)
   - Permissions: ELB, EC2, ACM operations
   - Role: `realistic-demo-pretamane-aws-load-balancer-controller-role`

##  Monitoring Stack

### CloudWatch Container Insights
- **Metrics Collected**:
  - CPU and memory utilization
  - Network I/O
  - Storage I/O
  - Pod and container metrics
- **Logs**:
  - Application logs
  - System logs
  - Audit logs

### Custom Metrics
- Application-specific metrics can be sent to CloudWatch
- Prometheus-compatible metrics endpoint support

##  Scaling Behavior

### Pod Scaling (HPA)
- **Scale Up**: When CPU > 70% or Memory > 80%
- **Scale Down**: When resources are underutilized
- **Stabilization**: 60s for scale-up, 300s for scale-down

### Node Scaling (Cluster Autoscaler)
- **Scale Up**: When pods can't be scheduled
- **Scale Down**: When nodes are underutilized
- **Grace Period**: 10 minutes before terminating nodes

##  Deployment

### Prerequisites
1. Terraform applied successfully
2. AWS CLI configured
3. kubectl installed

### Deploy Everything
```bash
# Deploy infrastructure
cd terraform
terraform apply

# Deploy application and monitoring
cd ../k8s
./deploy.sh
```

### Manual Deployment Steps
```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-southeast-1 --name realistic-demo-pretamane-cluster

# Deploy application
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f hpa.yaml
```

##  Verification

### Check Components Status
```bash
# Check all pods
kubectl get pods -A

# Check HPA status
kubectl get hpa

# Check cluster autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Check metrics server
kubectl top nodes
kubectl top pods
```

### CloudWatch Dashboard
- Navigate to CloudWatch Console
- Go to Container Insights
- Select your cluster: `realistic-demo-pretamane-cluster`

##  Scaling Test

### Generate Load
```bash
# Install hey (load testing tool)
go install github.com/rakyll/hey@latest

# Get ALB endpoint
ALB_ENDPOINT=$(kubectl get ingress contact-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Generate load
hey -n 1000 -c 10 http://$ALB_ENDPOINT/health
```

### Monitor Scaling
```bash
# Watch HPA
kubectl get hpa -w

# Watch pods
kubectl get pods -w

# Watch nodes
kubectl get nodes -w
```

##  Troubleshooting

### Common Issues

1. **Metrics Server Not Ready**
   ```bash
   kubectl describe pod -n kube-system -l app.kubernetes.io/name=metrics-server
   ```

2. **HPA Not Scaling**
   ```bash
   kubectl describe hpa contact-api-hpa
   kubectl top pods
   ```

3. **Cluster Autoscaler Not Working**
   ```bash
   kubectl logs -n kube-system deployment/cluster-autoscaler
   ```

4. **CloudWatch Metrics Missing**
   ```bash
   kubectl logs -n amazon-cloudwatch deployment/aws-cloudwatch-metrics
   ```

##  Cost Optimization

### Current Setup
- **Nodes**: 1-3 x t3.small (SPOT instances)
- **Monitoring**: CloudWatch Container Insights
- **Scaling**: Automatic based on demand

### Cost Monitoring
- CloudWatch provides cost insights
- Set up billing alerts
- Monitor resource utilization

##  Security

### IAM Best Practices
- Least privilege access
- IRSA for service accounts
- Separate roles for each component

### Network Security
- Security groups properly configured
- VPC with public subnets only
- ALB with SSL termination

##  Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Cluster Autoscaler Documentation](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
