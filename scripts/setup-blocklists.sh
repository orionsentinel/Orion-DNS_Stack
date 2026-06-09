#!/usr/bin/env bash
# Optimal Blocklist Setup for Pi-hole v6
# Automatically configures recommended blocklists

set -u

CONTAINER="${1:-pihole_unbound}"
PRESET="${2:-balanced}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

# Check if container exists
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Error: Container '$CONTAINER' not found or not running"
    exit 1
fi

setup_light() {
    info "Setting up LIGHT blocklists (Best for beginners)..."
    echo ""
    
    docker exec "$CONTAINER" sqlite3 /etc/pihole/gravity.db \
        "DELETE FROM adlist; 
         INSERT INTO adlist (address, enabled, comment) VALUES 
         ('https://hosts.oisd.nl/basic/', 1, 'OISD Basic - ~600K domains'),
         ('https://o0.pages.dev/Lite/adblock.txt', 1, '1Hosts Lite - ~200K domains');"
    
    log "Added 2 blocklists"
    info "Expected total: ~800,000 domains"
}

setup_balanced() {
    info "Setting up BALANCED blocklists (RECOMMENDED for most users)..."
    echo ""
    
    docker exec "$CONTAINER" sqlite3 /etc/pihole/gravity.db \
        "DELETE FROM adlist;
         INSERT INTO adlist (address, enabled, comment) VALUES
         ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/pro.txt', 1, 'Hagezi Multi PRO - ads/trackers/telemetry (recommended)'),
         ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/tif.txt', 1, 'Hagezi TIF - threat intel (malware/phishing)');"

    log "Added Hagezi Multi PRO + TIF — the recommended pair"
    info "Two curated lists beat thirty random ones (less overlap, fewer false positives)."
}

setup_aggressive() {
    info "Setting up AGGRESSIVE blocklists (For advanced users)..."
    echo ""
    
    docker exec "$CONTAINER" sqlite3 /etc/pihole/gravity.db \
        "DELETE FROM adlist;
         INSERT INTO adlist (address, enabled, comment) VALUES 
         ('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/pro.plus.txt', 1, 'Hagezi Pro++ - aggressive'),
         ('https://big.oisd.nl/', 1, 'OISD Big - ~3M domains'),
         ('https://o0.pages.dev/Pro/adblock.txt', 1, '1Hosts Pro - ~500K domains'),
         ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 1, 'StevenBlack Unified - ~150K domains');"
    
    log "Added 4 blocklists"
    info "Expected total: ~5 million domains"
    warn "This preset may cause more false positives"
}

# Main
echo ""
echo "═══════════════════════════════════════════"
echo " Pi-hole Optimal Blocklist Setup"
echo "═══════════════════════════════════════════"
echo ""

case "$PRESET" in
    light)
        setup_light
        ;;
    balanced)
        setup_balanced
        ;;
    aggressive)
        setup_aggressive
        ;;
    *)
        echo "Error: Unknown preset '$PRESET'"
        echo ""
        echo "Usage: $0 [container] [preset]"
        echo ""
        echo "Presets:"
        echo "  light       - ~800K domains (minimal false positives)"
        echo "  balanced    - ~2M domains (recommended) ⭐"
        echo "  aggressive  - ~5M domains (maximum blocking)"
        echo ""
        echo "Example:"
        echo "  $0 pihole_unbound balanced"
        exit 1
        ;;
esac

echo ""
info "Updating gravity database (this may take a few minutes)..."
docker exec "$CONTAINER" pihole updateGravity

echo ""
log "Blocklist setup complete!"
echo ""

# Show statistics
DOMAINS=$(docker exec "$CONTAINER" bash -c \
    "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity;'" 2>/dev/null || echo "unknown")

LISTS=$(docker exec "$CONTAINER" bash -c \
    "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM adlist WHERE enabled=1;'" 2>/dev/null || echo "unknown")

info "Statistics:"
info "  Active blocklists: $LISTS"
info "  Total domains blocked: $DOMAINS"
echo ""
info "Access Pi-hole admin at: http://$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER)/admin"
echo ""
