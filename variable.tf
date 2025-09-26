# variables.tf - Input variables for the monitoring stack deployment

# Project Configuration
variable "project_name" {
  description = "Name of the project for resource naming and tagging"
  type        = string
  default     = "monitoring"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "application_stack" {
  description = "Application stack name"
  type        = string
  default     = "metrics-processor"
}

# AWS Region Configuration
variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-2"
}

variable "availability_zone" {
  description = "Availability zone for deployment"
  type        = string
  default     = "us-east-2a"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "192.168.240.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "192.168.240.0/25"  # Half of VPC CIDR
}

# Security Configuration
variable "uhg_cidrs" {
  description = "UHG network CIDR blocks for secure access"
  type        = list(string)
  default     = []
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type for metrics processing (2000 devices)"
  type        = string
  default     = "m5.xlarge"  # 4 vCPU, 16 GB RAM for 2000 devices
}

variable "iam_instance_profile" {
  description = "IAM instance profile for EC2 instance"
  type        = string
  default     = "ec2-ssm-access-role"
}

# Storage Configuration for 2000 devices metrics
variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 50
}

variable "root_volume_type" {
  description = "Type of the root EBS volume"
  type        = string
  default     = "gp3"
}

variable "data_volume_size" {
  description = "Size of the data EBS volume in GB for metrics storage"
  type        = number
  default     = 500  # For 2000 devices metrics retention
}

variable "data_volume_type" {
  description = "Type of the data EBS volume"
  type        = string
  default     = "gp3"
}

variable "data_volume_iops" {
  description = "IOPS for data volume (gp3)"
  type        = number
  default     = 6000
}

variable "data_volume_throughput" {
  description = "Throughput in MiB/s for data volume (gp3)"
  type        = number
  default     = 250
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
