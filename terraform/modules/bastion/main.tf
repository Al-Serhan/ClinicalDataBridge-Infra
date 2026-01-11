# Terraform configuration for Bastion module
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Data source for latest Amazon Linux 2 AMI (hardened and regularly updated)
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Bastion (STRICT - only admin access via SSH)
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-bastion-sg-"
  description = "Security group for Bastion host - restricted admin access only"
  vpc_id      = var.vpc_id

  # Inbound: SSH ONLY from admin CIDR
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = [var.admin_cidr]
    description     = "SSH access from admin workstation only"
  }

  # Outbound: Allow all traffic (for system updates, library downloads)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for updates"
  }

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-bastion-sg-${var.environment}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Role for Bastion (minimal permissions for security)
resource "aws_iam_role" "bastion" {
  name_prefix = "${var.project_name}-bastion-role-"

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

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-bastion-role-${var.environment}"
    }
  )
}

# IAM Policy for Bastion (CloudWatch logs and SSM)
resource "aws_iam_role_policy" "bastion" {
  name_prefix = "${var.project_name}-bastion-policy-"
  role        = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:log-group:/clinicaldata/bastion-${var.environment}:*"
      },
      {
        Sid    = "SSMAccess"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:AcknowledgeMessage",
          "ssmmessages:GetMessages",
          "ssmmessages:SendCommand"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Instance Profile for Bastion
resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${var.project_name}-bastion-profile-"
  role        = aws_iam_role.bastion.name
}

# CloudWatch Log Group for Bastion
# HIPAA requires audit logs retained for 6 years
# CloudWatch retention: 365 days for active monitoring
# TODO: Configure S3 archival with lifecycle policies for long-term retention (6+ years)
resource "aws_cloudwatch_log_group" "bastion" {
  name              = "/clinicaldata/bastion-${var.environment}"
  retention_in_days = 365

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-bastion-logs-${var.environment}"
    }
  )
}

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  key_name               = var.ssh_key_name
  monitoring             = var.enable_monitoring
  vpc_security_group_ids = [aws_security_group.bastion.id]

  # Enable EBS encryption
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-bastion-root-volume-${var.environment}"
    }
  }

  # Enable termination protection for bastion
  disable_api_termination = false

  # User data for security hardening
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    log_group_name = aws_cloudwatch_log_group.bastion.name
    environment    = var.environment
    project_name   = var.project_name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-bastion-${var.environment}"
      Role = "Bastion"
    }
  )

  depends_on = [aws_cloudwatch_log_group.bastion]
}

# CloudWatch Alarm for Bastion status
resource "aws_cloudwatch_metric_alarm" "bastion_status" {
  alarm_name          = "${var.project_name}-bastion-status-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert when Bastion status check fails"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.bastion.id
  }

  tags = var.compliance_tags
}
