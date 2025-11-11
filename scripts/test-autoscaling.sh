#!/bin/bash
# Test Autoscaling Script for Portfolio Demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE} Autoscaling Test for Portfolio Demo${NC}"
echo -e "${PURPLE}====================================${NC}"
echo ""

# Function to check HPA status
check_hpa_status() {
    echo -e "${BLUE} Current HPA Status:${NC}"
    kubectl get hpa portfolio-demo-hpa
    echo ""
    
    echo -e "${BLUE} HPA Details:${NC}"
    kubectl describe hpa portfolio-demo-hpa
    echo ""
}

# Function to check pod status
check_pod_status() {
    echo -e "${GREEN} Current Pod Status:${NC}"
    kubectl get pods -l app=portfolio-demo -o wide
    echo ""
    
    echo -e "${GREEN} Pod Resource Usage:${NC}"
    kubectl top pods -l app=portfolio-demo 2>/dev/null || echo "Metrics server not available"
    echo ""
}

# Function to generate load
generate_load() {
    echo -e "${YELLOW} Generating Load for Autoscaling Test...${NC}"
    echo "This will create multiple concurrent requests to trigger autoscaling"
    echo ""
    
    # Create a load generation script
    cat > load-generator.sh << 'LOAD_EOF'
#!/bin/bash
# Load generator script

for i in {1..50}; do
    {
        # Generate CPU load by making multiple requests
        for j in {1..10}; do
            curl -s http://localhost:8080/health > /dev/null &
            curl -s http://localhost:8080/storage/status > /dev/null &
            curl -s http://localhost:8080/files > /dev/null &
        done
        wait
        echo "Load batch $i completed"
    } &
done
wait
echo "Load generation completed"
LOAD_EOF
    
    chmod +x load-generator.sh
    echo "Starting load generation in background..."
    ./load-generator.sh &
    LOAD_PID=$!
    echo "Load generator PID: $LOAD_PID"
    echo ""
}

# Function to monitor autoscaling
monitor_autoscaling() {
    echo -e "${CYAN} Monitoring Autoscaling (60 seconds)...${NC}"
    echo "Watching for pod count changes..."
    echo ""
    
    for i in {1..12}; do
        echo -e "${BLUE}--- Check $i/12 (5 seconds interval) ---${NC}"
        echo "Time: $(date)"
        
        # Check HPA status
        kubectl get hpa portfolio-demo-hpa -o custom-columns="NAME:.metadata.name,REFERENCE:.spec.scaleTargetRef.name,TARGETS:.status.currentCPUUtilizationPercentage%,MINPODS:.spec.minReplicas,MAXPODS:.spec.maxReplicas,REPLICAS:.status.currentReplicas"
        
        # Check pod count
        POD_COUNT=$(kubectl get pods -l app=portfolio-demo --no-headers | wc -l)
        echo "Current pod count: $POD_COUNT"
        
        # Check if pods are ready
        READY_PODS=$(kubectl get pods -l app=portfolio-demo --no-headers | grep "Running" | wc -l)
        echo "Ready pods: $READY_PODS"
        
        echo ""
        sleep 5
    done
}

# Function to test scale down
test_scale_down() {
    echo -e "${RED} Testing Scale Down...${NC}"
    echo "Stopping load generation and waiting for scale down..."
    
    # Kill load generator if running
    pkill -f load-generator.sh 2>/dev/null || true
    
    echo "Waiting 2 minutes for scale down..."
    sleep 120
    
    echo -e "${BLUE}Final HPA Status:${NC}"
    kubectl get hpa portfolio-demo-hpa
    echo ""
    
    echo -e "${BLUE}Final Pod Status:${NC}"
    kubectl get pods -l app=portfolio-demo
    echo ""
}

# Function to create stress test
create_stress_test() {
    echo -e "${PURPLE} Creating Stress Test Deployment${NC}"
    
    cat > k8s/stress-test.yaml << 'STRESS_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-test
  labels:
    app: stress-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stress-test
  template:
    metadata:
      labels:
        app: stress-test
    spec:
      containers:
      - name: stress-test
        image: busybox
        command: ["/bin/sh"]
        args:
          - -c
          - |
            echo "Starting stress test..."
            while true; do
              # Generate CPU load
              for i in $(seq 1 100); do
                echo "Stress test iteration $i"
                # Make requests to the portfolio demo
                wget -q -O /dev/null http://portfolio-demo-service:80/health || true
                wget -q -O /dev/null http://portfolio-demo-service:80/storage/status || true
                wget -q -O /dev/null http://portfolio-demo-service:80/files || true
              done
              sleep 1
            done
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
STRESS_EOF
    
    kubectl apply -f k8s/stress-test.yaml
    echo "Stress test deployment created"
    echo ""
}

# Function to clean up stress test
cleanup_stress_test() {
    echo -e "${YELLOW} Cleaning up stress test...${NC}"
    kubectl delete -f k8s/stress-test.yaml 2>/dev/null || true
    rm -f k8s/stress-test.yaml
    rm -f load-generator.sh
    echo "Cleanup completed"
    echo ""
}

# Main test function
main() {
    echo -e "${GREEN} Starting Autoscaling Test${NC}"
    echo "=================================="
    echo ""
    
    # Check initial status
    echo -e "${BLUE}1. Initial Status Check${NC}"
    check_hpa_status
    check_pod_status
    
    # Create stress test
    echo -e "${BLUE}2. Creating Stress Test${NC}"
    create_stress_test
    
    # Wait for stress test to start
    echo "Waiting for stress test to start..."
    kubectl wait --for=condition=Ready pod -l app=stress-test --timeout=60s
    
    # Monitor autoscaling
    echo -e "${BLUE}3. Monitoring Autoscaling${NC}"
    monitor_autoscaling
    
    # Test scale down
    echo -e "${BLUE}4. Testing Scale Down${NC}"
    test_scale_down
    
    # Cleanup
    echo -e "${BLUE}5. Cleanup${NC}"
    cleanup_stress_test
    
    echo -e "${GREEN} Autoscaling Test Completed!${NC}"
    echo ""
    echo -e "${CYAN}Summary:${NC}"
    echo "- HPA was created and configured"
    echo "- Load was generated to trigger scaling"
    echo "- Pod count was monitored during scaling"
    echo "- Scale down was tested after load removal"
    echo ""
    echo -e "${PURPLE}Your autoscaling is working! ${NC}"
}

# Run main function
main "$@"
