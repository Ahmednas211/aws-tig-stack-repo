#!/bin/bash
# Complete Grafana + InfluxDB HTTPS Setup for Amazon Linux 2023
# Fully Automated - No Manual Intervention Required
# Author: Infrastructure Team
# Date: 2024
# Updated for Amazon Linux 2023 compatibility

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================================================${NC}"
echo -e "${BLUE}🚀 COMPLETE GRAFANA + INFLUXDB HTTPS SETUP FOR AMAZON LINUX 2023${NC}"
echo -e "${BLUE}=======================================================================${NC}"

# Configuration Variables
GRAFANA_CERT_DIR="/etc/nginx/ssl/grafana"
INFLUXDB_CERT_DIR="/etc/nginx/ssl/influxdb"
GRAFANA_NGINX_CONFIG="/etc/nginx/sites-available/grafana"
INFLUXDB_NGINX_CONFIG="/etc/nginx/sites-available/influxdb"
TEMP_DIR="/tmp/monitoring-setup-$$"
GRAFANA_DOMAIN="grafana.az-nsis.optum.com"
INFLUXDB_DOMAIN="influxdb.az-nsis.optum.com"

# Certificate Password - Both certificates use the same password
CERT_PASSWORD="<Vs0gHeGCf61HX.x"

#### SECTION 1: SYSTEM PREPARATION ####
echo ""
echo -e "${CYAN}=== SECTION 1: SYSTEM PREPARATION ===${NC}"

# Detect if running on Amazon Linux 2023
if [ -f /etc/amazon-linux-release ]; then
    echo -e "${GREEN}✓ Detected Amazon Linux 2023${NC}"
    IS_AL2023=true
else
    echo -e "${YELLOW}⚠ System may not be Amazon Linux 2023, proceeding anyway...${NC}"
    IS_AL2023=false
fi

# Update system packages (Amazon Linux 2023 specific refresh)
echo -e "${BLUE}Updating system packages...${NC}"
sudo dnf update -y --refresh

# Install essential tools
echo -e "${BLUE}Installing essential tools...${NC}"
sudo dnf install -y vim wget curl nano net-tools openssl

echo -e "${GREEN}✅ Essential tools installed${NC}"

#### SECTION 2: INSTALL GRAFANA ####
echo ""
echo -e "${CYAN}=== SECTION 2: INSTALL GRAFANA ===${NC}"

# Setup Grafana repository
echo -e "${BLUE}Setting up Grafana repository...${NC}"
wget -q -O gpg.key https://rpm.grafana.com/gpg.key
sudo rpm --import gpg.key
rm -f gpg.key

sudo tee /etc/yum.repos.d/grafana.repo << EOF > /dev/null
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Install Grafana
echo -e "${BLUE}Installing Grafana...${NC}"
sudo dnf install -y grafana

# Enable and start Grafana service
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo -e "${GREEN}✅ Grafana installed and started${NC}"

#### SECTION 3: INSTALL INFLUXDB 2.x ####
echo ""
echo -e "${CYAN}=== SECTION 3: INSTALL INFLUXDB 2.x ===${NC}"

# Download and verify InfluxDB GPG key
echo -e "${BLUE}Setting up InfluxDB 2.x repository...${NC}"
wget -q https://repos.influxdata.com/influxdata-archive_compat.key

# Verify key checksum
echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c

# Import GPG key
sudo rpm --import influxdata-archive_compat.key
rm -f influxdata-archive_compat.key

# Create InfluxDB 2.x repository
# For Amazon Linux 2023, use RHEL 9 repository directly
cat <<EOF | sudo tee /etc/yum.repos.d/influxdb2.repo > /dev/null
[influxdb]
name = InfluxDB Repository - RHEL 9
baseurl = https://repos.influxdata.com/rhel/9/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF

# Install InfluxDB 2.x
echo -e "${BLUE}Installing InfluxDB 2.x server...${NC}"
sudo dnf install -y influxdb2

echo -e "${GREEN}✅ InfluxDB 2.x installed${NC}"

#### SECTION 4: CONFIGURE AND START INFLUXDB ####
echo ""
echo -e "${CYAN}=== SECTION 4: CONFIGURE AND START INFLUXDB ===${NC}"

# Create InfluxDB configuration directory
sudo mkdir -p /etc/influxdb

# Set proper ownership for InfluxDB data directory
sudo mkdir -p /var/lib/influxdb
sudo chown influxdb:influxdb /var/lib/influxdb

