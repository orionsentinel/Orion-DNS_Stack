# First-Run Web Wizard Guide

**Orion Sentinel DNS HA - Web-Based Setup**

The first-run web wizard provides a simple, graphical interface for configuring your Orion DNS HA stack without needing to edit configuration files manually.

---

## Table of Contents

- [Overview](#overview)
- [Accessing the Wizard](#accessing-the-wizard)
- [Setup Steps](#setup-steps)
- [After Setup](#after-setup)
- [Changing Configuration](#changing-configuration)
- [Disabling the Wizard](#disabling-the-wizard)
- [Troubleshooting](#troubleshooting)

---

## Overview

The web wizard simplifies the initial setup process by:

- **Guiding you through network configuration** - Choose single-node or HA mode
- **Configuring DNS security profiles** - Select from Family, Standard, or Paranoid filtering
- **Generating configuration files** - Automatically creates `.env` with your settings
- **Providing next steps** - Clear instructions on deploying and using your stack

**Who should use this:**
- First-time users who want a guided setup experience
- Users who prefer web interfaces over command-line
- Anyone setting up a simple single-node deployment

**Power users** can skip the wizard and configure `.env` directly or use `scripts/install.sh`.

---

## Accessing the Wizard

### First-Time Setup

If you used the one-line installer or ran the stack for the first time:

```bash
# The wizard runs automatically as part of the stack
# Access it at:
http://<your-pi-ip>:8080
```

### Manual Start

If you need to start the wizard manually:

```bash
cd /path/to/Orion-DNS_Stack

# Start just the wizard service
docker compose -f stacks/dns/docker-compose.yml up -d dns-wizard

# Then access it at:
# http://<your-pi-ip>:8080
```

### Finding Your Pi's IP Address

If you don't know your Pi's IP address:

```bash
# On the Pi, run:
hostname -I

# The first IP shown is usually your Pi's LAN IP
```

Or check your router's DHCP client list.

---

## Setup Steps

The wizard guides you through 3 simple steps:

### Step 1: Welcome

- Introduction to Orion DNS HA features
- Overview of what you'll configure
- Links to advanced documentation

**Action:** Click "Get Started" to begin

### Step 2: Network Configuration

Configure your network settings:

#### Deployment Mode

**Single-Node (Recommended for beginners):**
- One Raspberry Pi
- DNS services run on your Pi's IP
- No failover (but containers still have redundancy)
- Simpler setup

**High Availability (HA):**
- Two Raspberry Pis with automatic failover
- Requires a Virtual IP (VIP)
- Need to configure MASTER/BACKUP roles
- Full hardware redundancy

#### Fields to Configure

1. **Raspberry Pi IP Address**
   - The static IP of this Pi on your LAN
   - Auto-detected, but you can change it
   - Example: `192.168.1.100`

2. **Network Interface**
   - Usually `eth0` (wired) or `wlan0` (wireless)
   - Auto-detected
   
3. **Virtual IP (HA mode only)**
   - An unused IP on your LAN that both Pis will share
   - This is the DNS IP you'll give to your router
   - Example: `192.168.1.200`
   - **Important:** Make sure this IP is outside your router's DHCP range!

4. **Node Role (HA mode only)**
   - **MASTER**: Choose this for your first Pi
   - **BACKUP**: Choose this for your second Pi

5. **Pi-hole Admin Password**
   - Password for the Pi-hole web interface
   - Minimum 8 characters
   - Make it strong!

**Tip:** If you're not sure whether to use HA mode, choose **Single-Node**. You can add a second Pi later if needed.

### Step 3: DNS Profile Selection

Choose how aggressively to filter DNS queries:

#### Standard (Recommended) ✓
- Balanced ad and tracker blocking
- Malware protection
- Won't break most websites
- **Best for:** General home/office use

#### Family
- Everything in Standard, plus:
- Adult content filtering
- Additional malware protection
- Gambling site blocking
- **Best for:** Families with children

#### Paranoid
- Maximum privacy protection
- Aggressive tracker/telemetry blocking
- Blocks social media widgets
- **Warning:** May break some websites and services
- **Best for:** Privacy-focused users

**Tip:** Start with **Standard**. You can change profiles later without re-running the wizard.

### Step 4: Completion

After setup completes, you'll see:
- Confirmation that configuration was saved
- Next steps to deploy the stack
- Router DNS configuration instructions
- Links to Pi-hole admin interface

---

## After Setup

Once the wizard completes:

### 1. Deploy the Stack

The wizard saves configuration but doesn't start services. Deploy them:

```bash
cd /path/to/Orion-DNS_Stack

# Start all DNS services
docker compose -f stacks/dns/docker-compose.yml up -d

# Check status
docker compose -f stacks/dns/docker-compose.yml ps
```

### 2. Apply Your DNS Profile

Run the profile application script:

```bash
# Apply the profile you selected
python3 scripts/apply-profile.py --profile standard

# Or for other profiles:
python3 scripts/apply-profile.py --profile family
python3 scripts/apply-profile.py --profile paranoid

# Preview changes without applying:
python3 scripts/apply-profile.py --profile standard --dry-run
```

### 3. Configure Your Router

**Critical:** Point your router's DNS to your DNS HA stack:

#### Single-Node Mode:
- Primary DNS: `<your-pi-ip>`
- Secondary DNS: `<your-pi-ip>` (or `8.8.8.8` as fallback)

#### HA Mode:
- Primary DNS: `<your-vip>`
- Secondary DNS: `<your-vip>` (or leave blank)

**Where to configure this:**
- Usually in router settings under "DHCP" or "LAN" settings
- Look for "DNS Server" or "Name Server" settings
- Save and your router will distribute this to all devices

### 4. Verify It's Working

```bash
# Test DNS resolution from any device on your network
nslookup google.com

# Should show your Pi/VIP as the DNS server

# Access Pi-hole interface
# http://<your-pi-ip>/admin
# Or in HA mode: http://<your-vip>/admin
```

---

## Changing Configuration

### Re-running the Wizard

The wizard creates a `.setup_done` file after completion. To re-run:

```bash
# Remove the sentinel file
rm wizard/.setup_done

# Restart the wizard container
docker compose -f stacks/dns/docker-compose.yml restart dns-wizard

# Access the wizard again at http://<your-pi-ip>:8080
```

### Changing DNS Profile

You can change your DNS profile anytime without re-running the wizard:

```bash
# Change to a different profile
python3 scripts/apply-profile.py --profile family

# Or use the wizard's completion page
# Visit http://<your-pi-ip>:8080/done
# Select a different profile from the dropdown
```

### Manual Configuration

Power users can edit `.env` directly:

```bash
# Edit configuration
nano stacks/dns/.env

# Or use the main .env (they're symlinked)
nano .env

# Restart services to apply changes
docker compose -f stacks/dns/docker-compose.yml restart
```

---

## Disabling the Wizard

After initial setup, you may want to disable the wizard:

### Option 1: Stop the wizard container

```bash
# Stop and disable
docker compose -f stacks/dns/docker-compose.yml stop dns-wizard
```

### Option 2: Remove from docker-compose.yml

Edit `stacks/dns/docker-compose.yml` and comment out or remove the `dns-wizard` service:

```yaml
# Comment out the entire dns-wizard service
#  dns-wizard:
#    build: ../../wizard
#    ...
```

Then:

```bash
docker compose -f stacks/dns/docker-compose.yml up -d
```

### Option 3: Use environment variable (future enhancement)

```bash
# In .env, set:
DNS_WIZARD_ENABLED=false

# Then restart
docker compose -f stacks/dns/docker-compose.yml up -d
```

---

## Troubleshooting

### Cannot Access Wizard (Connection Refused)

**Check if wizard is running:**
```bash
docker ps | grep dns-wizard
```

**Start wizard if not running:**
```bash
docker compose -f stacks/dns/docker-compose.yml up -d dns-wizard
```

**Check logs:**
```bash
docker logs dns-wizard
```

### Wizard Shows "Setup Already Completed"

This means `.setup_done` file exists:

```bash
# To re-run wizard, remove the file:
rm wizard/.setup_done

# Then refresh your browser
```

### Configuration Not Applying

**Check .env file was created:**
```bash
ls -la stacks/dns/.env

# View contents
cat stacks/dns/.env
```

**Manually verify settings:**
```bash
# Ensure DNS_VIP, PIHOLE_PASSWORD, etc. are set
grep "DNS_VIP" stacks/dns/.env
grep "PIHOLE_PASSWORD" stacks/dns/.env
```

### Wrong IP Address Detected

The wizard tries to auto-detect your Pi's IP, but may get it wrong if you have multiple network interfaces:

**Solution:** Manually edit the IP in the wizard form before submitting.

### Port 8080 Already in Use

If another service uses port 8080:

**Change the wizard port in docker-compose.yml:**
```yaml
dns-wizard:
  ports:
    - "8888:8080"  # Changed from 8080:8080
```

Then access at `http://<your-pi-ip>:8888`

---

## What the Wizard Creates

After setup, the wizard creates/modifies:

1. **`stacks/dns/.env`** - Environment configuration file
2. **`wizard/.setup_done`** - Sentinel file marking setup complete

**What it configures:**
- `HOST_IP` - Your Pi's IP
- `DNS_VIP` / `VIP_ADDRESS` - Virtual IP (or Pi IP in single-node)
- `NODE_ROLE` - MASTER or BACKUP (HA mode)
- `NETWORK_INTERFACE` - Network interface name
- `PIHOLE_PASSWORD` - Pi-hole admin password
- `DNS_PROFILE` - Selected security profile

---

## Advanced: Wizard Architecture

The wizard is a simple Flask web application:

- **Backend:** Python Flask (`wizard/app.py`)
- **Frontend:** HTML + CSS + vanilla JavaScript
- **No database:** Configuration stored in `.env` files
- **Stateless:** Each request is independent

**File structure:**
```
wizard/
├── app.py              # Flask application
├── templates/          # HTML templates
│   ├── welcome.html    # Step 1: Welcome
│   ├── network.html    # Step 2: Network config
│   ├── profile.html    # Step 3: Profile selection
│   └── done.html       # Step 4: Completion
├── static/
│   └── style.css       # Styling
├── requirements.txt    # Python dependencies
├── Dockerfile          # Container build
└── .setup_done         # Sentinel file (created after setup)
```

---

## See Also

- [Installation Guide](../INSTALLATION_GUIDE.md) - Manual installation without wizard
- [DNS Profiles Guide](profiles.md) - Detailed profile information
- [Operations Guide](operations.md) - Day-to-day management
- [Troubleshooting Guide](../TROUBLESHOOTING.md) - Common issues

---

**Need Help?**

- Check the [Troubleshooting Guide](../TROUBLESHOOTING.md)
- Visit the [GitHub repository](https://github.com/orionsentinel/Orion-DNS_Stack)
- Review the [README](../README.md) for additional resources
