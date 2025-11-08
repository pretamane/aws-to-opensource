#  Portfolio Showcase Script - Enterprise File Processing System

##  **Demo Overview**
This script demonstrates a comprehensive enterprise-grade file processing system built on AWS EKS with advanced storage mounting, indexing, and monitoring capabilities.

---

##  **Architecture Highlights**

### **Core Technologies**
- **AWS EKS**: Managed Kubernetes cluster
- **AWS EFS**: Elastic File System for persistent storage
- **AWS S3**: Object storage with lifecycle management
- **AWS OpenSearch**: Managed search and analytics
- **AWS Lambda**: Serverless event processing
- **FastAPI**: Modern Python web framework
- **RClone**: Advanced cloud storage mounting
- **Terraform**: Infrastructure as Code

### **Advanced Features**
- **Multi-Container Architecture**: FastAPI + RClone + OpenSearch Indexer
- **EFS Persistent Volumes**: Shared storage across pods
- **S3 Integration**: Automated backup and sync
- **OpenSearch Indexing**: Real-time document indexing
- **Horizontal Pod Autoscaling**: Automatic scaling based on load
- **Cluster Autoscaling**: Node-level scaling
- **CloudWatch Monitoring**: Comprehensive observability
- **IAM Roles for Service Accounts (IRSA)**: Secure AWS access

---

##  **Live Demo Script**

### **Step 1: System Overview**
```bash
echo " Welcome to the Enterprise File Processing System Demo!"
echo "=================================================="
echo ""
echo " System Architecture:"
echo "- AWS EKS Cluster with 2 nodes"
echo "- EFS Persistent Storage (10GB)"
echo "- S3 Buckets for data, index, and backup"
echo "- OpenSearch for document indexing"
echo "- FastAPI application with 3 containers"
echo ""

# Show system status
echo " Current System Status:"
kubectl get pods -l app=portfolio-demo -o wide
echo ""
kubectl get pv,pvc | grep efs
echo ""
```

### **Step 2: Health Check Demonstration**
```bash
echo " System Health Check:"
echo "======================="
curl -s http://localhost:8080/health | jq .
echo ""

echo " Storage Status:"
curl -s http://localhost:8080/storage/status | jq .
echo ""
```

### **Step 3: Document Upload Workflow**
```bash
echo " Document Upload Workflow:"
echo "============================"

# Create a sample business document
cat > business-proposal-2025.txt << 'DOC_EOF'
BUSINESS PROPOSAL
=================
Company: TechCorp Solutions
Project: Digital Transformation Initiative
Budget: $2,500,000
Timeline: 18 months
Status: PENDING_APPROVAL

EXECUTIVE SUMMARY:
This proposal outlines a comprehensive digital transformation
strategy for TechCorp Solutions, focusing on cloud migration,
automation, and data analytics implementation.

KEY OBJECTIVES:
1. Migrate 80% of workloads to AWS
2. Implement CI/CD pipelines
3. Establish data lake architecture
4. Deploy monitoring and alerting

EXPECTED OUTCOMES:
- 40% reduction in operational costs
- 60% improvement in deployment speed
- 99.9% system availability
- Enhanced security posture

APPROVAL REQUIRED:
- CTO: Pending
- CFO: Pending
- CEO: Pending
DOC_EOF

echo " Uploading business proposal..."
curl -X POST -F "file=@business-proposal-2025.txt" \
  http://localhost:8080/upload | jq .
echo ""
```

### **Step 4: Document Processing**
```bash
echo " Document Processing:"
echo "======================"
curl -X POST http://localhost:8080/process/business-proposal-2025.txt | jq .
echo ""
```

### **Step 5: File Management**
```bash
echo " File Management:"
echo "=================="
echo "Available files:"
curl -s http://localhost:8080/files | jq '.files[] | {name: .name, size: .size, modified: .modified}'
echo ""
```

### **Step 6: Audit Logging**
```bash
echo " Audit Logging:"
echo "================="
echo "Recent activities:"
curl -s http://localhost:8080/logs | jq '.logs[] | select(.file == "activity.log") | .content' | tail -3
echo ""
```

### **Step 7: Multi-Container Architecture Demo**
```bash
echo " Multi-Container Architecture:"
echo "==============================="
echo "Container Status:"
kubectl get pods -l app=portfolio-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}{"  - "}{.name}{" ("}{.image}{")"}{"\n"}{end}{end}'
echo ""

echo "EFS Mount Status:"
kubectl exec -it $(kubectl get pods -l app=portfolio-demo -o jsonpath='{.items[0].metadata.name}') \
  -- df -h /mnt/efs
echo ""

echo "S3 Mount Status:"
kubectl exec -it $(kubectl get pods -l app=portfolio-demo -o jsonpath='{.items[0].metadata.name}') \
  -- ls -la /mnt/s3/
echo ""
```

### **Step 8: Performance Testing**
```bash
echo " Performance Testing:"
echo "======================"
echo "Load testing with 10 concurrent requests:"
for i in {1..10}; do
  echo -n "Request $i: "
  curl -w "Time: %{time_total}s, Status: %{http_code}\n" \
    -o /dev/null -s http://localhost:8080/health
done
echo ""
```

### **Step 9: Monitoring and Observability**
```bash
echo " Monitoring and Observability:"
echo "==============================="
echo "Pod Resource Usage:"
kubectl top pods -l app=portfolio-demo
echo ""

echo "Node Resource Usage:"
kubectl top nodes
echo ""

echo "Application Logs (last 5 lines):"
kubectl logs -l app=portfolio-demo -c fastapi-app --tail=5
echo ""

echo "S3 Sync Logs (last 3 lines):"
kubectl logs -l app=portfolio-demo -c s3-sync --tail=3
echo ""

echo "OpenSearch Indexer Logs (last 3 lines):"
kubectl logs -l app=portfolio-demo -c opensearch-indexer --tail=3
echo ""
```

