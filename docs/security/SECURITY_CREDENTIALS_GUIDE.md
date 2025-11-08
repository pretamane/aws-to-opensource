# Security & Credentials Management Guide

##  Overview

This guide explains how to securely manage credentials and sensitive information in the realistic-demo-pretamane project.

##  Security Issues Fixed

### Previously Hardcoded Credentials (Now Secured)

1. **Email Addresses**: `thawzin252467@gmail.com` was hardcoded in multiple files
2. **Default Passwords**: Weak default passwords in configuration files
3. **AWS Credentials**: References to hardcoded access keys

### Files Updated

-  `ansible/group_vars/all.yml` - Email variables now use environment lookup
-  `terraform/main.tf` - Email variables now use Terraform variables
-  `terraform/variables.tf` - Added email variable definitions
-  `terraform/modules/database/variables.tf` - Removed hardcoded emails
-  `k8s/*.yaml` - All deployment files now use Kubernetes secrets
-  `docker/api/app.py` - Default emails changed to generic examples
-  `lambda-code/lambda_function.py` - Default emails changed to generic examples
-  `ansible/inventory/hosts.yml` - Default password changed to secure placeholder

##  Security Best Practices Implemented

### 1. Environment Variables
- All sensitive data now uses environment variables
- Template file (`config/environments/production.env`) provided for easy setup
- `.env` file is gitignored to prevent accidental commits

### 2. Kubernetes Secrets
- Email addresses stored in Kubernetes secrets
- Base64 encoded for security
- Referenced via `secretKeyRef` in deployments

### 3. Terraform Variables
- Email addresses passed as variables
- No hardcoded values in infrastructure code
- Can be set via environment variables or `.tfvars` files

### 4. Secure Defaults
- Generic example emails instead of real addresses
- Secure password placeholders
- Clear instructions for credential setup

##  How to Set Up Your Credentials

### Option 1: Using the Setup Script (Recommended)

```bash
# Run the secure credentials setup script
./scripts/setup-secure-credentials.sh
```

This script will:
- Create `.env` file from template
- Set secure file permissions (600)
- Check AWS CLI configuration
- Auto-populate AWS Account ID
- Provide clear next steps

### Option 2: Manual Setup

1. **Copy the template**:
   ```bash
   cp config/environments/production.env .env
   ```

2. **Edit the .env file** with your actual credentials:
   ```bash
   nano .env
   ```

3. **Set secure permissions**:
   ```bash
   chmod 600 .env
   ```

4. **Load environment variables**:
   ```bash
   source .env
   ```

### Required Environment Variables

```bash
# AWS Configuration
AWS_ACCESS_KEY_ID=your_aws_access_key_here
AWS_SECRET_ACCESS_KEY=your_aws_secret_key_here
AWS_ACCOUNT_ID=your_aws_account_id_here
AWS_REGION=ap-southeast-1

# Email Configuration
SES_FROM_EMAIL=your-email@example.com
SES_TO_EMAIL=your-email@example.com

# OpenSearch Configuration
OPENSEARCH_ENDPOINT=https://search-your-domain-1234567890.ap-southeast-1.es.amazonaws.com
OPENSEARCH_MASTER_USER=admin
OPENSEARCH_MASTER_PASSWORD=your_secure_password_here

# S3 Configuration
S3_DATA_BUCKET=your-project-name-data
S3_INDEX_BUCKET=your-project-name-index
S3_BACKUP_BUCKET=your-project-name-backup

# EFS Configuration
EFS_FILE_SYSTEM_ID=fs-12345678
EFS_ACCESS_POINT_ID=fsap-12345678

# Terraform Configuration
TF_VAR_ses_from_email=your-email@example.com
TF_VAR_ses_to_email=your-email@example.com
```

##  Security Recommendations

### 1. Use IAM Roles Instead of Access Keys
- Prefer IAM roles for service accounts (IRSA) in Kubernetes
- Use EC2 instance roles for Terraform execution
- Minimize use of long-term access keys

### 2. Rotate Credentials Regularly
- Change passwords every 90 days
- Rotate access keys quarterly
- Use AWS Secrets Manager for automatic rotation

### 3. Least Privilege Principle
- Grant minimum required permissions
- Use separate IAM users for different purposes
- Regularly audit IAM policies

### 4. Monitor Access
- Enable CloudTrail for API logging
- Set up CloudWatch alarms for unusual activity
- Monitor failed authentication attempts

### 5. Secure Storage
- Never commit `.env` files to version control
- Use encrypted storage for sensitive data
- Implement proper backup and recovery procedures

##  Testing Security

### 1. Verify No Hardcoded Credentials
```bash
# Search for potential hardcoded credentials
grep -r "AKIA\|ASIA\|password\|secret" . --exclude-dir=.git --exclude="*.md"
```

### 2. Check File Permissions
```bash
# Ensure .env file has secure permissions
ls -la .env
# Should show: -rw------- (600)
```

### 3. Validate Environment Variables
```bash
# Test that environment variables are loaded
source .env
echo $AWS_ACCESS_KEY_ID
echo $SES_FROM_EMAIL
```

##  Emergency Procedures

### If Credentials Are Compromised

1. **Immediately rotate all credentials**:
   ```bash
   # Generate new AWS access keys
   aws iam create-access-key --user-name your-username
   
   # Update .env file with new credentials
   nano .env
   ```

2. **Revoke old credentials**:
   ```bash
   # Delete old access keys
   aws iam delete-access-key --user-name your-username --access-key-id OLD_KEY_ID
   ```

3. **Update all deployments**:
   ```bash
   # Redeploy with new credentials
   ansible-playbook playbooks/deploy.yml
   ```

4. **Audit access logs**:
   ```bash
   # Check CloudTrail for suspicious activity
   aws logs filter-log-events --log-group-name CloudTrail/YourLogGroup
   ```

##  Security Checklist

- [ ] All hardcoded credentials removed
- [ ] Environment variables properly configured
- [ ] `.env` file created and secured (600 permissions)
- [ ] Kubernetes secrets properly configured
- [ ] Terraform variables set correctly
- [ ] AWS CLI configured with appropriate credentials
- [ ] IAM policies follow least privilege principle
- [ ] CloudTrail logging enabled
- [ ] Regular credential rotation schedule established
- [ ] Team members trained on security procedures

##  Support

If you encounter any security issues or need help with credential management:

1. Check this guide first
2. Run the setup script: `./scripts/setup-secure-credentials.sh`
3. Verify your `.env` file configuration
4. Test with dry-run: `ansible-playbook playbooks/deploy.yml --check`

Remember: **Security is everyone's responsibility!** 


