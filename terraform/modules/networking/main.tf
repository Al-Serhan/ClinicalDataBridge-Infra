# Terraform configuration for Networking module
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-vpc-${var.environment}"
    }
  )
}

# Enable VPC Flow Logs for audit trail (HIPAA requirement)
resource "aws_flow_log" "vpc" {
  count                   = var.enable_flow_logs ? 1 : 0
  iam_role_arn            = aws_iam_role.flow_logs[0].arn
  log_destination         = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type            = "ALL"
  vpc_id                  = aws_vpc.main.id
  log_destination_type    = "cloud-watch-logs"
  log_format              = "$${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${windowstart} $${windowend} $${action} $${tcpflags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${vpc-id} $${flow-logs-id} $${traffic-type} $${subnet-id} $${instance-id} $${interface-id} $${account-id}"

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-flow-logs-${var.environment}"
    }
  )
}

# CloudWatch Log Group for VPC Flow Logs
# HIPAA requires audit logs retained for 6 years
# CloudWatch retention: 365 days for active monitoring
# TODO: Configure S3 archival with lifecycle policies for long-term retention (6+ years)
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${var.project_name}-${var.environment}"
  retention_in_days = 365

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-flow-logs-${var.environment}"
    }
  )
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.project_name}-vpc-flow-logs-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-flow-logs-role-${var.environment}"
    }
  )
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.project_name}-vpc-flow-logs-policy-${var.environment}"
  role  = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/vpc/flowlogs/*"
      }
    ]
  })
}

# Public Subnet for Bastion
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-public-subnet-${var.environment}"
      Type = "Public"
    }
  )
}

# Private Subnet for Data Processing VM
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-private-subnet-${var.environment}"
      Type = "Private"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-igw-${var.environment}"
    }
  )
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-nat-eip-${var.environment}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway (for Private VM secure internet access)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-nat-${var.environment}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-public-rt-${var.environment}"
    }
  )
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-private-rt-${var.environment}"
    }
  )
}

# Private Route Table Association
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Group for Public Subnet (Bastion)
resource "aws_security_group" "public" {
  name_prefix = "${var.project_name}-public-sg-"
  description = "Security group for Bastion in public subnet"
  vpc_id      = aws_vpc.main.id

  # Outbound: Allow all traffic (for updates, library downloads)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-public-sg-${var.environment}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Private Subnet (Data Processing VM)
resource "aws_security_group" "private" {
  name_prefix = "${var.project_name}-private-sg-"
  description = "Security group for Private VM in private subnet"
  vpc_id      = aws_vpc.main.id

  # Outbound: Allow all traffic (for NAT Gateway access)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic via NAT"
  }

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-private-sg-${var.environment}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
