#!/bin/bash
# Device Availability Ping Monitor Installation for Amazon Linux 2023
# Usage:
# sudo ./install-ping-monitor.sh
# sudo vim /etc/telegraf/device_availability.conf
# telegraf --config /etc/telegraf/device_availability.conf --test
# sudo systemctl start device-availability
# sudo systemctl enable device-availability
# sudo systemctl status device-availability
# sudo journalctl -u device-availability -f
# # Check memory usage
# ps aux | grep device_availability | awk '{print $6/1024 " MB"}'
# # Check CPU usage  
# top -b -n 1 | grep telegraf

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Run as root or with sudo"
   exit 1
fi

echo "======================================"
echo "Installing Device Availability Monitor"
echo "   Amazon Linux 2023 Compatible"
echo "======================================"

# Install Telegraf if not present
if ! command -v telegraf &> /dev/null; then
    echo "Installing Telegraf..."
    
    # Setup InfluxData repository with correct key for AL2023
    cat <<EOF | tee /etc/yum.repos.d/influxdata.repo
[influxdata]
name = InfluxData Repository - Stable
baseurl = https://repos.influxdata.com/stable/\$basearch/main
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF

    # Import GPG key
    wget -q https://repos.influxdata.com/influxdata-archive_compat.key
    rpm --import influxdata-archive_compat.key
    rm -f influxdata-archive_compat.key
    
    # Clean and install
    dnf clean all
    dnf makecache --refresh
    dnf install -y telegraf
    
    echo "✓ Telegraf installed"
else
    echo "✓ Telegraf already installed"
fi

# Set native ping capability
echo "Setting ping capabilities..."
setcap cap_net_raw=eip /usr/bin/telegraf

# Create directories with proper permissions
echo "Creating directories..."
mkdir -p /etc/telegraf
mkdir -p /var/log/telegraf

# Fix log directory permissions
chown -R telegraf:telegraf /var/log/telegraf
chmod 755 /var/log/telegraf

# Create config file with proper permissions
CONF_FILE="/etc/telegraf/device_availability.conf"
touch "$CONF_FILE"
chmod 644 "$CONF_FILE"
chown telegraf:telegraf "$CONF_FILE"
echo "✓ Config file created: $CONF_FILE"

# Fix any existing log files
if [[ -f "/var/log/telegraf/device_availability.log" ]]; then
    chown telegraf:telegraf "/var/log/telegraf/device_availability.log"
    chmod 644 "/var/log/telegraf/device_availability.log"
fi

# System limits - check if already exists before adding
echo "Configuring system limits..."
if ! grep -q "telegraf soft nofile" /etc/security/limits.conf; then
    cat >> /etc/security/limits.conf <<EOF

# Telegraf limits for device availability monitoring
telegraf soft nofile 524288
telegraf hard nofile 524288
telegraf soft nproc 65536
telegraf hard nproc 65536
EOF
    echo "✓ System limits configured"
else
    echo "✓ System limits already configured"
fi

# Network tuning for Amazon Linux 2023
echo "Applying network tuning..."
sysctl -w net.core.rmem_default=134217728
sysctl -w net.core.wmem_default=134217728
sysctl -w net.ipv4.icmp_ratelimit=10000
sysctl -w net.ipv4.ping_group_range="0 2147483647"

# Make sysctl settings persistent
if ! grep -q "net.ipv4.icmp_ratelimit" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf <<EOF

# Telegraf ping monitoring optimizations
net.core.rmem_default=134217728
net.core.wmem_default=134217728
net.ipv4.icmp_ratelimit=10000
net.ipv4.ping_group_range=0 2147483647
EOF
fi

# Apply sysctl settings
sysctl -p

echo "✓ Network tuning applied"

# Create systemd service with AL2023 compatibility
echo "Creating systemd service..."
cat > /etc/systemd/system/device-availability.service <<'EOF'
[Unit]
Description=Device Availability Monitoring
Documentation=https://github.com/influxdata/telegraf
After=network.target

[Service]
Type=notify
User=telegraf
Group=telegraf
ExecStart=/usr/bin/telegraf --config /etc/telegraf/device_availability.conf
Restart=on-failure
RestartSec=60s
StartLimitInterval=0

# Resource Limits
LimitNOFILE=524288
LimitNPROC=65536
MemoryMax=8G
TimeoutStartSec=600

# Capabilities for ping
CapabilityBoundingSet=CAP_NET_RAW
AmbientCapabilities=CAP_NET_RAW

# Environment
Environment="GOMAXPROCS=8"
Environment="LD_LIBRARY_PATH=/usr/lib64"

# Amazon Linux 2023 specific
PrivateDevices=no
ProtectSystem=no

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/device-availability.service
systemctl daemon-reload

echo "✓ Systemd service created"

echo ""
echo "======================================"
echo "     INSTALLATION COMPLETE!"
echo "======================================"
echo ""
echo "Config file: $CONF_FILE"
echo "Service: device-availability"
echo ""
echo "Next steps:"
echo "1. Edit config:  sudo vim $CONF_FILE"
echo "2. Test config:  telegraf --config $CONF_FILE --test"
echo "3. Start service: sudo systemctl start device-availability"
echo "4. Enable boot:  sudo systemctl enable device-availability"
echo "5. Check status: sudo systemctl status device-availability"
echo "6. View logs:    sudo journalctl -u device-availability -f"
echo ""
