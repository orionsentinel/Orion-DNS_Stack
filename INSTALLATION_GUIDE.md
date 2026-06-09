# Installation Guide

## Table of Contents
1. [⚠️ Pi-hole DNS Configuration (IMPORTANT)](#️-pi-hole-dns-configuration-important)
2. [Prerequisites](#prerequisites)
3. [Hardware Requirements](#hardware-requirements)
4. [Quick Installation](#quick-installation)
5. [Detailed Installation](#detailed-installation)
6. [Post-Installation Configuration](#post-installation-configuration)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

---

## ⚠️ Pi-hole DNS Configuration (IMPORTANT)

> **🔒 Privacy Policy: This project ONLY supports Unbound as upstream DNS provider for Pi-hole.**

Before proceeding with installation, understand this critical privacy requirement:

### Allowed DNS Upstreams

| Provider | Configuration | Privacy Level |
|----------|---------------|---------------|
| **Unbound** (Default) | `127.0.0.1#5335` | 🟢 Maximum - Local recursive resolver |

### NOT Allowed (Privacy Risk)

❌ **DO NOT configure Pi-hole to use these public DNS providers:**
- Google DNS (8.8.8.8)
- Cloudflare DNS (1.1.1.1)
- OpenDNS (208.67.222.222)
- Quad9 (9.9.9.9)
- Any other third-party public DNS

### Why This Policy?

Using public DNS resolvers exposes your **entire DNS query history** to third parties. With Unbound:
- DNS queries go directly to authoritative servers
- No single third party sees all your queries
- DNSSEC validation is performed locally
- Complete privacy control

📖 **[Read the full Pi-hole DNS Configuration Guide](docs/PIHOLE_CONFIGURATION.md)** for detailed rationale and configuration instructions.

For installation instructions, please see:

- **[GETTING_STARTED.md](GETTING_STARTED.md)** — Quick start guide (recommended)
- **[INSTALL.md](INSTALL.md)** — Comprehensive installation reference

---

## Quick Start

```bash
git clone https://github.com/orionsentinel/Orion-DNS_Stack.git
cd Orion-DNS_Stack
bash install.sh
```

Then open `http://<your-pi-ip>:5555` and follow the wizard.

---

## Deployment Guides

- **[docs/install-single-pi.md](docs/install-single-pi.md)** — Single Raspberry Pi setup
- **[docs/install-two-pi-ha.md](docs/install-two-pi-ha.md)** — Two-Pi high availability setup

---

## After Installation

See **[USER_GUIDE.md](USER_GUIDE.md)** for daily operations and maintenance.
