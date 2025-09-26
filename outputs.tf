# outputs.tf - Output values for the monitoring stack deployment

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# Subnet Output
output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "CIDR block of the public subnet"
  value       = aws_subnet.public.cidr_block
}

# Security Group Output
output "security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.application.id
}

# EC2 Instance Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.monitoring.id
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.monitoring.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.monitoring.public_ip
}

output "elastic_ip" {
  description = "Elastic IP address attached to the instance"
  value       = aws_eip.instance.public_ip
}

# Volume Outputs
output "data_volume_id" {
  description = "ID of the data volume"
  value       = aws_ebs_volume.data.id
}

output "data_volume_device" {
  description = "Device name for the data volume"
  value       = aws_volume_attachment.data.device_name
}

# AMI Information
output "ami_id" {
  description = "ID of the AMI used for the instance"
  value       = data.aws_ami.optum_golden_ecs.id
}

output "ami_name" {
  description = "Name of the AMI used for the instance"
  value       = data.aws_ami.optum_golden_ecs.name
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of the deployed configuration"
  value = {
    project_name      = var.project_name
    environment       = var.environment
    application_stack = var.application_stack
    instance_type     = var.instance_type
    data_volume_size  = "${var.data_volume_size} GB"
    region            = var.aws_region
    availability_zone = var.availability_zone
  }
}
