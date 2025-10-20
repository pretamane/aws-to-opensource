# Terraform Variables for EC2 Deployment

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "pretamane-opensource"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"  # 2 vCPU, 4GB RAM - ~$30/month
  
  # Alternative options:
  # t3.small:  1 vCPU, 2GB RAM - ~$15/month (might be tight)
  # t3.large:  2 vCPU, 8GB RAM - ~$60/month (more headroom)
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "key_name" {
  description = "SSH key pair name (must exist in AWS)"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change to your IP: ["YOUR.IP.ADD.RESS/32"]
}

variable "use_elastic_ip" {
  description = "Whether to use Elastic IP for stable address"
  type        = bool
  default     = true  # Recommended for demos
}

variable "ses_from_email" {
  description = "SES from email address"
  type        = string
  default     = "noreply@demo-pretamane.com"
}

variable "ses_to_email" {
  description = "SES to email address"
  type        = string
  default     = "admin@demo-pretamane.com"
}

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}


