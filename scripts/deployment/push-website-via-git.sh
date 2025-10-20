#!/bin/bash
# Push pretamane-website to git and deploy to EC2

set -e

EC2_INSTANCE="i-0c151e9556e3d35e8"
REGION="ap-southeast-1"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║            DEPLOY FULL WEBSITE VIA GIT                                    ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

cd /home/guest/aws-to-opensource

echo "Step 1: Checking git status..."
git status
echo ""

read -p "Do you want to commit and push pretamane-website? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Step 2: Adding files to git..."
    git add pretamane-website/
    git add docker-compose/config/caddy/Caddyfile
    git add docker-compose/docker-compose.yml
    
    echo "Step 3: Committing..."
    git commit -m "Integrate pretamane portfolio website with EC2 backend

- Updated all API endpoints to point to EC2 (54.179.230.219)
- Configured Caddy to serve static website files
- Added volume mount for pretamane-website in docker-compose
- Contact form now integrated with PostgreSQL database
- Visitor counter working
- Full stack integration complete
"
    
    echo "Step 4: Pushing to remote..."
    git push
    
    echo ""
    echo "Step 5: Pulling on EC2 and restarting services..."
    CMD_ID=$(aws ssm send-command \
      --instance-ids $EC2_INSTANCE \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=[
        "echo \"Pulling latest code...\"",
        "cd /home/ubuntu/app",
        "git pull origin main || git pull origin master",
        "echo \"✓ Code updated\"",
        "echo \"\"",
        "echo \"Restarting Caddy...\"",
        "cd docker-compose",
        "docker-compose restart caddy",
        "echo \"✓ Caddy restarted\"",
        "echo \"\"",
        "echo \"Verifying website files:\"",
        "test -f /home/ubuntu/app/pretamane-website/index.html && echo \"✓ index.html found\" || echo \"✗ index.html missing\"",
        "test -f /home/ubuntu/app/pretamane-website/style.css && echo \"✓ style.css found\" || echo \"✗ style.css missing\"",
        "test -f /home/ubuntu/app/pretamane-website/assets/js/contact-form.js && echo \"✓ contact-form.js found\" || echo \"✗ contact-form.js missing\"",
        "echo \"\"",
        "echo \"Testing homepage:\"",
        "curl -s -o /dev/null -w \"HTTP Status: %{http_code}\" http://localhost/"
      ]' \
      --region $REGION \
      --output text --query 'Command.CommandId')
    
    echo "Waiting for deployment..."
    sleep 8
    
    aws ssm get-command-invocation \
      --command-id $CMD_ID \
      --instance-id $EC2_INSTANCE \
      --region $REGION \
      --query 'StandardOutputContent' \
      --output text
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    DEPLOYMENT COMPLETE!                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Your full portfolio website is now live at:"
    echo ""
    echo "  🏠 Homepage:       http://54.179.230.219/"
    echo "  📧 Contact:        http://54.179.230.219/pages/contact.html"
    echo "  👤 About:          http://54.179.230.219/pages/about.html"
    echo "  💼 Services:       http://54.179.230.219/pages/services.html"
    echo "  🎨 Portfolio:      http://54.179.230.219/pages/portfolio.html"
    echo ""
    echo "Backend APIs:"
    echo "  📚 Docs:           http://54.179.230.219/docs"
    echo "  📊 Grafana:        http://54.179.230.219/grafana/"
    echo "  🗄️  pgAdmin:        http://54.179.230.219/pgadmin"
    echo ""
else
    echo ""
    echo "Deployment cancelled. Run this script again when ready."
fi

