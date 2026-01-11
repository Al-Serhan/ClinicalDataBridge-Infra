# Data source for latest Amazon Linux 2 AMI
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

# Security Group for Private VM (only accepts connections from Bastion)
resource "aws_security_group" "private_vm" {
  name_prefix = "${var.project_name}-private-vm-sg-"
  description = "Security group for Private Data Processing VM - Bastion access only"
  vpc_id      = var.vpc_id

  # Inbound: SSH ONLY from Bastion Security Group
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_security_group]
    description     = "SSH from Bastion only (air-gapped)"
  }

  # Outbound: Allow all traffic (via NAT Gateway for secure internet access)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic via NAT Gateway"
  }

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-private-vm-sg-${var.environment}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Role for Private VM (for data processing, S3 access, etc.)
resource "aws_iam_role" "private_vm" {
  name_prefix = "${var.project_name}-private-vm-role-"

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
      Name = "${var.project_name}-private-vm-role-${var.environment}"
    }
  )
}

# IAM Policy for Private VM (CloudWatch logs, minimal S3/data access)
resource "aws_iam_role_policy" "private_vm" {
  name_prefix = "${var.project_name}-private-vm-policy-"
  role        = aws_iam_role.private_vm.id

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
        Resource = "arn:aws:logs:*:*:log-group:/clinicaldata/private-vm-${var.environment}:*"
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
      },
      {
        Sid    = "DecryptCMK"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        # Restrict to only the EBS encryption key used by this module
        Resource = var.enable_encryption ? aws_kms_key.ebs[0].arn : ""
      }
    ]
  })
}

# Instance Profile for Private VM
resource "aws_iam_instance_profile" "private_vm" {
  name_prefix = "${var.project_name}-private-vm-profile-"
  role        = aws_iam_role.private_vm.name
}

# CloudWatch Log Group for Private VM
resource "aws_cloudwatch_log_group" "private_vm" {
  name              = "/clinicaldata/private-vm-${var.environment}"
  retention_in_days = 30

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-private-vm-logs-${var.environment}"
    }
  )
}

# KMS Key for EBS encryption (for HIPAA compliance)
resource "aws_kms_key" "ebs" {
  count                   = var.enable_encryption ? 1 : 0
  description             = "KMS key for EBS encryption - ${var.project_name} ${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-ebs-key-${var.environment}"
    }
  )
}

resource "aws_kms_alias" "ebs" {
  count         = var.enable_encryption ? 1 : 0
  name          = "alias/${var.project_name}-ebs-${var.environment}"
  target_key_id = aws_kms_key.ebs[0].key_id
}

# Private VM EC2 Instance (NO PUBLIC IP - Air-gapped)
resource "aws_instance" "private_vm" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  iam_instance_profile        = aws_iam_instance_profile.private_vm.name
  key_name                    = var.ssh_key_name
  monitoring                  = var.enable_monitoring
  associate_public_ip_address = false  # CRITICAL: No public IP (air-gapped)
  vpc_security_group_ids      = [aws_security_group.private_vm.id]

  # Enable EBS encryption with customer-managed key
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 100  # Larger for data processing
    encrypted             = var.enable_encryption
    kms_key_id            = var.enable_encryption ? aws_kms_key.ebs[0].arn : null
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-private-vm-root-volume-${var.environment}"
    }
  }

  # Metadata endpoint security (IMDSv2 required)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  # User data for security hardening
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    log_group_name = aws_cloudwatch_log_group.private_vm.name
    environment    = var.environment
    project_name   = var.project_name
  }))

  tags = merge(
    var.compliance_tags,
    {
      Name             = "${var.project_name}-private-vm-${var.environment}"
      Role             = "DataProcessing"
      NetworkAccess    = "Restricted"
    }
  )

  depends_on = [aws_cloudwatch_log_group.private_vm]
}

# Additional encrypted EBS volume for sensitive data
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.private_vm.availability_zone
  size              = 50
  type              = "gp3"
  encrypted         = var.enable_encryption
  kms_key_id        = var.enable_encryption ? aws_kms_key.ebs[0].arn : null

  tags = merge(
    var.compliance_tags,
    {
      Name = "${var.project_name}-private-vm-data-volume-${var.environment}"
    }
  )
}

# Attach data volume to Private VM
resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.private_vm.id
}

# CloudWatch Alarm for Private VM status
resource "aws_cloudwatch_metric_alarm" "private_vm_status" {
  alarm_name          = "${var.project_name}-private-vm-status-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert when Private VM status check fails"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.private_vm.id
  }

  tags = var.compliance_tags
}

# CloudWatch Alarm for CPU utilization
resource "aws_cloudwatch_metric_alarm" "private_vm_cpu" {
  alarm_name          = "${var.project_name}-private-vm-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when CPU exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.private_vm.id
  }

  tags = var.compliance_tags
}