# Enable and start InfluxDB service
echo -e "${BLUE}Starting InfluxDB service...${NC}"
sudo systemctl enable influxdb
sudo systemctl start influxdb

# Wait for service to fully initialize
sleep 10

# Verify InfluxDB service status
echo -e "${GREEN}✅ InfluxDB Status:${NC}"
sudo systemctl is-active influxdb

# Check if InfluxDB is listening on port 8086
echo -e "${GREEN}✅ InfluxDB port check:${NC}"
sudo ss -tlnp | grep :8086 || true

#### SECTION 5: INSTALL NGINX ####
echo ""
echo -e "${CYAN}=== SECTION 5: INSTALL NGINX ===${NC}"

# Install EPEL repository (Amazon Linux 2023 specific method)
echo -e "${BLUE}Installing EPEL repository for Amazon Linux 2023...${NC}"
if [ "$IS_AL2023" = true ]; then
    # Amazon Linux 2023 has EPEL in the extras library
    sudo dnf install -y epel-release
    # If epel-release doesn't work, try the direct method
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Standard EPEL install failed, trying alternative method...${NC}"
        sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    fi
else
    # Fallback for non-AL2023 systems (like RHEL 9)
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
fi

sudo dnf upgrade -y

# Install Nginx
echo -e "${BLUE}Installing Nginx...${NC}"
sudo dnf install -y nginx

nginx -v
echo -e "${GREEN}✅ Nginx installed${NC}"

#### SECTION 6: CONFIGURE NGINX DIRECTORY STRUCTURE ####
echo ""
echo -e "${CYAN}=== SECTION 6: CONFIGURE NGINX DIRECTORY STRUCTURE ===${NC}"

sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/sites-enabled

# Backup original nginx.conf
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup-$(date +%Y%m%d-%H%M%S)

# Add sites-enabled to nginx.conf if not present
if ! grep -q "sites-enabled" /etc/nginx/nginx.conf; then
    sudo sed -i '/include \/etc\/nginx\/conf.d\/\*.conf;/a\    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
    echo -e "${GREEN}✅ Nginx configuration updated${NC}"
fi

#### SECTION 7: CONFIGURE FIREWALL ####
echo ""
echo -e "${CYAN}=== SECTION 7: CONFIGURE FIREWALL ===${NC}"

echo -e "${BLUE}Configuring firewall rules...${NC}"
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=8086/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
echo -e "${GREEN}✅ Firewall configured${NC}"

#### SECTION 8: DEPLOY GRAFANA CERTIFICATE ####
echo ""
echo -e "${CYAN}=== SECTION 8: DEPLOY GRAFANA CERTIFICATE ===${NC}"

# Create temporary directory
mkdir -p ${TEMP_DIR}
cd ${TEMP_DIR}

