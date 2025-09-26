# terraform.tfvars - Variable values for the monitoring stack deployment

# Project Identification
project_name      = "monitoring"
environment       = "prod"
application_stack = "metrics-processor"

# AWS Configuration
aws_region        = "us-east-2"
availability_zone = "us-east-2a"

# Network Configuration
vpc_cidr           = "192.168.240.0/24"
public_subnet_cidr = "192.168.240.0/25"

# Security Configuration - Update with your actual IPs
uhg_cidrs = [
  "10.0.0.0/8",      # Example: Corporate network
  "172.16.0.0/12",   # Example: VPN range
  "192.168.1.0/24"   # Example: Office network
]

# EC2 Instance Configuration for 2000 devices
instance_type        = "m5.xlarge"
iam_instance_profile = "ec2-ssm-access-role"

# Storage Configuration - Sized for 2000 device metrics
root_volume_size       = 50
root_volume_type       = "gp3"
data_volume_size       = 500
data_volume_type       = "gp3"
data_volume_iops       = 6000
data_volume_throughput = 250

# Additional Tags
additional_tags = {
  ManagedBy  = "Terraform"
  CostCenter = "Infrastructure"
  Purpose    = "MetricsProcessing"
}
