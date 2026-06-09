# Orion Sentinel DNS HA - Simple Installation Guide

This guide provides clear, step-by-step instructions to install the Orion Sentinel DNS HA stack on your Raspberry Pi.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
  - [Method 1: Web UI Installation (Recommended)](#method-1-web-ui-installation-recommended)
  - [Method 2: Command Line Installation](#method-2-command-line-installation)
- [Post-Installation Steps](#post-installation-steps)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

---

## Prerequisites

### Hardware Requirements
- **Raspberry Pi**: Model 4 or 5 (4GB RAM minimum, 8GB recommended)
- **Storage**: 32GB+ SD card (64GB+ SSD via USB recommended for better performance)
- **Power**: 3A+ USB-C power supply
- **Network**: Ethernet connection (recommended) or WiFi

### Software Requirements
- **Operating System**: Raspberry Pi OS (64-bit) or Ubuntu Server 20.04+
- **Internet Connection**: Required for installation
- **SSH Access**: Ability to connect to your Pi (or direct keyboard/monitor access)

### Network Requirements
- **Static IP**: Configure a static IP for your Pi or create a DHCP reservation in your router
- **Available IPs**: You'll need at least 1 IP address (more for multi-node HA setup)

### Time Required
- **Installation**: 15-30 minutes
- **Configuration**: 10-15 minutes

### Pre-Installation Validation (Optional)

Before installing, you can run a validation script to check prerequisites:

```bash
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack
bash scripts/validate-installation.sh
```

This will verify:
- Repository structure is correct
- All required files are present
- Scripts have valid syntax
- Documentation is consistent

---

## Installation Methods

### Method 1: Web UI Installation (Recommended)

This method uses a web-based wizard for easy, guided setup. **Perfect for beginners!**

#### Step 1: Download and Run the Installer

SSH into your Raspberry Pi and run:

```bash
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack
bash install.sh
```

The installer will:
- Check your system compatibility
- Install Docker and dependencies (if needed)
- Launch the web-based setup wizard

#### Step 2: Access the Web UI

Once the installer completes, open your web browser and navigate to:

```
http://YOUR-PI-IP-ADDRESS:5555
```

Example: `http://192.168.1.100:5555`

#### Step 3: Follow the Wizard

The wizard will guide you through:
1. **Welcome Screen**: Overview of what will be installed
2. **Network Configuration**: Choose deployment mode and configure network settings
3. **Security Profile**: Select DNS filtering level (Standard, Family, or Paranoid)
4. **Deployment**: Complete the setup

#### Step 4: Complete Setup

After the wizard finishes, it will display:
- Next steps for accessing Pi-hole
- Router configuration instructions
- How to verify everything is working

---

### Method 2: Command Line Installation

This method is for users who prefer terminal-based installation or need more control.

#### Step 1: Clone the Repository

```bash
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack
```

#### Step 2: Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit the configuration
nano .env
```

**Key settings to configure:**

```bash
# Your Pi's IP address
HOST_IP=192.168.1.100

# Network configuration
NETWORK_INTERFACE=eth0
SUBNET=192.168.1.0/24
GATEWAY=192.168.1.1

# Security (IMPORTANT: Change these!)
PIHOLE_PASSWORD=your_secure_password_here
GRAFANA_ADMIN_PASSWORD=your_secure_password_here

# Timezone
TZ=America/New_York
```

Save the file (Ctrl+X, then Y, then Enter).

#### Step 3: Install Docker

If Docker is not already installed:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```

Log out and log back in for the group changes to take effect.

#### Step 4: Deploy the Stack

For a single Pi setup:

```bash
cd stacks/dns
docker compose --profile single-pi-ha up -d
```

For a two-Pi HA setup, see [INSTALL.md](INSTALL.md) for detailed instructions.

---

## Post-Installation Steps

### 1. Access Pi-hole Web Interface

Open your browser and go to:

```
http://YOUR-PI-IP/admin
```

Login with the password you set in the `.env` file (or via the wizard).

### 2. Configure Your Router

To use your new DNS server network-wide:

1. Log into your router's admin interface
2. Find the DHCP/DNS settings
3. Set the DNS server to your Pi's IP address: `192.168.1.100` (use your actual IP)
4. Save and reboot your router

**Alternative**: Configure DNS on individual devices if you don't have router access.

### 3. Apply a Security Profile (Optional)

Choose your preferred DNS filtering level:

```bash
# Standard (balanced ad/tracker blocking)
python3 scripts/apply-profile.py --profile standard

# Family (includes adult content filtering)
python3 scripts/apply-profile.py --profile family

# Paranoid (maximum privacy, may break some sites)
python3 scripts/apply-profile.py --profile paranoid
```

---

## Verification

### Check Services are Running

```bash
docker ps
```

You should see containers like:
- `pihole_primary`
- `unbound_primary`
- `keepalived` (if HA is enabled)

### Test DNS Resolution

```bash
# Test from your Pi
dig @127.0.0.1 google.com

# Test from another device (replace with your Pi's IP)
dig @192.168.1.100 google.com
```

You should get a response with an IP address.

### Verify Ad Blocking

Try visiting a known ad domain:

```bash
dig @192.168.1.100 ads.doubleclick.net
```

You should get `0.0.0.0` as the response (blocked).

### Check Container Health

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

All containers should show "healthy" status after a few minutes.

---

## Troubleshooting

### Problem: Can't access the web wizard

**Solution:**
```bash
# Check if the wizard is running
docker ps | grep setup-ui

# If not running, start it manually
cd wizard
docker compose up -d

# Check logs for errors
docker logs rpi-dns-setup-ui
```

### Problem: Docker permission errors

**Solution:**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

Or log out and log back in.

### Problem: Services won't start

**Solution:**
```bash
# Check logs
docker compose -f stacks/dns/docker-compose.yml logs

# Restart services
docker compose -f stacks/dns/docker-compose.yml restart
```

### Problem: DNS not resolving

**Solution:**
1. Check Pi-hole is running: `docker logs pihole_primary`
2. Check Unbound is running: `docker logs unbound_primary`
3. Verify network configuration in `.env` file
4. Make sure your device is using the Pi's IP as its DNS server

### Problem: High memory usage

**Solution:**
```bash
# Check resource usage
docker stats

# Increase swap space if needed
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile  # Set CONF_SWAPSIZE=2048
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

### Still having issues?

- Check the comprehensive [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide
- Review logs: `docker compose logs -f`
- Verify your `.env` configuration matches your network
- Make sure your Pi has a static IP address

---

## Next Steps

### Access Monitoring (Optional)

If you deployed the observability stack:

- **Grafana**: `http://YOUR-PI-IP:3000` (default: admin / your_grafana_password)
- **Prometheus**: `http://YOUR-PI-IP:9090`

### Enable Automated Backups

```bash
# Set up automated backups
bash scripts/backup-config.sh

# Add to crontab for weekly backups
crontab -e
# Add: 0 2 * * 0 /home/pi/Orion-DNS_Stack/scripts/backup-config.sh
```

### Configure Notifications (Optional)

Edit `.env` and add Signal notification settings:

```bash
SIGNAL_NUMBER=+1234567890
SIGNAL_RECIPIENTS=+1234567890
```

### Update the Stack

Keep your system updated:

```bash
# Update the stack
cd Orion-DNS_Stack
bash scripts/smart-upgrade.sh -i

# Update Pi-hole gravity (blocklists)
docker exec pihole_primary pihole -g
```

---

## Additional Resources

- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Quick start guide
- **[INSTALL.md](INSTALL.md)** - Comprehensive installation guide with advanced options
- **[USER_GUIDE.md](USER_GUIDE.md)** - Daily operations and maintenance
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Detailed troubleshooting guide
- **[wizard/README.md](wizard/README.md)** - Web UI wizard documentation

---

## Security Best Practices

1. **Change all default passwords** before deployment
2. **Use strong passwords** (20+ characters, random)
3. **Keep your system updated**: `sudo apt update && sudo apt upgrade`
4. **Limit network access** to admin interfaces
5. **Regular backups**: Set up automated backup cron jobs
6. **Monitor logs**: Check for suspicious activity regularly

Generate secure passwords:
```bash
openssl rand -base64 32
```

---

## Getting Help

- **Documentation**: Check the `/docs` directory in this repository
- **Issues**: [GitHub Issues](https://github.com/orionsentinel/Orion-DNS_Stack/issues)
- **Community**: See README.md for community links

---

**Version**: 2.4.0  
**Last Updated**: December 2024

**Ready to start?** Choose your installation method above and follow the steps! 🚀
