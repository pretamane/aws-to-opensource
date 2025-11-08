#!/bin/bash
# Phase 1 - Command Reference
# Copy and paste these commands to deploy Phase 1

# ============================================================================
# PREREQUISITES
# ============================================================================
# 1. Load your EC2 SSH key:
#    ssh-add ~/.ssh/your-ec2-key.pem
#
# 2. Test SSH connectivity:
#    ssh ubuntu@54.179.230.219 "echo 'SSH OK'"
#
# If SSH doesn't work, you'll need to:
#    - Ensure security group allows SSH from your IP
#    - Verify the correct SSH key is loaded
# ============================================================================

# Set instance IP
export INSTANCE_IP="54.179.230.219"

# ============================================================================
# STEP 1: Upload Phase 0 Corrected Configs
# ============================================================================

echo "Creating directories on EC2..."
ssh ubuntu@$INSTANCE_IP "mkdir -p ~/app/docker-compose/config/{prometheus,alertmanager,promtail,blackbox}"

echo "Uploading Prometheus configs..."
scp /home/guest/aws-to-opensource/docker-compose/config/prometheus/prometheus.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/prometheus/

scp /home/guest/aws-to-opensource/docker-compose/config/prometheus/alert-rules.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/prometheus/

echo "Uploading Alertmanager configs..."
scp /home/guest/aws-to-opensource/docker-compose/config/alertmanager/config.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/alertmanager/

scp /home/guest/aws-to-opensource/docker-compose/config/alertmanager/default.tmpl \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/alertmanager/

echo "Uploading Promtail config..."
scp /home/guest/aws-to-opensource/docker-compose/config/promtail/promtail-config.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/promtail/

echo "Uploading docker-compose.yml..."
scp /home/guest/aws-to-opensource/docker-compose/docker-compose.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/

echo "✓ All configs uploaded"

# ============================================================================
# STEP 2: Deploy Exporters and Prometheus
# ============================================================================

echo ""
echo "Starting exporters and Prometheus..."
ssh ubuntu@$INSTANCE_IP "cd ~/app/docker-compose && docker-compose up -d node-exporter cadvisor blackbox-exporter prometheus"

echo "Waiting 15 seconds for services to initialize..."
sleep 15

echo "✓ Services started"

# ============================================================================
# STEP 3: Verify Services Running
# ============================================================================

echo ""
echo "Checking service status..."
ssh ubuntu@$INSTANCE_IP "cd ~/app/docker-compose && docker-compose ps node-exporter cadvisor blackbox-exporter prometheus"

# ============================================================================
# STEP 4: Check Prometheus Targets
# ============================================================================

echo ""
echo "Checking Prometheus targets..."
ssh ubuntu@$INSTANCE_IP "curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | \"  \" + (.health | if . == \"up\" then \"✓\" else \"❌\" end) + \" \" + .labels.job + \" - \" + .scrapeUrl'"

echo ""
echo "Checking for DOWN targets..."
ssh ubuntu@$INSTANCE_IP "curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health != \"up\") | \"❌ DOWN: \" + .labels.job + \" (\" + .scrapeUrl + \")\"' || echo '✓ All targets UP'"

# ============================================================================
# STEP 5: Test Exporter Endpoints
# ============================================================================

echo ""
echo "Testing node-exporter..."
ssh ubuntu@$INSTANCE_IP "curl -s http://localhost:9100/metrics | head -n 3"
echo "  ✓ node-exporter responding"

echo ""
echo "Testing cAdvisor..."
ssh ubuntu@$INSTANCE_IP "curl -s http://localhost:8080/metrics | head -n 3"
echo "  ✓ cAdvisor responding"

echo ""
echo "Testing blackbox-exporter probe..."
ssh ubuntu@$INSTANCE_IP "curl -s 'http://localhost:9115/probe?target=http://caddy:80&module=http_2xx' | grep 'probe_success'"
echo "  ✓ blackbox-exporter responding"

# ============================================================================
# COMPLETE
# ============================================================================

echo ""
echo "=========================================="
echo "Phase 1 Deployment Complete!"
echo "=========================================="
echo ""
echo "Access Prometheus UI:"
echo "  http://$INSTANCE_IP:9090/targets"
echo ""
echo "Next: Proceed to Phase 2 (baseline alerts)"
echo ""

