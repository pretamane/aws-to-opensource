# Database Setup Guide

This document describes the comprehensive database setup for the EKS application.

##  **Database Architecture**

### **DynamoDB Tables**

#### 1. **Contact Submissions Table**
- **Name**: `realistic-demo-pretamane-contact-submissions`
- **Purpose**: Store contact form submissions
- **Billing**: Pay-per-request (cost-effective for variable workloads)
- **Encryption**: Server-side encryption enabled
- **Backup**: Point-in-time recovery enabled

**Schema**:
```json
{
  "id": "contact_1234567890_123456",  // Primary key
  "name": "John Doe",
  "email": "john@example.com",
  "company": "Acme Corp",
  "service": "Web Development",
  "budget": "$10,000 - $50,000",
  "message": "Looking for a new website...",
  "timestamp": "2024-01-15T10:30:00Z",
  "status": "new",
  "source": "website",
  "userAgent": "Mozilla/5.0...",
  "pageUrl": "https://example.com/contact"
}
```

**Global Secondary Indexes**:
- **email-index**: Query by email address
- **timestamp-index**: Query by submission time

#### 2. **Website Visitors Table**
- **Name**: `realistic-demo-pretamane-website-visitors`
- **Purpose**: Track visitor count and analytics
- **Billing**: Pay-per-request
- **Encryption**: Server-side encryption enabled
- **Backup**: Point-in-time recovery enabled

**Schema**:
```json
{
  "id": "visitor_count",  // Primary key
  "count": 1234           // Atomic counter
}
```

### **SES Configuration**
- **From Email**: thawzin252467@gmail.com
- **To Email**: thawzin252467@gmail.com
- **Configuration Set**: realistic-demo-pretamane-ses-config
- **Features**: Email tracking, reputation metrics

##  **Security & IAM**

### **Application IAM Role (IRSA)**
- **Role Name**: `realistic-demo-pretamane-app-role`
- **Service Account**: `contact-api` (default namespace)
- **Permissions**:
  - DynamoDB: GetItem, PutItem, UpdateItem, Query, Scan
  - SES: SendEmail, SendRawEmail

### **Security Features**
- **Encryption at Rest**: All tables encrypted with AWS managed keys
- **Encryption in Transit**: HTTPS for all API calls
- **Access Control**: IAM roles with least privilege
- **Audit Logging**: CloudTrail integration

##  **Deployment Process**

### **1. Create Backend Infrastructure**
```bash
# Create S3 bucket and DynamoDB table for Terraform state
cd terraform/modules/backend
terraform init
terraform apply
```

### **2. Deploy Main Infrastructure**
```bash
# Deploy all infrastructure including databases
cd terraform
terraform init
terraform plan
terraform apply
```

### **3. Verify Database Creation**
```bash
# Check DynamoDB tables
aws dynamodb list-tables --region ap-southeast-1

# Check SES configuration
aws ses list-identities --region ap-southeast-1
```

### **4. Deploy Application**
```bash
# Deploy to EKS
cd k8s
./deploy.sh
```

##  **Database Performance & Monitoring**

### **DynamoDB Metrics**
- **CloudWatch Metrics**:
  - ConsumedReadCapacityUnits
  - ConsumedWriteCapacityUnits
  - ThrottledRequests
  - UserErrors
  - SystemErrors

### **Performance Optimization**
- **Global Secondary Indexes**: For efficient querying
- **Batch Operations**: For bulk data operations
- **Connection Pooling**: Handled by boto3
- **Retry Logic**: Built into application code

### **Cost Optimization**
- **Pay-per-Request**: No upfront costs
- **Auto-scaling**: Automatic capacity adjustment
- **Point-in-time Recovery**: Cost-effective backup solution

##  **Configuration**

### **Environment Variables**
```bash
# Application environment variables
AWS_REGION=ap-southeast-1
CONTACTS_TABLE=realistic-demo-pretamane-contact-submissions
VISITORS_TABLE=realistic-demo-pretamane-website-visitors
SES_FROM_EMAIL=thawzin252467@gmail.com
SES_TO_EMAIL=thawzin252467@gmail.com
```

### **Service Account Configuration**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: contact-api
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/realistic-demo-pretamane-app-role
```

##  **Troubleshooting**

### **Common Issues**

#### 1. **DynamoDB Access Denied**
```bash
# Check IAM role permissions
aws iam get-role --role-name realistic-demo-pretamane-app-role

# Check service account
kubectl describe serviceaccount contact-api
```

#### 2. **SES Email Not Sending**
```bash
# Verify SES identity
aws ses get-identity-verification-attributes --identities thawzin252467@gmail.com

# Check SES sending quota
aws ses get-send-quota --region ap-southeast-1
```

#### 3. **Table Not Found**
```bash
# List all tables
aws dynamodb list-tables --region ap-southeast-1

# Check table details
aws dynamodb describe-table --table-name realistic-demo-pretamane-contact-submissions
```

### **Debugging Commands**
```bash
# Check application logs
kubectl logs -l app=contact-api

# Check service account token
kubectl get serviceaccount contact-api -o yaml

# Test DynamoDB access
kubectl exec -it deployment/contact-api -- aws dynamodb list-tables
```

##  **Scaling Considerations**

### **DynamoDB Scaling**
- **Automatic Scaling**: Built-in with pay-per-request
- **Global Secondary Indexes**: For complex queries
- **DynamoDB Accelerator (DAX)**: For microsecond latency (if needed)

### **SES Scaling**
- **Sending Limits**: 200 emails/day (sandbox), 50,000/day (production)
- **Rate Limits**: 14 emails/second
- **Bounce/Complaint Handling**: Automatic suppression lists

##  **Backup & Recovery**

### **Backup Strategy**
- **Point-in-time Recovery**: Enabled for all tables
- **Retention Period**: 35 days (configurable)
- **Cross-region Replication**: Available if needed

### **Recovery Process**
```bash
# Restore to point in time
aws dynamodb restore-table-to-point-in-time \
  --source-table-name realistic-demo-pretamane-contact-submissions \
  --target-table-name realistic-demo-pretamane-contact-submissions-restored \
  --restore-date-time 2024-01-15T10:30:00Z
```

##  **Cost Estimation**

### **Monthly Costs (Estimated)**
- **DynamoDB**: $0.25 per million read requests, $1.25 per million write requests
- **SES**: $0.10 per 1,000 emails sent
- **CloudWatch**: $0.30 per GB of logs ingested

### **Cost Optimization Tips**
- Use DynamoDB TTL for automatic data cleanup
- Implement proper error handling to avoid unnecessary retries
- Monitor CloudWatch metrics for cost optimization

##  **Security Best Practices**

1. **Least Privilege Access**: IAM roles with minimal required permissions
2. **Encryption**: All data encrypted at rest and in transit
3. **Audit Logging**: CloudTrail for all API calls
4. **Network Security**: VPC endpoints for private access (optional)
5. **Regular Backups**: Point-in-time recovery enabled

##  **Additional Resources**

- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [SES Developer Guide](https://docs.aws.amazon.com/ses/latest/dg/)
- [EKS IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [DynamoDB Global Secondary Indexes](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html)
