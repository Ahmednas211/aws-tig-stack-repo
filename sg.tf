# security_group.tf - Security group configuration

# Application Security Group
resource "aws_security_group" "application" {
  name        = local.sg_name
  description = "Security group for monitoring application"
  vpc_id      = aws_vpc.main.id
  
  # HTTPS ingress from allowed CIDRs
  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.ingress_cidr_blocks
  }
  
  # Egress - Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = local.sg_name
    }
  )
  
  lifecycle {
    create_before_destroy = true
  }
}
