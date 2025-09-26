#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "  MIB INSTALLATION FOR AMAZON LINUX 2023"
echo "======================================"

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "Run as root or with sudo"
   exit 1
fi

# Detect system
if [ -f /etc/amazon-linux-release ]; then
    echo -e "${GREEN}✓ Detected Amazon Linux 2023${NC}"
else
    echo -e "${YELLOW}⚠ System may not be Amazon Linux 2023, proceeding anyway...${NC}"
fi

# Variables
MIB_DIR="/usr/share/snmp/mibs"
BACKUP_DIR="/root/mib-backup-$(date +%Y%m%d-%H%M%S)"

# Create backup if MIBs exist
if [ -d "$MIB_DIR" ] && [ "$(ls -A $MIB_DIR 2>/dev/null)" ]; then
    echo "Creating backup of existing MIBs..."
    mkdir -p "$BACKUP_DIR"
    cp -r "$MIB_DIR" "$BACKUP_DIR/" 2>/dev/null || true
    echo -e "${GREEN}✓ Backup saved to: $BACKUP_DIR${NC}"
fi

# Create fresh directories
mkdir -p "$MIB_DIR"
mkdir -p /etc/snmp
chmod 755 "$MIB_DIR"
chmod 755 /etc/snmp

echo -e "${GREEN}✓ Directories prepared${NC}"

# STEP 2: INSTALL PACKAGES
echo ""
echo "STEP 2: Installing SNMP packages"
echo "---------------------------------"

# Update package cache for AL2023
dnf makecache --refresh

# Install SNMP packages (same package names work on AL2023)
dnf install -y net-snmp net-snmp-utils net-snmp-libs

# Also install perl-Net-SNMP if available (useful for some MIB tools)
dnf install -y perl-Net-SNMP 2>/dev/null || echo "perl-Net-SNMP not available, skipping"

echo -e "${GREEN}✓ Packages installed${NC}"

# STEP 3: DOWNLOAD MIBs
echo ""
echo "STEP 3: Downloading MIBs"
echo "------------------------"
cd /tmp

# Download net-snmp MIBs
echo "Downloading from: github.com/net-snmp/net-snmp"
wget --no-check-certificate -O master.zip "https://github.com/net-snmp/net-snmp/archive/refs/heads/master.zip" 2>/dev/null

if [ -f master.zip ]; then
    unzip -q master.zip
    if [ -d "net-snmp-master/mibs" ]; then
        # Copy .txt MIB files
        cp net-snmp-master/mibs/*.txt "$MIB_DIR/" 2>/dev/null || true
        
        # Copy other MIB files (without extensions)
        for file in net-snmp-master/mibs/*; do
            if [ -f "$file" ]; then
                name=$(basename "$file")
                # Skip non-MIB files
                if [[ "$name" != *.c && "$name" != *.h && "$name" != *.pl && \
                      "$name" != Makefile* && "$name" != *.txt && "$name" != README* ]]; then
                    cp "$file" "$MIB_DIR/" 2>/dev/null || true
                fi
            fi
        done
        echo -e "${GREEN}✓ Standard MIBs installed${NC}"
    fi
    rm -rf net-snmp-master master.zip
fi

# Download Palo Alto MIBs
echo "Downloading Palo Alto MIBs..."
wget -q -O pan.zip "https://docs.paloaltonetworks.com/content/dam/techdocs/en_US/zip/snmp-mib/pan-11-2-snmp-mib-modules.zip" 2>/dev/null || true

if [ -f pan.zip ]; then
    unzip -q -o pan.zip
    cp *.my "$MIB_DIR/" 2>/dev/null || true
    rm -f pan.zip *.my
    echo -e "${GREEN}✓ Palo Alto MIBs installed${NC}"
fi

# STEP 4: SET PERMISSIONS
echo ""
echo "STEP 4: Setting Permissions"
echo "----------------------------"
chown -R root:root "$MIB_DIR"
chmod 755 "$MIB_DIR"
chmod 644 "$MIB_DIR"/* 2>/dev/null || true

# STEP 5: CONFIGURE SNMP
echo ""
echo "STEP 5: Configuring SNMP"
echo "-------------------------"

# Create main SNMP configuration
cat > /etc/snmp/snmp.conf <<'EOF'
# SNMP Configuration for Amazon Linux 2023
mibs +ALL
mibdirs /usr/share/snmp/mibs
showMibErrors no
mibAllowUnderline 1
EOF

chmod 644 /etc/snmp/snmp.conf
chown root:root /etc/snmp/snmp.conf

# Update library path for AL2023 if needed
echo "/usr/lib64" > /etc/ld.so.conf.d/net-snmp.conf
ldconfig

echo -e "${GREEN}✓ SNMP configured${NC}"

# STEP 6: SELinux Configuration (if enabled)
echo ""
echo "STEP 6: Checking SELinux"
echo "-------------------------"
if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
    echo "Configuring SELinux contexts..."
    restorecon -Rv /usr/share/snmp 2>/dev/null || true
    restorecon -Rv /etc/snmp 2>/dev/null || true
    echo -e "${GREEN}✓ SELinux contexts updated${NC}"
else
    echo "SELinux is disabled or not installed, skipping"
fi

# STEP 7: VERIFY
echo ""
echo "======================================"
echo "VERIFICATION"
echo "======================================"

MIB_COUNT=$(ls -1 "$MIB_DIR" 2>/dev/null | wc -l)
echo "MIBs installed: $MIB_COUNT"

echo -n "MIB resolution test: "
if snmptranslate -On SNMPv2-MIB::sysDescr 2>/dev/null; then
    echo -e "${GREEN}WORKING${NC}"
else
    echo -e "${RED}NOT WORKING (use numeric OIDs)${NC}"
fi

# Test SNMP tools availability
echo ""
echo "SNMP Tools Status:"
which snmpwalk &>/dev/null && echo -e "  snmpwalk: ${GREEN}✓ Available${NC}" || echo -e "  snmpwalk: ${RED}✗ Not found${NC}"
which snmpget &>/dev/null && echo -e "  snmpget:  ${GREEN}✓ Available${NC}" || echo -e "  snmpget:  ${RED}✗ Not found${NC}"
which snmptrap &>/dev/null && echo -e "  snmptrap: ${GREEN}✓ Available${NC}" || echo -e "  snmptrap: ${RED}✗ Not found${NC}"

echo ""
echo "Directory permissions:"
ls -ld "$MIB_DIR"
ls -ld /etc/snmp
ls -l /etc/snmp/snmp.conf

# Show system info
echo ""
echo "System Information:"
echo "  OS: $(cat /etc/amazon-linux-release 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  Kernel: $(uname -r)"
echo "  SNMP Version: $(snmpwalk --version 2>&1 | head -1)"

echo ""
echo "======================================"
echo -e "${GREEN}DONE - Ready for SNMPv3 testing${NC}"
echo "======================================"
echo ""
echo "Test commands:"
echo "  Basic MIB translation: snmptranslate -On SNMPv2-MIB::sysDescr"
echo "  SNMPv3 walk: snmpwalk -v3 -u USER -l authPriv -a SHA -A PASS -x AES -X PASS IP .1.3.6.1.2.1.1"
echo "  List loaded MIBs: snmptranslate -Tp | head -20"
echo ""
