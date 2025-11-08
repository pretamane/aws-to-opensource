#!/bin/bash
# Install CrowdSec + Firewall Bouncer for IP-based threat protection
# Parses Caddy logs and auto-bans malicious IPs via nftables

set -e

echo "=========================================="
echo "  CrowdSec Installation"
echo "=========================================="
echo "This will install:"
echo "  - CrowdSec Security Engine"
echo "  - Firewall Bouncer (nftables)"
echo "  - Caddy collection (log parser)"
echo ""

# Check if running on Ubuntu/Debian
if [ ! -f /etc/debian_version ]; then
    echo "ERROR: This script is for Ubuntu/Debian systems only"
    exit 1
fi

# Add CrowdSec repository
echo "[1/6] Adding CrowdSec repository..."
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash

# Install CrowdSec
echo "[2/6] Installing CrowdSec..."
sudo apt-get update
sudo apt-get install -y crowdsec

# Install firewall bouncer
echo "[3/6] Installing CrowdSec Firewall Bouncer (nftables)..."
sudo apt-get install -y crowdsec-firewall-bouncer-nftables

# Install Caddy collection
echo "[4/6] Installing Caddy collection for log parsing..."
sudo cscli collections install crowdsecurity/caddy

# Configure Caddy log acquisition
echo "[5/6] Configuring Caddy log acquisition..."
sudo tee /etc/crowdsec/acquis.yaml > /dev/null <<EOF
---
# Caddy access logs from Docker volume
filenames:
  - /var/lib/docker/volumes/docker-compose_caddy-logs/_data/access.log
labels:
  type: caddy

# Caddy access logs (if mounted to host)
filenames:
  - /var/log/caddy/access.log
labels:
  type: caddy

# SSH logs
filenames:
  - /var/log/auth.log
labels:
  type: syslog

# System logs
filenames:
  - /var/log/syslog
labels:
  type: syslog
EOF

# Restart CrowdSec to apply configuration
echo "[6/6] Restarting CrowdSec..."
sudo systemctl restart crowdsec
sudo systemctl enable crowdsec
sudo systemctl restart crowdsec-firewall-bouncer
sudo systemctl enable crowdsec-firewall-bouncer

echo ""
echo "=========================================="
echo "  CrowdSec Installation Complete!"
echo "=========================================="
echo ""
echo "Status:"
sudo cscli metrics

echo ""
echo "Installed collections:"
sudo cscli collections list

echo ""
echo "Hub scenarios:"
sudo cscli scenarios list | head -20

echo ""
echo "=========================================="
echo "  Next Steps"
echo "=========================================="
echo "1. Check CrowdSec is running:"
echo "   sudo systemctl status crowdsec"
echo ""
echo "2. View decisions (banned IPs):"
echo "   sudo cscli decisions list"
echo ""
echo "3. View alerts:"
echo "   sudo cscli alerts list"
echo ""
echo "4. Monitor logs:"
echo "   sudo tail -f /var/log/crowdsec.log"
echo ""
echo "5. Test ban:"
echo "   sudo cscli decisions add --ip YOUR_IP --duration 4h --reason 'test'"
echo ""
echo "6. Remove ban:"
echo "   sudo cscli decisions delete --ip YOUR_IP"
echo ""
echo "CrowdSec will automatically:"
echo "  - Parse Caddy logs for attack patterns"
echo "  - Detect SSH brute force attempts"
echo "  - Ban malicious IPs via nftables"
echo "  - Share threat intel with community"
echo ""