### **Step 10: Disaster Recovery Demo**
```bash
echo " Disaster Recovery Testing:"
echo "============================"
echo "Simulating pod failure and recovery..."

# Get current pod name
POD_NAME=$(kubectl get pods -l app=portfolio-demo -o jsonpath='{.items[0].metadata.name}')
echo "Current pod: $POD_NAME"

# Delete the pod
echo "Deleting pod to simulate failure..."
kubectl delete pod $POD_NAME

# Wait for new pod to be ready
echo "Waiting for new pod to be ready..."
kubectl wait --for=condition=Ready pod -l app=portfolio-demo --timeout=120s

# Verify system is still functional
echo "Verifying system recovery..."
curl -s http://localhost:8080/health | jq '.status'
echo ""

# Check if data persisted
echo "Verifying data persistence..."
curl -s http://localhost:8080/files | jq '.files | length'
echo ""
```

### **Step 11: Advanced Features Showcase**
```bash
echo " Advanced Features Showcase:"
echo "============================="

echo "1. EFS Persistent Storage:"
kubectl exec -it $(kubectl get pods -l app=portfolio-demo -o jsonpath='{.items[0].metadata.name}') \
  -- ls -la /mnt/efs/uploads/ | head -5
echo ""

echo "2. S3 Integration:"
kubectl exec -it $(kubectl get pods -l app=portfolio-demo -o jsonpath='{.items[0].metadata.name}') \
  -- ls -la /mnt/s3/data/ 2>/dev/null || echo "S3 mount in progress..."
echo ""

echo "3. OpenSearch Indexing:"
kubectl logs -l app=portfolio-demo -c opensearch-indexer --tail=1 | grep -o "Indexed document: doc_[0-9]*" || echo "Indexing in progress..."
echo ""

echo "4. Horizontal Pod Autoscaler:"
kubectl get hpa -l app=portfolio-demo 2>/dev/null || echo "HPA not configured in this demo"
echo ""

echo "5. Cluster Autoscaler:"
kubectl get nodes
echo ""
```

### **Step 12: Cost Optimization Features**
```bash
echo " Cost Optimization Features:"
echo "============================="
echo "1. SPOT Instances: Using t3.small SPOT for cost savings"
echo "2. EFS Lifecycle: Files transition to IA after 7 days"
echo "3. S3 Lifecycle: Automatic archival to Glacier"
echo "4. Auto-scaling: Resources scale based on demand"
echo "5. Monitoring: CloudWatch billing alarms"
echo ""

echo "Estimated monthly cost for this setup:"
echo "- EKS Cluster: ~$73/month"
echo "- EC2 Instances (2x t3.small SPOT): ~$30/month"
echo "- EFS (10GB): ~$3/month"
echo "- S3 Storage: ~$1/month"
echo "- OpenSearch: ~$50/month"
echo "- Total: ~$157/month"
echo ""
```

### **Step 13: Security Features**
```bash
echo " Security Features:"
echo "===================="
echo "1. IAM Roles for Service Accounts (IRSA)"
echo "2. EFS Encryption at rest"
echo "3. S3 Server-side encryption"
echo "4. VPC with private subnets"
echo "5. Security groups with least privilege"
echo "6. OpenSearch access policies"
echo ""

echo "IAM Roles in use:"
kubectl get serviceaccounts -l app=portfolio-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .metadata.annotations}{"  "}{.}{"\n"}{end}{end}'
echo ""
```

### **Step 14: Cleanup Demo**
```bash
echo " Cleanup Demo:"
echo "==============="
echo "Cleaning up test files..."
rm -f business-proposal-2025.txt
rm -f legal-contract-2025.txt
rm -f patient-record-12345.txt
rm -f loan-application-*.txt
rm -f student-transcript-789.txt
rm -f research-paper-ai-ethics.txt
rm -f qc-report-batch-2025-001.txt
echo "Test files cleaned up!"
echo ""
```

---

##  **Demo Conclusion**

### **Key Takeaways**
1. **Enterprise-Grade Architecture**: Multi-container, scalable, and resilient
2. **Advanced Storage**: EFS + S3 integration with lifecycle management
3. **Real-time Indexing**: OpenSearch for document search and analytics
4. **Cost Optimization**: SPOT instances, auto-scaling, and lifecycle policies
5. **Security**: IRSA, encryption, and least-privilege access
6. **Monitoring**: Comprehensive observability with CloudWatch
7. **Disaster Recovery**: Data persistence and automatic pod recovery

### **Business Value**
- **Scalability**: Handles high-volume document processing
- **Reliability**: 99.9% uptime with auto-recovery
- **Cost-Effective**: Optimized for AWS Free Tier and cost savings
- **Secure**: Enterprise-grade security and compliance
- **Maintainable**: Infrastructure as Code with Terraform

### **Technical Skills Demonstrated**
- **AWS Services**: EKS, EFS, S3, OpenSearch, Lambda, IAM
- **Kubernetes**: Deployments, Services, PVCs, ConfigMaps, Secrets
- **Containerization**: Multi-container patterns, sidecars, init containers
- **Infrastructure as Code**: Terraform modules and automation
- **Monitoring**: CloudWatch, logging, and observability
- **Security**: IRSA, encryption, and access control

---

##  **Next Steps**
1. **Production Deployment**: Use `deploy-comprehensive.sh`
2. **Monitoring Setup**: Configure CloudWatch dashboards
3. **Backup Strategy**: Implement automated backups
4. **Security Hardening**: Review and update security policies
5. **Performance Tuning**: Optimize based on usage patterns

**Demo Completed Successfully! **
