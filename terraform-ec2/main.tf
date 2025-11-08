# Terraform Configuration for EC2-Only Deployment
# Replaces expensive EKS cluster with single EC2 instance

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# ============================================================================
# VPC AND NETWORKING
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet"
    Project = var.project_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ============================================================================
# SECURITY GROUPS
# ============================================================================

resource "aws_security_group" "app_server" {
  name        = "${var.project_name}-app-server-sg"
  description = "Security group for application server"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # MinIO Console (direct access)
  ingress {
    from_port   = 9001
    to_port     = 9001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MinIO Console"
  }

  # SSH (restrict to your IP in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
    description = "SSH from allowed IPs"
  }

  # Outbound - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name    = "${var.project_name}-app-server-sg"
    Project = var.project_name
  }
}

# ============================================================================
# IAM ROLE FOR EC2 (SES Access Only)
# ============================================================================

resource "aws_iam_role" "ec2_app_role" {
  name = "${var.project_name}-ec2-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ec2-app-role"
    Project = var.project_name
  }
}

# SES sending permissions
resource "aws_iam_role_policy" "ses_send_policy" {
  name = "${var.project_name}-ses-send-policy"
  role = aws_iam_role.ec2_app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:GetSendQuota"
        ]
        Resource = "*"
      }
    ]
  })
}

# S3 access for deployment and backups
resource "aws_iam_role_policy" "s3_access_policy" {
  name = "${var.project_name}-s3-access-policy"
  role = aws_iam_role.ec2_app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::pretamane-*/*",
          "arn:aws:s3:::pretamane-*"
        ]
      }
    ]
  })
}

# CloudWatch logs (optional - for system logs)
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# SSM access for Session Manager (no SSH key needed)
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_server" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_app_role.name

  tags = {
    Name    = "${var.project_name}-ec2-profile"
    Project = var.project_name
  }
}

# ============================================================================
# ELASTIC IP (Optional - for stable IP)
# ============================================================================

resource "aws_eip" "app_server" {
  count    = var.use_elastic_ip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.app_server.id

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# EC2 INSTANCE
# ============================================================================

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.app_server.id]
  iam_instance_profile   = aws_iam_instance_profile.app_server.name

  key_name = var.key_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name    = "${var.project_name}-root-volume"
      Project = var.project_name
    }
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    project_name  = var.project_name
    aws_region    = var.region
    ses_from_email = var.ses_from_email
    ses_to_email   = var.ses_to_email
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  monitoring = true

  tags = {
    Name        = "${var.project_name}-app-server"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Role        = "application-server"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IP address"
  value       = var.use_elastic_ip ? aws_eip.app_server[0].public_ip : aws_instance.app_server.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name"
  value       = aws_instance.app_server.public_dns
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${var.use_elastic_ip ? aws_eip.app_server[0].public_ip : aws_instance.app_server.public_ip}"
}

output "application_url" {
  description = "Application URL"
  value       = "http://${var.use_elastic_ip ? aws_eip.app_server[0].public_ip : aws_instance.app_server.public_ip}"
}

output "api_docs_url" {
  description = "API documentation URL"
  value       = "http://${var.use_elastic_ip ? aws_eip.app_server[0].public_ip : aws_instance.app_server.public_ip}/docs"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${var.use_elastic_ip ? aws_eip.app_server[0].public_ip : aws_instance.app_server.public_ip}/grafana"
}

output "meilisearch_url" {
  description = "Meilisearch console URL"
  value       = "http://${var.use_elastic_ip ? aws_eip.app_server[0].public_ip : aws_instance.app_server.public_ip}/meilisearch"
}

output "minio_console_url" {
  description = "MinIO console URL"
  value       = "http://${var.use_elastic_ip ? aws_eip.app_server[0].public_ip : aws_instance.app_server.public_ip}/minio"
}

output "ssm_connect_command" {
  description = "AWS Systems Manager Session Manager command"
  value       = "aws ssm start-session --target ${aws_instance.app_server.id} --region ${var.region}"
}




