#!/bin/bash
set -e

# Private VM Security Hardening Script
# This instance processes PHI data - maximum security is critical

# System Updates
yum update -y

# Install Security Tools
yum install -y amazon-cloudwatch-agent amazon-ssm-agent aide openssl

# Configure SELinux (extra security for data processing)
# Note: SELinux is not enabled by default on Amazon Linux 2, but can be enforced if needed

# Security Configurations
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.conf
sysctl -p

# Configure SSH Security (no password auth, key-based only)
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config

systemctl restart sshd

# Mount and format encrypted data volume
# Wait for volume to attach
sleep 5

if [ -b /dev/nvme1n1 ]; then
  DEVICE=/dev/nvme1n1
elif [ -b /dev/xvdf ]; then
  DEVICE=/dev/xvdf
else
  DEVICE=/dev/sdf
fi

# Create partition if it doesn't exist
if ! sudo parted -s $DEVICE print | grep -q "Partition Table"; then
  sudo parted -s $DEVICE mklabel gpt
fi

# Create filesystem if not already present
if ! sudo blkid $DEVICE || ! sudo blkid $DEVICE | grep -q "TYPE"; then
  sudo mkfs -t ext4 $DEVICE
fi

# Create mount point
mkdir -p /data
mount $DEVICE /data

# Add to fstab for persistent mounting using UUID (more reliable than device names)
echo "UUID=$(blkid -s UUID -o value $DEVICE) /data ext4 defaults,nofail 0 2" >> /etc/fstab

# Set secure permissions on data directory
chmod 750 /data

# Initialize AIDE (Intrusion Detection)
aideinit

# Configure CloudWatch Agent
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
          },
          {
            "file_path": "/var/log/audit/audit.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "/var/log/audit/audit.log"
          }
        ]
      }
    },
    "force_flush_interval": 15
  }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Create audit script for file integrity monitoring
cat > /usr/local/bin/aide-check.sh << 'EOF'
#!/bin/bash
aide --check > /tmp/aide-report.txt 2>&1 || true
EOF
chmod +x /usr/local/bin/aide-check.sh

# Schedule daily file integrity checks
echo "0 2 * * * /usr/local/bin/aide-check.sh" | crontab -

echo "Private VM hardening complete - PHI data security measures enabled"
