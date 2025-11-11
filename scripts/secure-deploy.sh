#!/bin/bash

# Secure Deployment Script for AWS EKS Portfolio Demo
# This script ensures credentials are handled securely

set -e

echo " Secure AWS EKS Portfolio Demo Deployment"
echo "=========================================="

# Check if AWS credentials are available
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo " Error: AWS credentials not found in environment variables"
    echo "Please set the following environment variables:"
    echo "  export AWS_ACCESS_KEY_ID=your_access_key"
    echo "  export AWS_SECRET_ACCESS_KEY=your_secret_key"
    echo "  export AWS_DEFAULT_REGION=ap-southeast-1"
    echo ""
    echo "Optional OpenSearch credentials:"
    echo "  export OPENSEARCH_USERNAME=your_opensearch_user"
    echo "  export OPENSEARCH_PASSWORD=your_opensearch_password"
    echo "  export OPENSEARCH_ENDPOINT=your_opensearch_endpoint"
    exit 1
fi

echo " AWS credentials found in environment variables"

# Check for OpenSearch credentials
if [ -z "$OPENSEARCH_USERNAME" ] || [ -z "$OPENSEARCH_PASSWORD" ]; then
    echo "  Warning: OpenSearch credentials not found in environment variables"
    echo "Setting default values (you should replace these with actual credentials)"
    export OPENSEARCH_USERNAME="admin"
    export OPENSEARCH_PASSWORD="Admin123!"
    export OPENSEARCH_ENDPOINT="https://search-realistic-demo-pretamane-us-east-1.es.amazonaws.com"
fi

# Create secure Kubernetes secrets
echo " Creating secure AWS credentials secret..."
kubectl create secret generic aws-credentials \
    --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
    --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

echo " Creating secure storage credentials secret..."
kubectl create secret generic storage-credentials \
    --from-literal=aws-access-key-id="$AWS_ACCESS_KEY_ID" \
    --from-literal=aws-secret-access-key="$AWS_SECRET_ACCESS_KEY" \
    --from-literal=opensearch-username="$OPENSEARCH_USERNAME" \
    --from-literal=opensearch-password="$OPENSEARCH_PASSWORD" \
    --from-literal=opensearch-endpoint="$OPENSEARCH_ENDPOINT" \
    --dry-run=client -o yaml | kubectl apply -f -

echo " All secrets created securely"

# Deploy the portfolio demo
echo " Deploying portfolio demo..."
kubectl apply -f k8s/portfolio-demo.yaml

echo " Portfolio demo deployed successfully"
echo ""
echo " To check the deployment status:"
echo "  kubectl get pods -l app=portfolio-demo"
echo "  kubectl get services"
echo "  kubectl get secrets"
echo ""
echo " To access the application:"
echo "  kubectl port-forward service/portfolio-demo-service 8080:80"
echo "  Then open: http://localhost:8080"
echo ""
echo " To check logs:"
echo "  kubectl logs -l app=portfolio-demo -c fastapi-app"
echo "  kubectl logs -l app=portfolio-demo -c s3-sync"
echo ""
echo "  SECURITY REMINDER:"
echo "  - Never commit AWS credentials to version control"
echo "  - Use IAM roles with minimal required permissions"
echo "  - Rotate credentials regularly"
echo "  - Consider using AWS IAM Roles for Service Accounts (IRSA) for production"
echo "  - Monitor AWS CloudTrail for unauthorized access"
echo ""
echo " For more security information, see: SECURITY_GUIDE.md"
