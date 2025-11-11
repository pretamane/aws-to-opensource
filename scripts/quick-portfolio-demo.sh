#!/bin/bash
# Quick Portfolio Demo Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE} Enterprise File Processing System - Portfolio Demo${NC}"
echo -e "${PURPLE}================================================${NC}"
echo ""

# Check if port-forward is running
if ! pgrep -f "kubectl port-forward" > /dev/null; then
    echo -e "${YELLOW}  Starting port-forward...${NC}"
    kubectl port-forward $(kubectl get pods -l app=portfolio-demo -o jsonpath='{.items[0].metadata.name}') 8080:8000 &
    sleep 5
fi

echo -e "${BLUE} System Overview:${NC}"
echo "=================="
kubectl get pods -l app=portfolio-demo -o wide
echo ""

echo -e "${GREEN} Health Check:${NC}"
echo "==============="
curl -s http://localhost:8080/health | jq .
echo ""

echo -e "${CYAN} Storage Status:${NC}"
echo "=================="
curl -s http://localhost:8080/storage/status | jq .
echo ""

echo -e "${YELLOW} Creating Sample Document:${NC}"
echo "============================="
cat > demo-document.txt << 'DOC_EOF'
PORTFOLIO DEMO DOCUMENT
=======================
Project: Enterprise File Processing System
Technologies: AWS EKS, EFS, S3, OpenSearch, FastAPI
Features: Multi-container, Auto-scaling, Monitoring
Date: $(date)
Status: DEMO_READY

This document demonstrates the capabilities of our
enterprise-grade file processing system built on AWS.
DOC_EOF

echo -e "${GREEN} Uploading Document:${NC}"
echo "======================"
curl -X POST -F "file=@demo-document.txt" http://localhost:8080/upload | jq .
echo ""

echo -e "${BLUE}️ Processing Document:${NC}"
echo "======================="
curl -X POST http://localhost:8080/process/demo-document.txt | jq .
echo ""

echo -e "${PURPLE} File Management:${NC}"
echo "===================="
curl -s http://localhost:8080/files | jq '.files[] | {name: .name, size: .size}'
echo ""

echo -e "${CYAN} Multi-Container Architecture:${NC}"
echo "================================="
kubectl get pods -l app=portfolio-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}{"  - "}{.name}{" ("}{.image}{")"}{"\n"}{end}{end}'
echo ""

echo -e "${YELLOW} Resource Usage:${NC}"
echo "=================="
kubectl top pods -l app=portfolio-demo 2>/dev/null || echo "Metrics server not available"
echo ""

echo -e "${GREEN} Advanced Features:${NC}"
echo "====================="
echo " EFS Persistent Storage"
echo " S3 Integration with RClone"
echo " OpenSearch Indexing"
echo " Multi-container Architecture"
echo " Auto-scaling Capabilities"
echo " CloudWatch Monitoring"
echo " IAM Roles for Service Accounts"
echo ""

echo -e "${RED} Cleaning up demo files:${NC}"
echo "=========================="
rm -f demo-document.txt
echo "Demo files cleaned up!"
echo ""

echo -e "${PURPLE} Portfolio Demo Completed Successfully!${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""
echo -e "${CYAN}Key Technologies Demonstrated:${NC}"
echo "- AWS EKS (Kubernetes)"
echo "- AWS EFS (Persistent Storage)"
echo "- AWS S3 (Object Storage)"
echo "- AWS OpenSearch (Search & Analytics)"
echo "- FastAPI (Python Web Framework)"
echo "- RClone (Cloud Storage Mounting)"
echo "- Terraform (Infrastructure as Code)"
echo ""
echo -e "${GREEN}Your portfolio is ready for presentation! ${NC}"
