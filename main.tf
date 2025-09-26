# main.tf - Main configuration with providers and EC2 resources

# Terraform Configuration
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Data source for Optum Golden AMI
data "aws_ami" "optum_golden_ecs" {
  most_recent = true
  owners      = ["187829367669"]
  
  filter {
    name   = "name"
    values = ["optum/AmazonLinux_2023*"]
  }
}

# EC2 Instance for Monitoring
resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.optum_golden_ecs.id
  instance_type = var.instance_type
  
  # Network configuration
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.application.id]
  associate_public_ip_address = true
  
  # IAM role for SSM access
  iam_instance_profile = var.iam_instance_profile
  
  # Root volume configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
    
    tags = merge(
      local.common_tags,
      {
        Name = "${local.instance_name}-root"
        Type = "Root"
      }
    )
  }
  
  # Metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = local.instance_name
    }
  )
  
  lifecycle {
    ignore_changes = [ami]
  }
}

# Data Volume for Metrics Storage
resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = var.data_volume_size
  type              = var.data_volume_type
  iops              = var.data_volume_type == "gp3" ? var.data_volume_iops : null
  throughput        = var.data_volume_type == "gp3" ? var.data_volume_throughput : null
  encrypted         = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.instance_name}-data"
      Type = "Data"
    }
  )
}

# Attach Data Volume to Instance
resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.monitoring.id
  
  stop_instance_before_detaching = true
}
