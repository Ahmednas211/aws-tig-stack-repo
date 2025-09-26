#!/bin/bash
set -e

# Usage: ./setup-telegraf-instance.sh snmp-1-telegraf
# Example: ./setup-telegraf-instance.sh snmp-telegraf
# Edit .conf file
# telegraf --config /etc/telegraf/snmp-1-telegraf.conf --test
# sudo systemctl start snmp-1-telegraf
# sudo systemctl enable snmp-1-telegraf
# sudo systemctl status snmp-1-telegraf
# sudo journalctl -u snmp-1-telegraf

INSTANCE_NAME="$1"

if [[ -z "$INSTANCE_NAME" ]]; then
    echo "Usage: $0 <instance-name>"
    exit 1
fi

echo "======================================"
echo "  SETTING UP TELEGRAF INSTANCE: $INSTANCE_NAME"
echo "======================================"

TELEGRAF_DIR="/etc/telegraf"
CONF_FILE="$TELEGRAF_DIR/${INSTANCE_NAME}.conf"
SERVICE_FILE="/etc/systemd/system/${INSTANCE_NAME}.service"

# STEP 1: Ensure config file exists
echo ""
echo "STEP 1: Checking config file..."

mkdir -p "$TELEGRAF_DIR"

if [[ ! -f "$CONF_FILE" ]]; then
    touch "$CONF_FILE"
    chmod 644 "$CONF_FILE"
    chown telegraf:telegraf "$CONF_FILE"
    echo "✓ Created empty config file: $CONF_FILE"
else
    echo "✓ Config file already exists: $CONF_FILE"
    # Fix permissions on existing file
    chmod 644 "$CONF_FILE"
    chown telegraf:telegraf "$CONF_FILE"
fi

# STEP 2: Create systemd service
echo ""
echo "STEP 2: Creating systemd service..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Telegraf Instance: $INSTANCE_NAME
Documentation=https://github.com/influxdata/telegraf
After=network.target

[Service]
EnvironmentFile=-/etc/default/telegraf
User=telegraf
ExecStart=/usr/bin/telegraf --config $CONF_FILE
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartForceExitStatus=SIGPIPE
KillMode=control-group

# MIB Environment Variables
Environment="MIBDIRS=/usr/share/snmp/mibs"
Environment="MIBS=+ALL"

# Amazon Linux 2023 compatibility
Environment="LD_LIBRARY_PATH=/usr/lib64"
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_FILE"
systemctl daemon-reload

echo "✓ Service created: $SERVICE_FILE"

# STEP 3: Create log directory if needed
echo ""
echo "STEP 3: Setting up logging..."

LOG_DIR="/var/log/telegraf"
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR"
    chown telegraf:telegraf "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    echo "✓ Created log directory: $LOG_DIR"
else
    # Fix permissions on existing directory
    chown telegraf:telegraf "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    echo "✓ Log directory exists: $LOG_DIR"
fi

# Ensure any existing log files have correct permissions
if [[ -f "$LOG_DIR/telegraf.log" ]]; then
    chown telegraf:telegraf "$LOG_DIR/telegraf.log"
    chmod 644 "$LOG_DIR/telegraf.log"
fi

# Also handle the specific instance log file if it exists
INSTANCE_LOG="$LOG_DIR/${INSTANCE_NAME}.log"
if [[ -f "$INSTANCE_LOG" ]]; then
    chown telegraf:telegraf "$INSTANCE_LOG"
    chmod 644 "$INSTANCE_LOG"
fi

# STEP 4: Display next steps
echo ""
echo "======================================"
echo "         SETUP COMPLETE!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Edit config file:"
echo "   vim $CONF_FILE"
echo ""
echo "2. Test configuration:"
echo "   telegraf --config $CONF_FILE --test"
echo ""
echo "3. Start the service:"
echo "   sudo systemctl start $INSTANCE_NAME"
echo ""
echo "4. Enable at boot:"
echo "   sudo systemctl enable $INSTANCE_NAME"
echo ""
echo "5. Check status:"
echo "   sudo systemctl status $INSTANCE_NAME"
echo ""
echo "6. View logs:"
echo "   sudo journalctl -u $INSTANCE_NAME -f"
echo ""
