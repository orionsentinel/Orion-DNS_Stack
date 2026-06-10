#!/usr/bin/env bash
# =============================================================================
# Orion Sentinel DNS HA - Verification Script
# =============================================================================
# This script verifies the HA configuration and current state
# Run on either primary or secondary node
#
# Usage: ./scripts/verify-ha.sh
# =============================================================================

set -euo pipefail

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# Default values from env or fallback
VIP_ADDRESS="${VIP_ADDRESS:-192.168.8.243}"
NODE_IP="${NODE_IP:-}"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"

echo "============================================================================="
echo "  Orion Sentinel DNS HA - Health Verification"
echo "============================================================================="
echo ""

# Note: Most checks don't require root, but some network commands may need sudo
# The script will inform you if root privileges are needed for specific commands

# =============================================================================
# 1. VIP Status - Which node holds the Virtual IP?
# =============================================================================
echo -e "${COLOR_BLUE}[1/5] Virtual IP Status${COLOR_RESET}"
echo "---------------------------------------------"
echo "VIP: ${VIP_ADDRESS}"
echo ""

if ip addr show "${NETWORK_INTERFACE}" 2>/dev/null | grep -q "${VIP_ADDRESS}"; then
  echo -e "${COLOR_GREEN}✓ This node HAS the VIP${COLOR_RESET}"
  echo ""
  ip addr show "${NETWORK_INTERFACE}" | grep -A2 "${VIP_ADDRESS}" || true
else
  echo -e "${COLOR_YELLOW}○ This node does NOT have the VIP${COLOR_RESET}"
  echo "  (This is normal for BACKUP node when primary is healthy)"
fi
echo ""

# =============================================================================
# 2. Keepalived Status
# =============================================================================
echo -e "${COLOR_BLUE}[2/5] Keepalived Status${COLOR_RESET}"
echo "---------------------------------------------"

if docker ps --format '{{.Names}}' | grep -q "^keepalived$"; then
  echo -e "${COLOR_GREEN}✓ Keepalived container is running${COLOR_RESET}"
  echo ""
  
  # Show last 15 lines of keepalived logs
  echo "Recent keepalived logs:"
  echo "---"
  docker logs --tail 15 keepalived 2>&1 | sed 's/^/  /'
  echo "---"
  echo ""
  
  # Try to detect current state from logs
  if docker logs --tail 50 keepalived 2>&1 | grep -q "Entering MASTER STATE"; then
    echo -e "${COLOR_GREEN}✓ State: MASTER (from logs)${COLOR_RESET}"
  elif docker logs --tail 50 keepalived 2>&1 | grep -q "Entering BACKUP STATE"; then
    echo -e "${COLOR_YELLOW}○ State: BACKUP (from logs)${COLOR_RESET}"
  else
    echo "  State: Unknown (check logs above)"
  fi
else
  echo -e "${COLOR_RED}✗ Keepalived container is NOT running${COLOR_RESET}"
  echo ""
  echo "Start with:"
  echo "  cd /opt/orion-dns-ha"
  echo "  docker compose --profile two-node-ha-primary up -d"
  echo "  (or --profile two-node-ha-backup for secondary)"
fi
echo ""

# =============================================================================
# 3. Keepalived Configuration Verification
# =============================================================================
echo -e "${COLOR_BLUE}[3/5] Keepalived Configuration${COLOR_RESET}"
echo "---------------------------------------------"

if docker exec keepalived test -f /etc/keepalived/keepalived.conf 2>/dev/null; then
  echo "Checking unicast_peer configuration..."
  echo ""
  
  # Show unicast_peer block
  echo "unicast_peer block:"
  docker exec keepalived sh -c '
    awk "/unicast_peer/{p=1} p{print} p && /}/{exit}" /etc/keepalived/keepalived.conf
  ' 2>/dev/null | sed 's/^/  /' || echo "  (could not read config)"
  echo ""
  
  # Show unicast_src_ip
  echo "unicast_src_ip:"
  docker exec keepalived sh -c '
    grep "unicast_src_ip" /etc/keepalived/keepalived.conf || echo "  NOT FOUND"
  ' 2>/dev/null | sed 's/^/  /'
  echo ""
  
  # Show virtual_ipaddress block
  echo "virtual_ipaddress block:"
  docker exec keepalived sh -c '
    awk "/virtual_ipaddress/{p=1} p{print} p && /}/{exit}" /etc/keepalived/keepalived.conf
  ' 2>/dev/null | sed 's/^/  /' || echo "  (could not read config)"
  
else
  echo -e "${COLOR_RED}✗ Cannot read keepalived.conf (container not running?)${COLOR_RESET}"
fi
echo ""

# =============================================================================
# 4. DNS Resolution Test - VIP
# =============================================================================
echo -e "${COLOR_BLUE}[4/5] DNS Resolution Test - VIP${COLOR_RESET}"
echo "---------------------------------------------"
echo "Testing: dig @${VIP_ADDRESS} github.com +short"
echo ""

if command -v dig >/dev/null 2>&1; then
  if result=$(timeout 5 dig @"${VIP_ADDRESS}" github.com +short +time=3 2>&1); then
    if [ -n "$result" ]; then
      echo -e "${COLOR_GREEN}✓ DNS via VIP works${COLOR_RESET}"
      echo "$result" | head -3 | sed 's/^/  /'
    else
      echo -e "${COLOR_RED}✗ DNS via VIP returned empty response${COLOR_RESET}"
    fi
  else
    echo -e "${COLOR_RED}✗ DNS via VIP failed${COLOR_RESET}"
    echo "$result" | sed 's/^/  /'
  fi
else
  echo -e "${COLOR_YELLOW}⚠️  dig command not found - install dnsutils${COLOR_RESET}"
fi
echo ""

# =============================================================================
# 5. DNS Resolution Test - Node IP (if known)
# =============================================================================
echo -e "${COLOR_BLUE}[5/5] DNS Resolution Test - Node IP${COLOR_RESET}"
echo "---------------------------------------------"

if [ -n "$NODE_IP" ]; then
  echo "Testing: dig @${NODE_IP} github.com +short"
  echo ""
  
  if command -v dig >/dev/null 2>&1; then
    if result=$(timeout 5 dig @"${NODE_IP}" github.com +short +time=3 2>&1); then
      if [ -n "$result" ]; then
        echo -e "${COLOR_GREEN}✓ DNS via Node IP works${COLOR_RESET}"
        echo "$result" | head -3 | sed 's/^/  /'
      else
        echo -e "${COLOR_RED}✗ DNS via Node IP returned empty response${COLOR_RESET}"
      fi
    else
      echo -e "${COLOR_RED}✗ DNS via Node IP failed${COLOR_RESET}"
      echo "$result" | sed 's/^/  /'
    fi
  else
    echo -e "${COLOR_YELLOW}⚠️  dig command not found${COLOR_RESET}"
  fi
else
  echo "NODE_IP not set in environment - skipping node IP test"
fi
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "============================================================================="
echo "  Verification Complete"
echo "============================================================================="
echo ""
echo "Expected for healthy HA setup:"
echo "  • Primary (MASTER): Has VIP, state MASTER, DNS works on both VIP and Node IP"
echo "  • Secondary (BACKUP): No VIP, state BACKUP, DNS works on Node IP only"
echo ""
echo "If secondary becomes MASTER when primary is healthy:"
echo "  1. Check that unicast_peer IPs are correct (peer should be OTHER node's IP)"
echo "  2. Check that VRRP packets are flowing: tcpdump -ni eth1 proto 112"
echo "  3. Check for NIC flaps: dmesg -T | grep eth1"
echo ""
