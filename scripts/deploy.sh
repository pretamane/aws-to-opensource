#!/bin/bash
# /k8s/deploy.sh - Deployment script for EKS cluster

set -e

echo " Deploying to EKS cluster..."

# Get cluster name from Terraform output
CLUSTER_NAME=$(cd ../terraform && terraform output -raw cluster_name 2>/dev/null || echo "realistic-demo-pretamane-cluster")

# Update kubeconfig
echo " Updating kubeconfig for cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --region ap-southeast-1 --name $CLUSTER_NAME

# Wait for metrics server to be ready
echo " Waiting for metrics server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

# Wait for cluster autoscaler to be ready
echo " Waiting for cluster autoscaler to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cluster-autoscaler -n kube-system

# Deploy the application
echo " Deploying application..."
kubectl apply -f serviceaccount.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Deploy HPA
echo " Deploying HPA..."
kubectl apply -f hpa.yaml

# Wait for deployment to be ready
echo " Waiting for application to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/contact-api

# Get the ALB endpoint
echo " Getting ALB endpoint..."
kubectl get ingress contact-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

echo " Deployment completed successfully!"
echo " Check status with: kubectl get pods,svc,ingress,hpa"
