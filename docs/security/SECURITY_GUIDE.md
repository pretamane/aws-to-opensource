#  Security Guide for AWS EKS Portfolio Demo

##  CRITICAL SECURITY WARNINGS

###  Never Commit Credentials to Version Control
- **NEVER** commit AWS access keys, secret keys, or passwords to Git
- **NEVER** hardcode credentials in YAML files
- **ALWAYS** use environment variables or secure secret management

###  Credential Management Best Practices

#### 1. Environment Variables (Recommended for Development)
```bash
export AWS_ACCESS_KEY_ID=your_access_key_here
export AWS_SECRET_ACCESS_KEY=your_secret_key_here
export AWS_DEFAULT_REGION=ap-southeast-1
```

#### 2. AWS IAM Roles for Service Accounts (IRSA) - Production Recommended
```bash
# Create IAM role for service account
eksctl create iamserviceaccount \
  --name contact-api \
  --namespace default \
  --cluster your-cluster-name \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
  --approve
```

#### 3. Kubernetes Secrets (Secure Method)
```bash
# Create secrets from environment variables
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY"

kubectl create secret generic storage-credentials \
  --from-literal=aws-access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=aws-secret-access-key="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=opensearch-username="your_opensearch_user" \
  --from-literal=opensearch-password="your_opensearch_password"
```

##  Security Checklist

### Before Deployment
- [ ] Remove all hardcoded credentials from YAML files
- [ ] Set up environment variables
- [ ] Use least-privilege IAM policies
- [ ] Enable AWS CloudTrail for audit logging
- [ ] Enable VPC Flow Logs

### During Deployment
- [ ] Use secure deployment scripts
- [ ] Verify secrets are created properly
- [ ] Test with minimal permissions first
- [ ] Monitor for unauthorized access

### After Deployment
- [ ] Rotate credentials regularly
- [ ] Monitor AWS CloudTrail logs
- [ ] Set up billing alerts
- [ ] Regular security audits

##  Secure Deployment Commands

### 1. Set Environment Variables
```bash
# Set your AWS credentials
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=ap-southeast-1

# Set OpenSearch credentials
export OPENSEARCH_USERNAME=your_opensearch_user
export OPENSEARCH_PASSWORD=your_opensearch_password
export OPENSEARCH_ENDPOINT=your_opensearch_endpoint
```

### 2. Create Secrets Securely
```bash
# Create AWS credentials secret
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY"

# Create storage credentials secret
kubectl create secret generic storage-credentials \
  --from-literal=aws-access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=aws-secret-access-key="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=opensearch-username="$OPENSEARCH_USERNAME" \
  --from-literal=opensearch-password="$OPENSEARCH_PASSWORD" \
  --from-literal=opensearch-endpoint="$OPENSEARCH_ENDPOINT"
```

### 3. Deploy Application
```bash
# Use the secure deployment script
./scripts/secure-deploy.sh
```

##  Emergency Response

### If Credentials Are Compromised
1. **Immediately rotate AWS credentials** in AWS Console
2. **Delete compromised secrets** from Kubernetes
3. **Review CloudTrail logs** for unauthorized access
4. **Update all deployment scripts** with new credentials
5. **Notify your team** about the security incident

### Credential Rotation Process
```bash
# 1. Generate new AWS credentials in AWS Console
# 2. Update environment variables
export AWS_ACCESS_KEY_ID=new_access_key
export AWS_SECRET_ACCESS_KEY=new_secret_key

# 3. Delete old secrets
kubectl delete secret aws-credentials storage-credentials

# 4. Create new secrets
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY"

# 5. Restart deployments to pick up new secrets
kubectl rollout restart deployment/portfolio-demo
```

##  IAM Policy Recommendations

### Minimal S3 Policy
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::your-bucket-name/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::your-bucket-name"
            ]
        }
    ]
}
```

### Minimal EFS Policy
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientWrite"
            ],
            "Resource": [
                "arn:aws:elasticfilesystem:region:account:file-system/fs-xxxxxxxxx"
            ]
        }
    ]
}
```

##  Monitoring and Alerting

### Set up Billing Alerts
```bash
# Create billing alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "AWS-Billing-Alarm" \
  --alarm-description "Alert when AWS charges exceed $10" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 10.0 \
  --comparison-operator GreaterThanThreshold
```

### Monitor for Unauthorized Access
```bash
# Check CloudTrail for recent API calls
aws logs filter-log-events \
  --log-group-name CloudTrail/YourLogGroup \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR"
```

##  Additional Resources

- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [EKS Security Best Practices](https://aws.github.io/aws-eks-best-practices/security/)

---

**Remember: Security is everyone's responsibility. When in doubt, ask for help!**