# Create Grafana certificate bundle
echo -e "${BLUE}Creating Grafana certificate bundle...${NC}"
cat > grafana-bundle.pem << 'GRAFANA_CERT_EOF'
-----BEGIN CERTIFICATE-----
MIIHJTCCBY2gAwIBAgIQdrJLcGlOIRBWA0mXt/1DhzANBgkqhkiG9w0BAQsFADBg
MQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTcwNQYDVQQD
Ey5TZWN0aWdvIFB1YmxpYyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gQ0EgT1YgUjM2
MB4XDTI1MDkxNTAwMDAwMFoXDTI2MDkxNTIzNTk1OVowZzELMAkGA1UEBhMCVVMx
EjAQBgNVBAgTCU1pbm5lc290YTEgMB4GA1UEChMXVW5pdGVkSGVhbHRoIEdyb3Vw
IEluYy4xIjAgBgNVBAMTGWdyYWZhbmEuYXotbnNpcy5vcHR1bS5jb20wggEiMA0G
CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCf6J9KyyfT4mMDNWnO9MawChMwdz+R
YIr4rLFPk3eSU+UVQGujVS7OdYl9l5o9IxCHst3Fw97gVIz/4ts4zA8ySlqdcF00
HyPbqzhoNnWu8TTeNAdzUNcj57JNPKzLs0JTUnhhElVh6hJuTlMQCbgCM213Z3IR
q24ql+hfB2DJCm1q3H0s7b9YHYXh6cZTNWPDL+1N3Rn+kOJ5oEstRj8Wky8ksIK+
QMSBd8WuBC0cKqLWftCB8iwpoGnzs24bIJX5Ygxp492SoTct8TNDgVhYsYeFiYGe
g6C6SH2dvTpjT5LzNScV133d0dxFBYgufJjiR1dQh8U4kyhOtkSlPhehAgMBAAGj
ggNSMIIDTjAfBgNVHSMEGDAWgBTjZnS7cGiNLF1ODqZKj5s3IpyCkjAdBgNVHQ4E
FgQUiDCXtH3Nb612uaBSxd8IZOJcoMQwDgYDVR0PAQH/BAQDAgWgMAwGA1UdEwEB
/wQCMAAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMEoGA1UdIARDMEEw
NQYMKwYBBAGyMQECAQMEMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5j
b20vQ1BTMAgGBmeBDAECAjBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vY3JsLnNl
Y3RpZ28uY29tL1NlY3RpZ29QdWJsaWNTZXJ2ZXJBdXRoZW50aWNhdGlvbkNBT1ZS
MzYuY3JsMIGEBggrBgEFBQcBAQR4MHYwTwYIKwYBBQUHMAKGQ2h0dHA6Ly9jcnQu
c2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1NlcnZlckF1dGhlbnRpY2F0aW9uQ0FP
VlIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMIIB
fgYKKwYBBAHWeQIEAgSCAW4EggFqAWgAdgDYCVU7lE96/8gWGW+UT4WrsPj8XodV
Jg8V0S5yu0VLFAAAAZlPOjiAAAAEAwBHMEUCIQD00B+FWLFpS20a9ChMI9TdCK7i
zR3leVZ5td9MKbXDVwIgfB6s/V/Ebra+VU1l2Jfj77pjen5Rg6rwsT9JseJ7OW4A
dgCvZ4g7V7BO3Y+m2X72LqjrgQrHcWDwJF5V1gwv54WHOgAAAZlPOjj7AAAEAwBH
MEUCIQDGwio3TRYjdYSKfKRYVr39IVmR/SboCWOgw27Bu2FCaAIgHkrb3gSWpcG4
mrnUpYp8Qm0PAA9YmUHFs2dFInPobg4AdgDXbX0Q0af1d8LH6V/XAL/5gskzWmXh
0LMBcxfAyMVpdwAAAZlPOjgZAAAEAwBHMEUCID2MdF6WA1luPe6BgbuSkCzL4rvl
HVIuvpjokiB6uNoDAiEAyfKN38ywAKc7zjanUT9s1Ptjf6YXF+xK1S+7RlFT148w
JAYDVR0RBB0wG4IZZ3JhZmFuYS5hei1uc2lzLm9wdHVtLmNvbTANBgkqhkiG9w0B
AQsFAAOCAYEAT1FojfJjc/7VLv2e1+a30aYALDArhk+mDyBSYUJSZe3EEER9wMza
YiLPQPoRRmGZQUIpQfDMDWUsgFsOiBT+krhk9gA3Hyi1DxnsQNLVKEK0k+pqmVF8
feCCl5nu5LdCqK5rZfRDYsx3zGxjFgms80Be1oOE07n7AZHtcsML63/Bh+sEmXud
SZlz4wC0lOXidcQC9KeHzDQfUPbs6caQSV7KkDlLa1ANntLoIQYMC/a2pAw5HQ4h
faKVduU4+uW2ZXhE93tRz3sOS7r/kgztuUrQkE1P0c9y67YCZGgSiGoTlwbsRJ0O
WSPiSgug1H5P4EyT35vK0VyCI2UElA3JfnSB3Zu/3oTfdOyOrw4NsMnDRu27ilsn
xq1iAg5slsP7zGqhboDJh+owDVeykAlTrWChkqb/kRkS2GXiyXW6Az0EvnKaUFeK
6QkVa1z7M+yZt8srz4jn3sDg5M9731lZMtUDyaAve2TTb9ZwLkUS+rlQ5uFMwQyS
1kYSdSJ8qWcC
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,188494A2C0EA17D4

