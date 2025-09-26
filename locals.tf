# locals.tf - Local values for resource naming and tagging

locals {
  # Naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Resource names
  vpc_name          = "${local.name_prefix}-vpc"
  subnet_name       = "${local.name_prefix}-public-subnet"
  igw_name          = "${local.name_prefix}-igw"
  route_table_name  = "${local.name_prefix}-public-rt"
  sg_name           = "${local.name_prefix}-app-sg"
  instance_name     = "${local.name_prefix}-${var.application_stack}"
  
  # Common tags
  common_tags = merge(
    {
      Project          = var.project_name
      Environment      = var.environment
      ApplicationStack = var.application_stack
      Terraform        = "true"
      ManagedBy        = "Terraform"
    },
    var.additional_tags
  )
  
  # Determine ingress CIDR blocks
  ingress_cidr_blocks = length(var.uhg_cidrs) > 0 ? var.uhg_cidrs : ["0.0.0.0/0"]
}
