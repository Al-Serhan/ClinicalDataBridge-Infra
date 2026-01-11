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
# Wait for volume to attach with timeout and polling
TIMEOUT=60
ELAPSED=0
DEVICE=""

echo "Waiting for data volume to attach..."
while [ $ELAPSED -lt $TIMEOUT ]; do
  if [ -b /dev/nvme1n1 ]; then
    DEVICE=/dev/nvme1n1
    break
  elif [ -b /dev/xvdf ]; then
    DEVICE=/dev/xvdf
    break
  elif [ -b /dev/sdf ]; then
    DEVICE=/dev/sdf
    break
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo "Still waiting for volume... (${ELAPSED}s elapsed)"
done

if [ -z "$DEVICE" ]; then
  echo "ERROR: Data volume did not attach within ${TIMEOUT} seconds"
  exit 1
fi

echo "Data volume found at $DEVICE"

# Final verification that device is still a block device before operations
if [ ! -b "$DEVICE" ]; then
  echo "ERROR: Device $DEVICE is not a valid block device"
  exit 1
fi

echo "Verified $DEVICE is a valid block device, proceeding with setup..."

# Check if device already has a filesystem using blkid
# blkid returns exit code 2 if no filesystem is found
if ! blkid "$DEVICE" > /dev/null 2>&1; then
  echo "No existing filesystem detected, creating ext4 filesystem on $DEVICE..."
  mkfs -t ext4 "$DEVICE"
else
  FSTYPE=$(blkid -s TYPE -o value "$DEVICE" 2>/dev/null || echo "unknown")
  echo "Existing filesystem detected: $FSTYPE on $DEVICE"
fi

# Create mount point
mkdir -p /data

# Mount the device if not already mounted
if ! mountpoint -q /data; then
  mount $DEVICE /data
  echo "Mounted $DEVICE to /data"
else
  echo "/data is already mounted"
fi

# Add to fstab for persistent mounting using UUID (more reliable than device names)
# Check if this mount point is already in fstab to avoid duplicates
UUID=$(blkid -s UUID -o value $DEVICE)
if ! grep -qs "UUID=$UUID" /etc/fstab && ! grep -qs "/data" /etc/fstab; then
  echo "UUID=$UUID /data ext4 defaults,nofail 0 2" >> /etc/fstab
  echo "Added /data mount entry to /etc/fstab"
else
  echo "/data entry already exists in /etc/fstab, skipping"
fi

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
# Append to existing crontab without overwriting other entries
CRON_ENTRY="0 2 * * * /usr/local/bin/aide-check.sh"
if ! crontab -l 2>/dev/null | grep -qF "/usr/local/bin/aide-check.sh"; then
  (crontab -l 2>/dev/null || true; echo "$CRON_ENTRY") | crontab -
  echo "Added AIDE check to crontab"
else
  echo "AIDE check already exists in crontab, skipping"
fi

echo "Private VM hardening complete - PHI data security measures enabled"
