#!/bin/bash
# Effective Autoscaling Test

echo " Effective Autoscaling Test for Portfolio Demo"
echo "==============================================="
echo ""

echo " Current Status:"
kubectl get hpa portfolio-demo-hpa
echo ""
kubectl top pods -l app=portfolio-demo
echo ""

echo " Creating CPU-intensive load test..."
echo "This will create a pod that generates CPU load to trigger autoscaling"

# Create a CPU stress test deployment
cat > k8s/cpu-stress-test.yaml << 'STRESS_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-stress-test
  labels:
    app: cpu-stress-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-stress-test
  template:
    metadata:
      labels:
        app: cpu-stress-test
    spec:
      containers:
      - name: cpu-stress
        image: busybox
        command: ["/bin/sh"]
        args:
          - -c
          - |
            echo "Starting CPU stress test..."
            # Generate CPU load by making continuous requests
            while true; do
              # Make requests to portfolio demo to increase its CPU usage
              for i in $(seq 1 100); do
                wget -q -O /dev/null http://portfolio-demo-service:80/health || true
                wget -q -O /dev/null http://portfolio-demo-service:80/storage/status || true
                wget -q -O /dev/null http://portfolio-demo-service:80/files || true
                # Add some CPU work
                echo "Request $i" > /dev/null
              done
              sleep 0.1
            done
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
STRESS_EOF

kubectl apply -f k8s/cpu-stress-test.yaml
echo "CPU stress test deployment created"
echo ""

echo " Waiting for stress test to start..."
kubectl wait --for=condition=Ready pod -l app=cpu-stress-test --timeout=60s

echo " Monitoring autoscaling for 2 minutes..."
echo "Watch for pod count changes..."

for i in {1..24}; do
    echo "--- Check $i/24 (5 seconds) ---"
    echo "Time: $(date)"
    
    # Show HPA status
    kubectl get hpa portfolio-demo-hpa -o custom-columns="NAME:.metadata.name,CPU:.status.currentCPUUtilizationPercentage%,MEM:.status.currentMemoryUtilizationPercentage%,REPLICAS:.status.currentReplicas"
    
    # Show pod count
    POD_COUNT=$(kubectl get pods -l app=portfolio-demo --no-headers | wc -l)
    echo "Portfolio demo pods: $POD_COUNT"
    
    # Show resource usage
    kubectl top pods -l app=portfolio-demo 2>/dev/null || echo "Metrics not available"
    
    echo ""
    sleep 5
done

echo " Cleaning up stress test..."
kubectl delete -f k8s/cpu-stress-test.yaml
rm -f k8s/cpu-stress-test.yaml

echo ""
echo " Final Status:"
kubectl get hpa portfolio-demo-hpa
echo ""
kubectl get pods -l app=portfolio-demo
echo ""

echo " Autoscaling test completed!"
echo ""
echo " If you didn't see scaling, try:"
echo "1. Lower the CPU target: kubectl patch hpa portfolio-demo-hpa -p '{\"spec\":{\"metrics\":[{\"type\":\"Resource\",\"resource\":{\"name\":\"cpu\",\"target\":{\"type\":\"Utilization\",\"averageUtilization\":20}}}]}}'"
echo "2. Check HPA events: kubectl describe hpa portfolio-demo-hpa"
echo "3. Monitor with: kubectl get hpa -w"
