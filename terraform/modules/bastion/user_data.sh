#!/bin/bash
set -e

# Bastion Security Hardening Script
# This script applies security best practices to the Bastion instance

# Configure CloudWatch Logs agent
yum install -y amazon-cloudwatch-agent

# System Updates
yum update -y

# Security Configurations
# Disable IPv6 if not needed
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

# Configure SSH Security
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
echo "Protocol 2" >> /etc/ssh/sshd_config

# Restart SSH
systemctl restart sshd

# Install Security Monitoring Tools
yum install -y amazon-ssm-agent amazon-cloudwatch-agent aide

# Initialize AIDE (Advanced Intrusion Detection Environment)
aideinit

# Enable CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/secure",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "/var/log/secure"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "/var/log/messages"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Create daily AIDE check
cat > /usr/local/bin/aide-check.sh << 'EOF'
#!/bin/bash
aide --check
EOF
chmod +x /usr/local/bin/aide-check.sh

# Add to crontab
echo "0 3 * * * /usr/local/bin/aide-check.sh" | crontab -

echo "Bastion hardening complete"
