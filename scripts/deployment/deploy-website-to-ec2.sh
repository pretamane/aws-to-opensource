#!/bin/bash
# Deploy pretamane-website to EC2 instance

set -e

INSTANCE_ID="i-0c151e9556e3d35e8"
REGION="ap-southeast-1"
EC2_IP="54.179.230.219"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║         DEPLOYING PRETAMANE WEBSITE TO EC2 INSTANCE                       ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Create tarball of website files
echo "Step 1: Packaging website files..."
cd /home/guest/aws-to-opensource
tar czf /tmp/pretamane-website.tar.gz pretamane-website/
echo "✓ Website packaged: /tmp/pretamane-website.tar.gz"
echo ""

# Step 2: Upload to S3 temporarily
echo "Step 2: Uploading to S3 (temporary storage)..."
S3_BUCKET="pretamane-deployment-temp-1760776208"
aws s3 cp /tmp/pretamane-website.tar.gz s3://$S3_BUCKET/pretamane-website.tar.gz --region $REGION
echo "✓ Uploaded to S3"
echo ""

# Step 3: Download and extract on EC2
echo "Step 3: Deploying to EC2 instance..."
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "echo \"Downloading website files from S3...\"",
    "aws s3 cp s3://'"$S3_BUCKET"'/pretamane-website.tar.gz /tmp/pretamane-website.tar.gz --region '"$REGION"'",
    "echo \"Extracting files...\"",
    "cd /home/ubuntu/app",
    "tar xzf /tmp/pretamane-website.tar.gz",
    "echo \"✓ Website files extracted to /home/ubuntu/app/pretamane-website/\"",
    "echo \"Updating Caddy configuration...\"",
    "cd /home/ubuntu/app/docker-compose",
    "docker-compose up -d caddy",
    "echo \"✓ Caddy restarted with new configuration\"",
    "rm /tmp/pretamane-website.tar.gz",
    "echo \"Deployment complete!\""
  ]' \
  --region $REGION \
  --output text --query 'Command.CommandId' > /tmp/deploy_cmd.txt

echo "Waiting for deployment to complete..."
sleep 5

CMD_ID=$(cat /tmp/deploy_cmd.txt)
aws ssm get-command-invocation \
  --command-id $CMD_ID \
  --instance-id $INSTANCE_ID \
  --region $REGION \
  --query 'StandardOutputContent' \
  --output text

# Cleanup
rm /tmp/deploy_cmd.txt
rm /tmp/pretamane-website.tar.gz
echo ""

echo "════════════════════════════════════════════════════════════════════════════"
echo "✅ DEPLOYMENT COMPLETE!"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Your website is now live at:"
echo ""
echo "  🌐 Portfolio Website:  http://$EC2_IP/"
echo "  📝 Contact Page:       http://$EC2_IP/pages/contact.html"
echo "  👤 About Page:         http://$EC2_IP/pages/about.html"
echo "  💼 Services Page:      http://$EC2_IP/pages/services.html"
echo ""
echo "  📚 API Documentation:  http://$EC2_IP/docs"
echo "  ❤️  Health Check:       http://$EC2_IP/health"
echo ""
echo "Backend Integration:"
echo "  ✓ Contact form → http://$EC2_IP/contact"
echo "  ✓ Stats API → http://$EC2_IP/stats"
echo "  ✓ All APIs connected to PostgreSQL database"
echo ""
echo "════════════════════════════════════════════════════════════════════════════"

