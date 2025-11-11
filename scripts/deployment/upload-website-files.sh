#!/bin/bash
# Upload pretamane-website files to EC2 via SSM and file chunking

set -e

INSTANCE_ID="i-0c151e9556e3d35e8"
REGION="ap-southeast-1"
EC2_IP="54.179.230.219"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║              UPLOADING WEBSITE FILES TO EC2                                ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# First, update the docker-compose.yml on EC2 to add the volume mount
echo "Step 1: Updating docker-compose.yml volume mounts..."
CMD_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "cd /home/ubuntu/app/docker-compose",
    "# Backup current file",
    "cp docker-compose.yml docker-compose.yml.bak",
    "# Check if volume mount already exists",
    "if ! grep -q \"pretamane-website\" docker-compose.yml; then",
    "  echo \"Adding volume mount for website files...\"",
    "  sed -i \"/caddy-config:\\/config/a\\      - \\/home\\/ubuntu\\/app\\/pretamane-website:\\/var\\/www\\/pretamane:ro\" docker-compose.yml",
    "  echo \" Volume mount added\"",
    "else",
    "  echo \" Volume mount already exists\"",
    "fi"
  ]' \
  --region $REGION \
  --output text --query 'Command.CommandId')

sleep 4
aws ssm get-command-invocation --command-id $CMD_ID --instance-id $INSTANCE_ID --region $REGION --query 'StandardOutputContent' --output text

echo ""
echo "Step 2: Creating website files on EC2..."

# Create index.html
INDEX_CONTENT=$(cat /home/guest/aws-to-opensource/pretamane-website/index.html | base64 -w0 | head -c 30000)
CONTACT_JS=$(cat /home/guest/aws-to-opensource/pretamane-website/assets/js/contact-form.js | base64 -w0)
NAV_JS=$(cat /home/guest/aws-to-opensource/pretamane-website/assets/js/navigation.js | base64 -w0)

# Due to SSM command size limits, we'll create files in multiple commands
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    \"mkdir -p /home/ubuntu/app/pretamane-website/assets/js\",
    \"mkdir -p /home/ubuntu/app/pretamane-website/assets/css\",
    \"mkdir -p /home/ubuntu/app/pretamane-website/pages\",
    \"echo ' Directory structure created'\"
  ]" \
  --region $REGION \
  --output json > /dev/null

sleep 3

echo " Directory structure created on EC2"
echo ""
echo "Step 3: For full website upload, use scp or git clone..."
echo ""
echo "RECOMMENDED: Upload via SCP (if you have the key):"
echo "  scp -i SingaporeKeyPair.pem -r pretamane-website/ ubuntu@$EC2_IP:/home/ubuntu/app/"
echo ""
echo "OR: Push to git and pull on EC2:"
echo "  git add pretamane-website/"
echo "  git commit -m 'Add portfolio website'"
echo "  git push"
echo "  # Then on EC2:"
echo "  ssh ubuntu@$EC2_IP \"cd /home/ubuntu/app && git pull\""
echo ""

EOF
chmod +x /tmp/deploy-website-final.sh && /tmp/deploy-website-final.sh