JsvpAEYvEEX/7QAfGSyJseUVzQgE5IXUcj6ZER+0ZJM984zRBwpadUq0G2idSgGB
DksKVJ8s0K2FzjQ4ty55skAuNNl9wYbq+r0mKSCR6m8pbHxZpBxGVN+nr/fZmsLE
jE+61D0pc5F8t6Sl0jwTlIsRj7T/pS7ohz4+Edhgn3kgMMmtLod7fOp77xzOiiF7
ConKAKE3pIMYB0ctpKQyJvcpzYBtQ70BKsSK3VamSbr7rWHgdJWwXZ8kIswGW4Q3
i2rdQCwL+4dzof8zIeUY6deKsF3kgfMVH1E/T/ceQYC6rTkPJXrUc/ZMEOxBK2zp
cqWZeJLwjJWa4Z8SDD5EM9kv4icNtmhsnn4Wahujs/icHKlg3Uv/cQ5HeNaF89Eg
1QjJP2kBLW6dbESTnI3Uou9q/5rJhzoW/KeJbXb6z3sPF3pJUNoCd6MYaYuLnZ2D
xd+KXhfdF1luFABtYuGOnXixIDa/O0O4Zo84KmeiEQVz6MxxYj/gSnD9ISZMdxnD
HZSL5Xr/i0THoxtQEbYxY3+8/8+X77mkP0P5laoVdkPZ7gVT7iBwZJfYt8hRF2uW
eEogtwxLiaouSIXSb0MJ+PIFkRcNESfxFAEItKKnDDq2trGP15tJN/UT6p1J4yGC
MSbGFakjeYo2LxZgGrFxPoGvzfet8fJN1rpj2fMYWm7lzlJSLLU8nOKpXusB3a2A
+9/4D80Yxlv9ao02j+RdT/BrtXPd5Yx1DutlhZ9MS61AzKD27yK9eH95RPJ8MXbF
dgH04pJ1Z3GRVw9y87l43plWAaJ5p85FFlvp66C+zFg9DV8+RjtZH2DkL9S4nsGL
yDzAIjnsZ/oFRkeumsMjDHDcoXAK8d809kMCeGym2LdltRj3suIfOOmTz6gD/xIN
ZYJ/01T4xooDiYrmAmtUyg7nEHj2hAgefNwKDS1+PSoFTtBCmbzP4kl1+0YwZGV+
H9bVIH+5vArOIvd6tV1HprGnoLEcHLa0eL3JCjH+sYJmW9MUIBSgJ1hIe0j0e025
++xNwsZrHVp7GcFMjfI2jV/VxUXEYGjKGU0TLjuMlLJBPJfQBPtejQSBbEB6iF6K
GktzwEG4ZEzZpDet0FaFx+XUZkHNJSFBCR3xcrQ6Gq9pFOpingAbmTbIpdrHWmKZ
TjFVuw6nKwYSO8Q5j5XeZi91KKb2+C3htLx87oZ+KxPSKwTQwvVlaqpmkHKbnaBQ
jFQmfQYiDYgZPVUY2burdRrmduwQdLS50M4U5qm3aEdf24gA2NBjlTBfaSfsyo0m
hoHuKZjk2zM5vIQtK+RHYFddCm2xjUO6tGZAIRAoW5vdVQZk7xxtDKCVj2BLOoDj
LMxOD+VR9XLT/zyVHT2CWBKWMoEHFzgT2W82h2D4Mcpyh+oklLtc2WawllYZMGhq
mzQ6A5mDseSsEsdGE7KuS3sSdmrclU2oIisOHwmq3zD2uD+kWJLpAySbJjtGbvH7
uXuqhRibx/A70BreS8HRjmt5kPICN6To6pAOZleVOLReDzymFc4hj2NUQdQfb8ry
+Ur8MFDqmFhgl0NcyrenA2W3azOfdGdS5TW6/7MkYu3V16X9d6vqv1s8yb3Jm7jJ
-----END RSA PRIVATE KEY-----
GRAFANA_CERT_EOF

# Extract Grafana certificate
openssl x509 -in grafana-bundle.pem -out grafana.crt 2>/dev/null

echo -e "${BLUE}Extracting and decrypting Grafana private key...${NC}"

# Extract and decrypt Grafana private key with password (AUTOMATED - NO PROMPT)
openssl rsa -in grafana-bundle.pem -out grafana.key -passin pass:"${CERT_PASSWORD}" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Grafana certificate processed successfully${NC}"
else
    echo -e "${RED}✗ Failed to decrypt Grafana private key${NC}"
    echo -e "${YELLOW}Please check the CERT_PASSWORD variable in the script${NC}"
    exit 1
fi

