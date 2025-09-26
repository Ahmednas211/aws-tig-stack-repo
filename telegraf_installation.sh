#!/bin/bash
set -e

echo "======================================"
echo "  TELEGRAF INSTALLATION - AMAZON LINUX 2023"
echo "======================================"

# STEP 1: Add InfluxData repository with correct key
echo ""
echo "Setting up InfluxData repository..."

cat <<EOF | sudo tee /etc/yum.repos.d/influxdata.repo
[influxdata]
name = InfluxData Repository - Stable
baseurl = https://repos.influxdata.com/stable/\$basearch/main
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF

# Import GPG key
wget -q https://repos.influxdata.com/influxdata-archive_compat.key
sudo rpm --import influxdata-archive_compat.key
rm -f influxdata-archive_compat.key

# STEP 2: Install Telegraf
echo ""
echo "Installing Telegraf..."

sudo dnf clean all
sudo dnf makecache --refresh
sudo dnf install -y telegraf

# STEP 3: Create directories
echo ""
echo "Setting up directories..."

sudo mkdir -p /etc/telegraf
sudo mkdir -p /var/log/telegraf
sudo chown telegraf:telegraf /var/log/telegraf

# STEP 4: Verify installation
echo ""
echo "======================================"
echo "INSTALLATION COMPLETE"
echo "======================================"
echo ""
echo "Telegraf version:"
telegraf --version
echo ""
echo "Config directory: /etc/telegraf/"
echo "Log directory: /var/log/telegraf/"
echo ""
echo "Now run your instance setup script:"
echo "  ./setup-telegraf-instance.sh <instance-name>"
echo ""
