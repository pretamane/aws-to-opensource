#!/bin/bash
# Install and configure fail2ban for SSH protection

set -e

echo "=========================================="
echo "  fail2ban Installation"
echo "=========================================="
echo ""

# Install fail2ban
echo "[1/3] Installing fail2ban..."
sudo apt-get update
sudo apt-get install -y fail2ban

# Create local configuration
echo "[2/3] Configuring fail2ban for SSH protection..."
sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
# Ban hosts for 1 hour
bantime = 3600

# Monitor window: 10 minutes
findtime = 600

# Max retries before ban
maxretry = 5

# Email notifications (optional - set destemail)
# destemail = your-email@example.com
# sendername = Fail2Ban
# action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 10
bantime = 7200
EOF

# Enable and start fail2ban
echo "[3/3] Starting fail2ban..."
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo ""
echo "=========================================="
echo "  fail2ban Installation Complete!"
echo "=========================================="
echo ""
echo "Status:"
sudo fail2ban-client status

echo ""
echo "SSH jail status:"
sudo fail2ban-client status sshd 2>/dev/null || echo "SSH jail starting..."

echo ""
echo "=========================================="
echo "  Configuration Summary"
echo "=========================================="
echo "SSH Protection:"
echo "  - Max retries: 3"
echo "  - Ban time: 1 hour"
echo "  - Monitor window: 10 minutes"
echo ""
echo "Useful commands:"
echo "  - Status: sudo fail2ban-client status"
echo "  - SSH jail: sudo fail2ban-client status sshd"
echo "  - Unban IP: sudo fail2ban-client set sshd unbanip IP_ADDRESS"
echo "  - View logs: sudo tail -f /var/log/fail2ban.log"
echo ""
echo "fail2ban is now protecting your SSH service!"
echo ""