# Deploy Grafana certificates
sudo mkdir -p ${GRAFANA_CERT_DIR}
sudo cp grafana.crt ${GRAFANA_CERT_DIR}/
sudo cp grafana.key ${GRAFANA_CERT_DIR}/
sudo chmod 644 ${GRAFANA_CERT_DIR}/grafana.crt
sudo chmod 600 ${GRAFANA_CERT_DIR}/grafana.key
sudo chown root:root ${GRAFANA_CERT_DIR}/*

echo -e "${GREEN}✅ Grafana certificates deployed${NC}"

#### SECTION 9: DEPLOY INFLUXDB CERTIFICATE ####
echo ""
echo -e "${CYAN}=== SECTION 9: DEPLOY INFLUXDB CERTIFICATE ===${NC}"

# Create InfluxDB certificate bundle
echo -e "${BLUE}Creating InfluxDB certificate bundle...${NC}"
cat > influxdb-bundle.pem << 'INFLUX_CERT_EOF'
-----BEGIN CERTIFICATE-----
MIIHKjCCBZKgAwIBAgIQTlDLrTI6UNPfRrVWzuCgQTANBgkqhkiG9w0BAQsFADBg
MQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTcwNQYDVQQD
Ey5TZWN0aWdvIFB1YmxpYyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gQ0EgT1YgUjM2
MB4XDTI1MDkxNjAwMDAwMFoXDTI2MDkxNjIzNTk1OVowaDELMAkGA1UEBhMCVVMx
EjAQBgNVBAgTCU1pbm5lc290YTEgMB4GA1UEChMXVW5pdGVkSGVhbHRoIEdyb3Vw
IEluYy4xIzAhBgNVBAMTGmluZmx1eGRiLmF6LW5zaXMub3B0dW0uY29tMIIBIjAN
BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsYZ/AHiuAEyq1etNYMYUsevDWbap
NapRKD3ykjK4NMb1CWIQwqiZJKN2g1rnxhFljBxMKr3SoAU7B/M2kHj6gXTH95FV
/3jFzFJT5MW8R3oMBWkRyLmTqJuvkc7QUChZIfHieodlAxsNzVlIgDpLmbI773Lz
4v7beokawrKeLg02yJZOfen8p7TkweliNIx9GbheCnqBclfxlLWweEDXUXFjCkzX
7kjUgRzoRhHMIQzZ4hSSlxFZR4PsiOERVsjJp1Nc3DRc7gGmrevjWxG4O0dk3tLO
LYy9hM+PDSMkvTav3wywHYxsMw7u111sYUqwtHIkDvcO26gUsZZu1c8W8QIDAQAB
o4IDVjCCA1IwHwYDVR0jBBgwFoAU42Z0u3BojSxdTg6mSo+bNyKcgpIwHQYDVR0O
BBYEFF6zysP758uCl2/Irrhp8A3vky1+MA4GA1UdDwEB/wQEAwIFoDAMBgNVHRMB
Af8EAjAAMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjBKBgNVHSAEQzBB
MDUGDCsGAQQBsjEBAgEDBDAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28u
Y29tL0NQUzAIBgZngQwBAgIwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL2NybC5z
ZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljU2VydmVyQXV0aGVudGljYXRpb25DQU9W
UjM2LmNybDCBhAYIKwYBBQUHAQEEeDB2ME8GCCsGAQUFBzAChkNodHRwOi8vY3J0
LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNTZXJ2ZXJBdXRoZW50aWNhdGlvbkNB
T1ZSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTCC
AYEGCisGAQQB1nkCBAIEggFxBIIBbQFrAHcA2AlVO5RPev/IFhlvlE+Fq7D4/F6H
VSYPFdEucrtFSxQAAAGZUJBIyAAABAMASDBGAiEA4r7B4caNWtqqtk/0tQ5XQAGH
9zuU6+20DDiakOMixxICIQCT2SifqHA92JjfFCxEBF199V/IPKsDTlptLm74ApvJ
lAB3AK9niDtXsE7dj6bZfvYuqOuBCsdxYPAkXlXWDC/nhYc6AAABmVCQSUEAAAQD
AEgwRgIhAP0awwdBSGvX+L2RttF+QQDJSXxJO/m6E6+HRlslz6f/AiEAwxoI05hE
DvM1LL8T6DkTLHjWUWmxlmACkrx+igtpcxMAdwDXbX0Q0af1d8LH6V/XAL/5gskz
WmXh0LMBcxfAyMVpdwAAAZlQkEheAAAEAwBIMEYCIQCs+5JCYhcV48snisBfvJ3T
NFea83HUF9h3Gy1wxGMaVwIhAIh07UyASPc7+OrsRbQb2z8STWzMKhQ8dv5Mf0sJ
ymw/MCUGA1UdEQQeMByCGmluZmx1eGRiLmF6LW5zaXMub3B0dW0uY29tMA0GCSqG
SIb3DQEBCwUAA4IBgQAGoJsjI8/hswiSRyemTSEQ7MZ1WqkLZoziFvXQ/UajbVHV
YebhR7MfMcdtXJ0TKgWwbIh9HxaPBCd4b9tnjtBN9r1VHw8HBOcvOeA77CBH1Ua9
XSppgFl83EVY9BiOZVdvjVqfw07kuiEB4WIjuSFcduysAn6xucA84J1GH5lsdX5c
TxRic4zc8bqIKeQwG8zfCIVOwLu8e5SkkIE7rnyUFaW9XvE43W/3nbLz9rKDG+Zv
BB587foK97NjvdOzuQTO09EONGaghEf+ANMQNycYWWOixLCwRCMNDyKH9psUNxFq
zSuLBzU/ExQNiLMxMKgMEwS/CG74+pPKEWlhsAKBz9pl6hP00IEX5uA0rX8AtGlH
m+W34gj6wRtUrXk7+FNTzYcHM3dW/e+Kv7/pDc0jPZfa+WIFE4UJlszIJ4TTg51n
8QWMzFwISuj8tX9IFUzdaY5DdEbGGd8H7RdXmigqLf2hAQ11L32z53dkEdNsnqO9
zbBH9nEPeD1Hl19Soh0=
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,0CF54183685F5CA3

0rpqtr0VaH2FQnO3pe/qOSIGCZS4QSSeBE//IhIp49QERd+Sc9YhBg2Hvx1yTGRK
1j8YLzT+Q4kDA2hJEZ1tsInqMHOjeARVHYjy63YsNCmC8S1s3G1DuY/PE9xgvHHH
N6Jz2cDEcnKXTr8EMwNN9K1BwRbIy7m3j1mNBGox1NjJ1tO6pNCW6ThdxLwTmzEa
tO5m5Ymv3GnRyVe4DYAXUjbbVpDNOis2rr4mJ4tgTcVbXcliuxjpVX0xSa13DwN+
h3aQPQV5GbRvFVSIc9g2py7FQsn3+NbVQdzmMVlGDE/UIIiIT5gcomDUY4f3Zdse
KRlocfHq0L6qK/WVh4CVtzJcY1rBk4VZe6JV4MRpoPgv3MnfU8/wQ3oABbwjRdQJ
cjB2i/z+W72XatMJvHvmIUfGWYoTsE9tf00IPR7teDjIBLU0j3eeSIddPhTdKGI3
4usLLk9yFOSY5p5BlMTf4MLydt6uir/VP/ACGi80Gec68hP3i/YxuaetCDDyGfwS
c2GDx7cipG2qzi1da3pTw8sgfc1jDkNH6QaurkQwdjFaSbvmPU7yTHiILd8Ku/E1
6Bpbaokfqnw+CSDj8RgGtxd7UKeWpRdJ0okXrZ7GsFk4QtYirIYtg5CCZBOe8fAK
sGljOzQ4xsL6SEj7CxaYsRzRERnv/CATiVlfqeeUjc1GCdZxnEBSadWHh1fsyQ9t
9FQPa9pP9L6x/RSCALYiNjPqFbmlwSplWKpQwtXQFLIkuzmLoQj1+Zooc/YtaloA
FAv4cEnPZ+s73Ms9HYmRfyRp1nCF13/ZhXIy+m6Ivvg9vZ8KGhio7v1a/SMmk3P4
63/AIZuiP9734INgnj8J7b6zNQfiN+Y8TIVLbk+5fqjXNs5iHzLvtT0MU7d9/pqU
3CBJ0TQh1UJj3MZwwksWw47MQg/yruICB4Mk0wSPhVjGriPj8ufIEDfZGMrrltYC
bIg7/xE/IbYa5IiUtRR/O9T7kY/AkGdiDU5534c5bytktzRiqgJxVvgULobg+N6R
JTgrjATqbMY293cj0rbwcO5A2TUq0ghqQoYY2Lg1VQTD/Z8j/D/T7tmcXyRGy8Dm
d7e/PG56lW0hmvO89tArVJa/5g5nQ1W1At0m62UVI7OQmo7TgjGFeYtHmnZ5o09q
VxXMqcuWmzVkVnNvxo2L6pKc8YRbX3zl03mHZHGlQjnlru4JoyYbPtKGnmC3YIUz
gzBvGnpXZLD43+Xjh6pbr/oggj7IDqc67VYr8nV0p7uFugSTcBTSUkDwiTt20EHZ
H9FB/6Qh8J99987bTC27KthcUYUCCq08tSw21wEVfXG5QXlkgR5otR59UbPEqIO1
Vk66cfDSvLQ/HkGsLm8mUgajjQjqyh7peHXSW5/w+pvFZ5/nxL3uB2Bbp1oSjO4t
sJXe2oKsVjOo5XRww6PrGO2Z2LcDksPbKDaGpcON/k8BmPD98CXcvQDVajYcyQBr
+YYIoIrczu94hdg9lDYiPztpeC/4rjQoWlLwbJ7iS+RUHkpYDWT7MB5+gRZkETh3
RftF6SxKezEVi9L4nNyCV/pAktj9csP6qvJaQaFIJYpI44PC3PjP99WFyLv4yuvb
-----END RSA PRIVATE KEY-----
INFLUX_CERT_EOF

# Extract InfluxDB certificate
openssl x509 -in influxdb-bundle.pem -out influxdb.crt 2>/dev/null

echo -e "${BLUE}Extracting and decrypting InfluxDB private key...${NC}"

# Extract and decrypt InfluxDB private key with password (AUTOMATED - NO PROMPT)
openssl rsa -in influxdb-bundle.pem -out influxdb.key -passin pass:"${CERT_PASSWORD}" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ InfluxDB certificate processed successfully${NC}"
else
    echo -e "${RED}✗ Failed to decrypt InfluxDB private key${NC}"
    echo -e "${YELLOW}Please check the CERT_PASSWORD variable in the script${NC}"
    exit 1
fi

# Deploy InfluxDB certificates
sudo mkdir -p ${INFLUXDB_CERT_DIR}
sudo cp influxdb.crt ${INFLUXDB_CERT_DIR}/
sudo cp influxdb.key ${INFLUXDB_CERT_DIR}/
sudo chmod 644 ${INFLUXDB_CERT_DIR}/influxdb.crt
sudo chmod 600 ${INFLUXDB_CERT_DIR}/influxdb.key
sudo chown root:root ${INFLUXDB_CERT_DIR}/*

echo -e "${GREEN}✅ InfluxDB certificates deployed${NC}"

#### SECTION 10: CREATE NGINX CONFIGURATION FOR GRAFANA ####
echo ""
echo -e "${CYAN}=== SECTION 10: CREATE NGINX CONFIGURATION FOR GRAFANA ===${NC}"

cat << 'EOF' | sudo tee ${GRAFANA_NGINX_CONFIG} > /dev/null
# Grafana HTTPS Configuration
server {
    listen 80;
    server_name grafana.az-nsis.optum.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name grafana.az-nsis.optum.com;

    ssl_certificate /etc/nginx/ssl/grafana/grafana.crt;
    ssl_certificate_key /etc/nginx/ssl/grafana/grafana.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    access_log /var/log/nginx/grafana-access.log;
    error_log /var/log/nginx/grafana-error.log;

    large_client_header_buffers 4 32k;
    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        proxy_buffering off;
    }
    
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

sudo ln -sf ${GRAFANA_NGINX_CONFIG} /etc/nginx/sites-enabled/
echo -e "${GREEN}✅ Grafana Nginx configuration created${NC}"

#### SECTION 11: CREATE NGINX CONFIGURATION FOR INFLUXDB ####
echo ""
echo -e "${CYAN}=== SECTION 11: CREATE NGINX CONFIGURATION FOR INFLUXDB ===${NC}"

cat << 'EOF' | sudo tee ${INFLUXDB_NGINX_CONFIG} > /dev/null
# InfluxDB HTTPS Configuration
server {
    listen 80;
    server_name influxdb.az-nsis.optum.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name influxdb.az-nsis.optum.com;

    ssl_certificate /etc/nginx/ssl/influxdb/influxdb.crt;
    ssl_certificate_key /etc/nginx/ssl/influxdb/influxdb.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    access_log /var/log/nginx/influxdb-access.log;
    error_log /var/log/nginx/influxdb-error.log;

    large_client_header_buffers 4 32k;
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:8086;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        proxy_buffering off;
        
        # InfluxDB specific headers
        proxy_set_header Authorization $http_authorization;
        proxy_pass_header Authorization;
    }
    
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

sudo ln -sf ${INFLUXDB_NGINX_CONFIG} /etc/nginx/sites-enabled/
echo -e "${GREEN}✅ InfluxDB Nginx configuration created${NC}"

#### SECTION 12: CONFIGURE SELINUX ####
echo ""
echo -e "${CYAN}=== SECTION 12: CONFIGURE SELINUX ===${NC}"

# Check if SELinux is present and enabled
if command -v getenforce &> /dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo -e "${BLUE}SELinux status: ${SELINUX_STATUS}${NC}"
    
    if [ "${SELINUX_STATUS}" != "Disabled" ]; then
        echo -e "${BLUE}Configuring SELinux policies...${NC}"
        
        # Install SELinux utilities if missing (Amazon Linux 2023 specific)
        if ! command -v semanage &> /dev/null; then
            echo -e "${YELLOW}Installing SELinux policy utilities...${NC}"
            sudo dnf install -y policycoreutils-python-utils
        fi
        
        # Apply SELinux policies
        sudo setsebool -P httpd_can_network_connect on 2>/dev/null || true
        sudo restorecon -Rv /etc/nginx/ssl/ 2>/dev/null || true
        
        echo -e "${GREEN}✅ SELinux configured${NC}"
    else
        echo -e "${YELLOW}SELinux is disabled, skipping configuration${NC}"
    fi
else
    echo -e "${YELLOW}SELinux is not installed on this system${NC}"
fi

#### SECTION 13: START AND TEST SERVICES ####
echo ""
echo -e "${CYAN}=== SECTION 13: START AND TEST SERVICES ===${NC}"

# Test Nginx configuration
echo -e "${BLUE}Testing Nginx configuration...${NC}"
sudo nginx -t

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Nginx configuration test passed${NC}"
    
    # Start or reload Nginx
    if systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx
    else
        sudo systemctl start nginx
        sudo systemctl enable nginx
    fi
    echo -e "${GREEN}✅ Nginx is running${NC}"
else
    echo -e "${RED}✗ Nginx configuration test failed${NC}"
    exit 1
fi

# Verify all services
echo ""
echo -e "${MAGENTA}=== SERVICE STATUS ===${NC}"
for service in grafana-server influxdb nginx; do
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}✓ $service: Running${NC}"
    else
        echo -e "${RED}✗ $service: Not running${NC}"
        sudo systemctl start $service
    fi
done

# Clean up
cd /
rm -rf ${TEMP_DIR}

#### SECTION 14: FINAL SUMMARY ####
echo ""
echo -e "${BLUE}=======================================================================${NC}"
echo -e "${GREEN}🎉 INSTALLATION COMPLETE ON AMAZON LINUX 2023!${NC}"
echo -e "${BLUE}=======================================================================${NC}"
echo ""
echo -e "${GREEN}📊 DEPLOYED SERVICES:${NC}"
echo -e "  ${CYAN}Grafana:${NC}  https://${GRAFANA_DOMAIN}"
echo -e "  ${CYAN}InfluxDB:${NC} https://${INFLUXDB_DOMAIN}"
echo ""
echo -e "${GREEN}📡 SERVICE PORTS:${NC}"
echo -e "  • Grafana:  3000 (backend) → 443 (HTTPS)"
echo -e "  • InfluxDB: 8086 (backend) → 443 (HTTPS)"
echo -e "  • HTTP:     80 (redirects to HTTPS)"
echo ""
echo -e "${GREEN}🔑 DEFAULT CREDENTIALS:${NC}"
echo -e "  ${YELLOW}Grafana:${NC}"
echo -e "    • Username: admin"
echo -e "    • Password: admin (change on first login)"
echo -e "  ${YELLOW}InfluxDB:${NC}"
echo -e "    • Setup at: https://${INFLUXDB_DOMAIN}"
echo ""
echo -e "${GREEN}📝 USEFUL COMMANDS:${NC}"
echo -e "  • Check services:     ${BLUE}sudo systemctl status grafana-server influxdb nginx${NC}"
echo -e "  • View Nginx logs:    ${BLUE}sudo tail -f /var/log/nginx/*.log${NC}"
echo -e "  • Test certificates:  ${BLUE}openssl s_client -connect localhost:443 -servername ${GRAFANA_DOMAIN}${NC}"
echo -e "  • Health checks:      ${BLUE}curl -k https://${GRAFANA_DOMAIN}/nginx-health${NC}"
echo ""
echo -e "${GREEN}🔧 NEXT STEPS:${NC}"
echo -e "  1. Access InfluxDB at https://${INFLUXDB_DOMAIN} and complete setup"
echo -e "  2. Access Grafana at https://${GRAFANA_DOMAIN}"
echo -e "  3. Add InfluxDB as a data source in Grafana"
echo -e "  4. Create your dashboards"
echo ""
echo -e "${YELLOW}📌 CERTIFICATES VALID UNTIL: September 2026${NC}"
echo -e "${CYAN}📌 Platform: Amazon Linux 2023${NC}"
echo ""
echo -e "${BLUE}=======================================================================${NC}"
