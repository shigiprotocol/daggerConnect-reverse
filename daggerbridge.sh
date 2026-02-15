#!/bin/bash
# ============================================================================
#  DaggerBridge - Reverse Tunnel Manager
#  Uses: DaggerConnect binary (must be present on system)
#
#  Transports : tcpmux | kcpmux | wsmux | wssmux | httpmux | httpsmux
#  Profiles   : balanced | aggressive | latency | cpu-efficient | gaming
#  Features   : HTTP Mimicry, Traffic Obfuscation, SMUX tuning,
#               Port Mapping (single/range/custom), System Optimizer
# ============================================================================

set -eo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Paths ────────────────────────────────────────────────────────────────────
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/daggerbridge"
SYSTEMD_DIR="/etc/systemd/system"
BINARY_PATH="$INSTALL_DIR/DaggerConnect"

# Possible locations where DaggerConnect might already exist
SEARCH_PATHS=(
    "/usr/local/bin/DaggerConnect"
    "/usr/bin/DaggerConnect"
    "/opt/DaggerConnect/DaggerConnect"
    "/root/DaggerConnect"
)

# ── Global arrays (client multi-path) ────────────────────────────────────────
declare -a PATH_TRANSPORTS=()
declare -a PATH_ADDRS=()
declare -a PATH_POOLS=()
declare -a PATH_AGGPOOL=()
declare -a PATH_RETRY=()
declare -a PATH_TIMEOUT=()

# ── Global config vars with safe defaults ────────────────────────────────────
TRANSPORT="httpsmux"
PROFILE="gaming"
VERBOSE="false"
LISTEN_PORT="2020"
PSK=""
CERT_FILE=""
KEY_FILE=""
MAPPINGS_YAML=""
USE_HTTP_MIMIC="false"

# HTTP Mimicry defaults
HTTP_DOMAIN="www.google.com"
HTTP_PATH="/search"
HTTP_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
HTTP_CHUNKED="true"
HTTP_COOKIES="true"

# Obfuscation defaults
OBFUS_ENABLED="true"
OBFUS_MIN_PAD=8
OBFUS_MAX_PAD=32
OBFUS_MIN_DELAY=0
OBFUS_MAX_DELAY=0
OBFUS_BURST="0"

# SMUX defaults (gaming-optimized)
SMUX_KEEPALIVE=1
SMUX_MAXRECV=524288
SMUX_MAXSTREAM=524288
SMUX_FRAMESIZE=2048

# Advanced defaults
TCP_NODELAY="true"
TCP_KEEPALIVE=3
TCP_READBUF=32768
TCP_WRITEBUF=32768
MAX_CONN=300
CONN_TIMEOUT=20
STREAM_TIMEOUT=45
CLEANUP_INTERVAL=1
SESSION_TIMEOUT=15
MAX_UDP_FLOWS=150
UDP_FLOW_TIMEOUT=90
UDP_BUFSIZE=262144
WS_READBUF=16384
WS_WRITEBUF=16384
WS_COMPRESSION="false"

# ============================================================================
# UTILITIES
# ============================================================================

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ██████╗  █████╗  ██████╗  ██████╗ ███████╗██████╗ "
    echo "  ██╔══██╗██╔══██╗██╔════╝ ██╔════╝ ██╔════╝██╔══██╗"
    echo "  ██║  ██║███████║██║  ███╗██║  ███╗█████╗  ██████╔╝"
    echo "  ██║  ██║██╔══██║██║   ██║██║   ██║██╔══╝  ██╔══██╗"
    echo "  ██████╔╝██║  ██║╚██████╔╝╚██████╔╝███████╗██║  ██║"
    echo "  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${PURPLE}  ┌────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}  │      DaggerBridge  •  Reverse Tunnel Manager       │${NC}"
    echo -e "${PURPLE}  │  httpsmux · gaming · mimicry · obfuscation · SMUX  │${NC}"
    echo -e "${PURPLE}  └────────────────────────────────────────────────────┘${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Run as root: sudo ./daggerbridge.sh${NC}"
        exit 1
    fi
}

press_enter() {
    echo ""
    read -r -p "  Press Enter to continue..."
}

confirm() {
    read -r -p "  ${1:-Are you sure?} [y/N]: " c
    [[ "$c" =~ ^[Yy]$ ]]
}

validate_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

svc_status() {
    local s="$1"
    if systemctl is-active --quiet "$s" 2>/dev/null; then
        echo -e "${GREEN}● Running${NC}"
    elif systemctl is-enabled --quiet "$s" 2>/dev/null; then
        echo -e "${YELLOW}○ Stopped (enabled)${NC}"
    else
        echo -e "${RED}○ Not installed${NC}"
    fi
}

# ============================================================================
# BINARY DETECTION
# ============================================================================

find_binary() {
    # Already at our target path
    [ -f "$BINARY_PATH" ] && return 0

    # Search known locations
    for p in "${SEARCH_PATHS[@]}"; do
        if [ -f "$p" ] && [ "$p" != "$BINARY_PATH" ]; then
            echo -e "${YELLOW}  Found DaggerConnect at: ${p}${NC}"
            echo -e "${YELLOW}  Copying to ${BINARY_PATH}...${NC}"
            mkdir -p "$INSTALL_DIR"
            cp "$p" "$BINARY_PATH"
            chmod +x "$BINARY_PATH"
            echo -e "${GREEN}  ✓ Binary ready${NC}"
            return 0
        fi
    done

    return 1
}

install_deps() {
    echo -e "${YELLOW}  📦 Checking dependencies...${NC}"
    local pkgs=()
    command -v wget    &>/dev/null || pkgs+=(wget)
    command -v curl    &>/dev/null || pkgs+=(curl)
    command -v openssl &>/dev/null || pkgs+=(openssl)
    command -v ip      &>/dev/null || pkgs+=(iproute2)

    if [ ${#pkgs[@]} -gt 0 ]; then
        if command -v apt-get &>/dev/null; then
            apt-get update -qq
            apt-get install -y "${pkgs[@]}" > /dev/null 2>&1
        elif command -v yum &>/dev/null; then
            yum install -y "${pkgs[@]}" > /dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            dnf install -y "${pkgs[@]}" > /dev/null 2>&1
        fi
    fi
    echo -e "${GREEN}  ✓ Dependencies ready${NC}"
}

# ============================================================================
# SYSTEM OPTIMIZER
# ============================================================================

optimize_system() {
    local loc="${1:-iran}"
    echo ""
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo -e "${CYAN}        SYSTEM OPTIMIZATION${NC}"
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Target: ${GREEN}${loc^^}${NC}"
    echo ""

    local iface
    iface=$(ip link show | awk '/state UP/{gsub(":",""); print $2}' | head -1)
    [ -z "$iface" ] && iface="eth0"
    echo -e "  ${GREEN}✓ Interface: $iface${NC}"

    echo -e "  ${YELLOW}Applying TCP settings...${NC}"
    sysctl -w net.core.rmem_max=16777216          > /dev/null 2>&1 || true
    sysctl -w net.core.wmem_max=16777216          > /dev/null 2>&1 || true
    sysctl -w net.core.rmem_default=262144        > /dev/null 2>&1 || true
    sysctl -w net.core.wmem_default=262144        > /dev/null 2>&1 || true
    sysctl -w net.core.netdev_max_backlog=5000    > /dev/null 2>&1 || true
    sysctl -w net.core.somaxconn=8192             > /dev/null 2>&1 || true
    sysctl -w "net.ipv4.tcp_rmem=4096 87380 16777216" > /dev/null 2>&1 || true
    sysctl -w "net.ipv4.tcp_wmem=4096 87380 16777216" > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_window_scaling=1       > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_timestamps=1           > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_sack=1                 > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_fastopen=3             > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0 > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_no_metrics_save=1      > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_autocorking=0          > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_mtu_probing=1          > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_retries2=5             > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_syn_retries=2          > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_fin_timeout=15         > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_keepalive_time=120     > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_keepalive_intvl=10     > /dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_keepalive_probes=3     > /dev/null 2>&1 || true
    echo -e "  ${GREEN}✓ TCP tuning applied${NC}"

    echo -e "  ${YELLOW}Enabling BBR...${NC}"
    if modprobe tcp_bbr 2>/dev/null; then
        sysctl -w net.ipv4.tcp_congestion_control=bbr > /dev/null 2>&1 || true
        sysctl -w net.core.default_qdisc=fq_codel     > /dev/null 2>&1 || true
        echo -e "  ${GREEN}✓ BBR + fq_codel enabled${NC}"
    else
        echo -e "  ${YELLOW}⚠️  BBR not available${NC}"
    fi

    tc qdisc del dev "$iface" root 2>/dev/null || true
    if tc qdisc add dev "$iface" root fq_codel limit 500 target 3ms interval 50ms ecn 2>/dev/null; then
        echo -e "  ${GREEN}✓ fq_codel configured${NC}"
    fi

    mkdir -p /etc/sysctl.d
    cat > /etc/sysctl.d/99-daggerbridge.conf << 'SYSCTL'
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=262144
net.core.wmem_default=262144
net.core.netdev_max_backlog=5000
net.core.somaxconn=8192
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_autocorking=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_retries2=5
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=120
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq_codel
SYSCTL
    echo -e "  ${GREEN}✓ Settings persistent (reboot-safe)${NC}"
    echo ""
    echo -e "  ${GREEN}══════════════════════════════════════${NC}"
    echo -e "  ${GREEN}   ✓ Optimization complete!${NC}"
    echo -e "  ${GREEN}══════════════════════════════════════${NC}"
}

optimizer_menu() {
    show_banner
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo -e "${CYAN}         SYSTEM OPTIMIZER${NC}"
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo ""
    echo "    1) Optimize Iran server"
    echo "    2) Optimize Foreign server"
    echo "    0) Back"
    echo ""
    read -r -p "  Select: " ch
    case "$ch" in
        1) optimize_system "iran";    press_enter; main_menu ;;
        2) optimize_system "foreign"; press_enter; main_menu ;;
        0) main_menu ;;
        *) optimizer_menu ;;
    esac
}

# ============================================================================
# SSL CERTIFICATE
# ============================================================================

generate_ssl_cert() {
    read -r -p "  Domain/CN [www.google.com]: " cn
    cn="${cn:-www.google.com}"
    mkdir -p "$CONFIG_DIR/certs"
    if openssl req -x509 -newkey rsa:4096 \
        -keyout "$CONFIG_DIR/certs/key.pem" \
        -out    "$CONFIG_DIR/certs/cert.pem" \
        -days 3650 -nodes \
        -subj "/C=US/ST=CA/L=SF/O=Corp/CN=${cn}" \
        > /dev/null 2>&1; then
        CERT_FILE="$CONFIG_DIR/certs/cert.pem"
        KEY_FILE="$CONFIG_DIR/certs/key.pem"
        echo -e "  ${GREEN}✓ Certificate generated for: ${cn}${NC}"
    else
        echo -e "  ${RED}✖ Certificate generation failed${NC}"
        CERT_FILE=""; KEY_FILE=""
    fi
}

# ============================================================================
# TRANSPORT SELECTOR
# ============================================================================

select_transport() {
    echo ""
    echo -e "  ${YELLOW}Transport Type:${NC}"
    echo "    1) tcpmux    — Plain TCP (fastest, no DPI bypass)"
    echo "    2) kcpmux    — KCP/UDP (high speed, packet loss tolerant)"
    echo "    3) wsmux     — WebSocket (HTTP-compatible)"
    echo "    4) wssmux    — WebSocket + TLS"
    echo "    5) httpmux   — HTTP Mimicry (DPI bypass)"
    echo "    6) httpsmux  — HTTPS Mimicry + TLS ⭐ Best"
    echo ""
    read -r -p "  Choice [6]: " tc
    case "${tc:-6}" in
        1) TRANSPORT="tcpmux" ;;
        2) TRANSPORT="kcpmux" ;;
        3) TRANSPORT="wsmux" ;;
        4) TRANSPORT="wssmux" ;;
        5) TRANSPORT="httpmux" ;;
        *) TRANSPORT="httpsmux" ;;
    esac
    echo -e "  ${GREEN}✓ Transport: ${TRANSPORT}${NC}"
}

# ============================================================================
# PROFILE SELECTOR  (sets SMUX + advanced defaults per profile)
# ============================================================================

select_profile() {
    echo ""
    echo -e "  ${YELLOW}Performance Profile:${NC}"
    echo "    1) balanced      — Everyday use"
    echo "    2) aggressive    — Maximum throughput"
    echo "    3) latency       — Minimum latency"
    echo "    4) cpu-efficient — Low CPU servers"
    echo "    5) gaming        — Gaming + streaming ⭐ Best"
    echo ""
    read -r -p "  Choice [5]: " pc
    case "${pc:-5}" in
        1) PROFILE="balanced" ;;
        2) PROFILE="aggressive" ;;
        3) PROFILE="latency" ;;
        4) PROFILE="cpu-efficient" ;;
        *) PROFILE="gaming" ;;
    esac

    # Apply profile-specific SMUX + advanced tuning
    case "$PROFILE" in
        gaming)
            SMUX_KEEPALIVE=1;  SMUX_MAXRECV=524288;  SMUX_MAXSTREAM=524288;  SMUX_FRAMESIZE=2048
            TCP_NODELAY="true"; TCP_KEEPALIVE=3; TCP_READBUF=32768; TCP_WRITEBUF=32768
            MAX_CONN=300; CONN_TIMEOUT=20; STREAM_TIMEOUT=45; CLEANUP_INTERVAL=1; SESSION_TIMEOUT=15
            MAX_UDP_FLOWS=150; UDP_FLOW_TIMEOUT=90; UDP_BUFSIZE=262144
            OBFUS_MIN_PAD=8;   OBFUS_MAX_PAD=32;  OBFUS_MIN_DELAY=0; OBFUS_MAX_DELAY=0; OBFUS_BURST="0"
            ;;
        latency)
            SMUX_KEEPALIVE=2;  SMUX_MAXRECV=1048576; SMUX_MAXSTREAM=1048576; SMUX_FRAMESIZE=4096
            TCP_NODELAY="true"; TCP_KEEPALIVE=5; TCP_READBUF=65536; TCP_WRITEBUF=65536
            MAX_CONN=500; CONN_TIMEOUT=30; STREAM_TIMEOUT=60; CLEANUP_INTERVAL=1; SESSION_TIMEOUT=20
            MAX_UDP_FLOWS=300; UDP_FLOW_TIMEOUT=120; UDP_BUFSIZE=524288
            OBFUS_MIN_PAD=8;   OBFUS_MAX_PAD=64;  OBFUS_MIN_DELAY=0; OBFUS_MAX_DELAY=5;  OBFUS_BURST="0.05"
            ;;
        aggressive)
            SMUX_KEEPALIVE=5;  SMUX_MAXRECV=16777216; SMUX_MAXSTREAM=16777216; SMUX_FRAMESIZE=32768
            TCP_NODELAY="true"; TCP_KEEPALIVE=10; TCP_READBUF=8388608; TCP_WRITEBUF=8388608
            MAX_CONN=5000; CONN_TIMEOUT=60; STREAM_TIMEOUT=120; CLEANUP_INTERVAL=3; SESSION_TIMEOUT=30
            MAX_UDP_FLOWS=1000; UDP_FLOW_TIMEOUT=300; UDP_BUFSIZE=4194304
            OBFUS_MIN_PAD=16;  OBFUS_MAX_PAD=256; OBFUS_MIN_DELAY=2; OBFUS_MAX_DELAY=20; OBFUS_BURST="0.1"
            ;;
        balanced)
            SMUX_KEEPALIVE=5;  SMUX_MAXRECV=8388608;  SMUX_MAXSTREAM=8388608;  SMUX_FRAMESIZE=16384
            TCP_NODELAY="true"; TCP_KEEPALIVE=15; TCP_READBUF=4194304; TCP_WRITEBUF=4194304
            MAX_CONN=2000; CONN_TIMEOUT=45; STREAM_TIMEOUT=90; CLEANUP_INTERVAL=3; SESSION_TIMEOUT=25
            MAX_UDP_FLOWS=500; UDP_FLOW_TIMEOUT=180; UDP_BUFSIZE=2097152
            OBFUS_MIN_PAD=16;  OBFUS_MAX_PAD=512; OBFUS_MIN_DELAY=5; OBFUS_MAX_DELAY=50; OBFUS_BURST="0.15"
            ;;
        cpu-efficient)
            SMUX_KEEPALIVE=10; SMUX_MAXRECV=4194304;  SMUX_MAXSTREAM=4194304;  SMUX_FRAMESIZE=8192
            TCP_NODELAY="false"; TCP_KEEPALIVE=30; TCP_READBUF=2097152; TCP_WRITEBUF=2097152
            MAX_CONN=500; CONN_TIMEOUT=60; STREAM_TIMEOUT=120; CLEANUP_INTERVAL=5; SESSION_TIMEOUT=30
            MAX_UDP_FLOWS=200; UDP_FLOW_TIMEOUT=180; UDP_BUFSIZE=1048576
            OBFUS_MIN_PAD=0;   OBFUS_MAX_PAD=0;   OBFUS_MIN_DELAY=0; OBFUS_MAX_DELAY=0;  OBFUS_BURST="0"
            OBFUS_ENABLED="false"
            ;;
    esac

    echo -e "  ${GREEN}✓ Profile: ${PROFILE}${NC}"
}

# ============================================================================
# HTTP MIMICRY
# ============================================================================

configure_http_mimicry() {
    echo ""
    echo -e "  ${CYAN}══════════════════════════════════════${NC}"
    echo -e "  ${CYAN}      HTTP MIMICRY SETTINGS${NC}"
    echo -e "  ${CYAN}══════════════════════════════════════${NC}"
    echo ""
    echo "    Fake Domain:"
    echo "      1) www.google.com     (default, most traffic)"
    echo "      2) www.cloudflare.com (CDN-like)"
    echo "      3) api.github.com     (API traffic)"
    echo "      4) www.microsoft.com  (enterprise)"
    echo "      5) Custom"
    read -r -p "    Choice [1]: " dc
    case "${dc:-1}" in
        2) HTTP_DOMAIN="www.cloudflare.com" ;;
        3) HTTP_DOMAIN="api.github.com" ;;
        4) HTTP_DOMAIN="www.microsoft.com" ;;
        5) read -r -p "    Domain: " HTTP_DOMAIN; HTTP_DOMAIN="${HTTP_DOMAIN:-www.google.com}" ;;
        *) HTTP_DOMAIN="www.google.com" ;;
    esac

    read -r -p "    Fake path [/search]: " HTTP_PATH
    HTTP_PATH="${HTTP_PATH:-/search}"

    echo ""
    echo "    User-Agent:"
    echo "      1) Chrome Windows ⭐"
    echo "      2) Firefox Windows"
    echo "      3) Chrome macOS"
    echo "      4) Safari macOS"
    echo "      5) Chrome Android"
    echo "      6) Custom"
    read -r -p "    Choice [1]: " uc
    case "${uc:-1}" in
        2) HTTP_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0" ;;
        3) HTTP_UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36" ;;
        4) HTTP_UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15" ;;
        5) HTTP_UA="Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.6167.144 Mobile Safari/537.36" ;;
        6) read -r -p "    User-Agent: " HTTP_UA ;;
        *) HTTP_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36" ;;
    esac

    read -r -p "    Chunked encoding? [Y/n]: " ch
    [[ "$ch" =~ ^[Nn]$ ]] && HTTP_CHUNKED="false" || HTTP_CHUNKED="true"

    read -r -p "    Session cookies? [Y/n]: " ck
    [[ "$ck" =~ ^[Nn]$ ]] && HTTP_COOKIES="false" || HTTP_COOKIES="true"

    USE_HTTP_MIMIC="true"
    echo -e "  ${GREEN}✓ HTTP Mimicry: ${HTTP_DOMAIN}${HTTP_PATH}${NC}"
}

# ============================================================================
# OBFUSCATION
# ============================================================================

configure_obfuscation() {
    echo ""
    echo -e "  ${CYAN}══════════════════════════════════════${NC}"
    echo -e "  ${CYAN}     TRAFFIC OBFUSCATION${NC}"
    echo -e "  ${CYAN}══════════════════════════════════════${NC}"
    echo ""
    echo "    1) Gaming/Streaming  — min overhead, near-zero delay ⭐"
    echo "    2) Stealth           — max hidden, more overhead"
    echo "    3) Balanced          — middle ground"
    echo "    4) Off               — disable"
    echo "    5) Custom"
    echo ""
    read -r -p "    Choice [1]: " oc
    case "${oc:-1}" in
        1)
            OBFUS_ENABLED="true"
            OBFUS_MIN_PAD=8;   OBFUS_MAX_PAD=32
            OBFUS_MIN_DELAY=0; OBFUS_MAX_DELAY=0; OBFUS_BURST="0"
            ;;
        2)
            OBFUS_ENABLED="true"
            OBFUS_MIN_PAD=128; OBFUS_MAX_PAD=2048
            OBFUS_MIN_DELAY=15; OBFUS_MAX_DELAY=150; OBFUS_BURST="0.3"
            ;;
        3)
            OBFUS_ENABLED="true"
            OBFUS_MIN_PAD=16;  OBFUS_MAX_PAD=512
            OBFUS_MIN_DELAY=5; OBFUS_MAX_DELAY=50; OBFUS_BURST="0.15"
            ;;
        4)
            OBFUS_ENABLED="false"
            OBFUS_MIN_PAD=0; OBFUS_MAX_PAD=0
            OBFUS_MIN_DELAY=0; OBFUS_MAX_DELAY=0; OBFUS_BURST="0"
            ;;
        5)
            OBFUS_ENABLED="true"
            read -r -p "    Min padding [8]: "  OBFUS_MIN_PAD;   OBFUS_MIN_PAD="${OBFUS_MIN_PAD:-8}"
            read -r -p "    Max padding [32]: " OBFUS_MAX_PAD;   OBFUS_MAX_PAD="${OBFUS_MAX_PAD:-32}"
            read -r -p "    Min delay ms [0]: " OBFUS_MIN_DELAY; OBFUS_MIN_DELAY="${OBFUS_MIN_DELAY:-0}"
            read -r -p "    Max delay ms [0]: " OBFUS_MAX_DELAY; OBFUS_MAX_DELAY="${OBFUS_MAX_DELAY:-0}"
            read -r -p "    Burst chance [0]: " OBFUS_BURST;     OBFUS_BURST="${OBFUS_BURST:-0}"
            ;;
    esac
    echo -e "  ${GREEN}✓ Obfuscation: enabled=${OBFUS_ENABLED}, pad=${OBFUS_MIN_PAD}-${OBFUS_MAX_PAD}${NC}"
}

# ============================================================================
# ADVANCED SETTINGS
# ============================================================================

configure_advanced() {
    echo ""
    read -r -p "  Configure advanced settings (SMUX/TCP/UDP)? [y/N]: " adv
    [[ "$adv" =~ ^[Yy]$ ]] || return

    echo ""
    echo -e "  ${YELLOW}── SMUX ──${NC}"
    read -r -p "    KeepAlive seconds [${SMUX_KEEPALIVE}]: " v; SMUX_KEEPALIVE="${v:-$SMUX_KEEPALIVE}"
    read -r -p "    Max recv buffer  [${SMUX_MAXRECV}]: "   v; SMUX_MAXRECV="${v:-$SMUX_MAXRECV}"
    read -r -p "    Max stream buf   [${SMUX_MAXSTREAM}]: " v; SMUX_MAXSTREAM="${v:-$SMUX_MAXSTREAM}"
    read -r -p "    Frame size       [${SMUX_FRAMESIZE}]: " v; SMUX_FRAMESIZE="${v:-$SMUX_FRAMESIZE}"

    echo ""
    echo -e "  ${YELLOW}── TCP ──${NC}"
    read -r -p "    NoDelay? [Y/n]: " nd
    [[ "$nd" =~ ^[Nn]$ ]] && TCP_NODELAY="false" || TCP_NODELAY="true"
    read -r -p "    KeepAlive seconds [${TCP_KEEPALIVE}]: "  v; TCP_KEEPALIVE="${v:-$TCP_KEEPALIVE}"
    read -r -p "    Read buffer bytes [${TCP_READBUF}]: "    v; TCP_READBUF="${v:-$TCP_READBUF}"
    read -r -p "    Write buffer bytes [${TCP_WRITEBUF}]: "  v; TCP_WRITEBUF="${v:-$TCP_WRITEBUF}"

    echo ""
    echo -e "  ${YELLOW}── Connections ──${NC}"
    read -r -p "    Max connections [${MAX_CONN}]: "     v; MAX_CONN="${v:-$MAX_CONN}"
    read -r -p "    Conn timeout s  [${CONN_TIMEOUT}]: " v; CONN_TIMEOUT="${v:-$CONN_TIMEOUT}"
    read -r -p "    Stream timeout  [${STREAM_TIMEOUT}]: " v; STREAM_TIMEOUT="${v:-$STREAM_TIMEOUT}"
    read -r -p "    Cleanup interval [${CLEANUP_INTERVAL}]: " v; CLEANUP_INTERVAL="${v:-$CLEANUP_INTERVAL}"

    echo ""
    echo -e "  ${YELLOW}── UDP ──${NC}"
    read -r -p "    Max UDP flows [${MAX_UDP_FLOWS}]: "    v; MAX_UDP_FLOWS="${v:-$MAX_UDP_FLOWS}"
    read -r -p "    UDP flow timeout [${UDP_FLOW_TIMEOUT}]: " v; UDP_FLOW_TIMEOUT="${v:-$UDP_FLOW_TIMEOUT}"
    read -r -p "    UDP buffer bytes [${UDP_BUFSIZE}]: "   v; UDP_BUFSIZE="${v:-$UDP_BUFSIZE}"

    echo -e "  ${GREEN}✓ Advanced settings saved${NC}"
}

# ============================================================================
# PORT MAPPING COLLECTOR
# ============================================================================

collect_port_mappings() {
    MAPPINGS_YAML=""
    local count=0

    echo ""
    echo -e "  ${CYAN}══════════════════════════════════════${NC}"
    echo -e "  ${CYAN}         PORT MAPPINGS${NC}"
    echo -e "  ${CYAN}══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}Formats:${NC}"
    echo "    443            → single port"
    echo "    80/90          → range 80 to 90"
    echo "    3000=8080      → bind 3000, target 8080"
    echo "    80/90=8080/8090 → range map"
    echo ""

    while true; do
        count=$((count+1))
        echo -e "  ${YELLOW}━━━━ Mapping #${count} ━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Protocol
        echo "    Protocol:  1) tcp   2) udp   3) both"
        read -r -p "    Choice [1]: " pc
        local proto
        case "${pc:-1}" in
            2) proto="udp" ;;
            3) proto="both" ;;
            *) proto="tcp" ;;
        esac

        # Bind IP / Target IP
        read -r -p "    Bind IP   [0.0.0.0]:   " bind_ip
        bind_ip="${bind_ip:-0.0.0.0}"
        read -r -p "    Target IP [127.0.0.1]: " target_ip
        target_ip="${target_ip:-127.0.0.1}"

        # Port input
        read -r -p "    Port(s): " port_raw
        port_raw="${port_raw// /}"

        if [ -z "$port_raw" ]; then
            echo -e "    ${RED}Port cannot be empty${NC}"
            count=$((count-1)); continue
        fi

        local new_entries="" ok=1

        # Range map: 80/90=8080/8090
        if [[ "$port_raw" =~ ^([0-9]+)/([0-9]+)=([0-9]+)/([0-9]+)$ ]]; then
            local bs="${BASH_REMATCH[1]}" be="${BASH_REMATCH[2]}"
            local ts="${BASH_REMATCH[3]}" te="${BASH_REMATCH[4]}"
            local blen=$(( be-bs+1 )) tlen=$(( te-ts+1 ))
            if [ "$blen" -ne "$tlen" ]; then
                echo -e "    ${RED}Range size mismatch (bind=$blen, target=$tlen)${NC}"
                ok=0
            else
                for (( i=0; i<blen; i++ )); do
                    local bp=$(( bs+i )) tp=$(( ts+i ))
                    _add_mapping_entry "$proto" "$bind_ip" "$bp" "$target_ip" "$tp"
                    new_entries+="$_MENTRY"
                done
                echo -e "    ${GREEN}✓ ${blen} mappings: ${bs}→${ts} … ${be}→${te} (${proto})${NC}"
            fi

        # Simple range: 80/90
        elif [[ "$port_raw" =~ ^([0-9]+)/([0-9]+)$ ]]; then
            local sp="${BASH_REMATCH[1]}" ep="${BASH_REMATCH[2]}"
            if [ "$sp" -gt "$ep" ]; then
                echo -e "    ${RED}Start > end${NC}"; ok=0
            else
                local rsize=$(( ep-sp+1 ))
                if [ "$rsize" -gt 500 ]; then
                    read -r -p "    Large range (${rsize} ports). Continue? [y/N]: " cv
                    [[ "$cv" =~ ^[Yy]$ ]] || { count=$((count-1)); continue; }
                fi
                for (( p=sp; p<=ep; p++ )); do
                    _add_mapping_entry "$proto" "$bind_ip" "$p" "$target_ip" "$p"
                    new_entries+="$_MENTRY"
                done
                echo -e "    ${GREEN}✓ ${rsize} mappings: ${sp}→${ep} (${proto})${NC}"
            fi

        # Custom map: 3000=8080
        elif [[ "$port_raw" =~ ^([0-9]+)=([0-9]+)$ ]]; then
            local bp="${BASH_REMATCH[1]}" tp="${BASH_REMATCH[2]}"
            if ! validate_port "$bp" || ! validate_port "$tp"; then
                echo -e "    ${RED}Invalid port${NC}"; ok=0
            else
                _add_mapping_entry "$proto" "$bind_ip" "$bp" "$target_ip" "$tp"
                new_entries+="$_MENTRY"
                echo -e "    ${GREEN}✓ ${bind_ip}:${bp} → ${target_ip}:${tp} (${proto})${NC}"
            fi

        # Single port
        elif [[ "$port_raw" =~ ^[0-9]+$ ]]; then
            if ! validate_port "$port_raw"; then
                echo -e "    ${RED}Invalid port (1-65535)${NC}"; ok=0
            else
                _add_mapping_entry "$proto" "$bind_ip" "$port_raw" "$target_ip" "$port_raw"
                new_entries+="$_MENTRY"
                echo -e "    ${GREEN}✓ ${bind_ip}:${port_raw} → ${target_ip}:${port_raw} (${proto})${NC}"
            fi
        else
            echo -e "    ${RED}Invalid format${NC}"; ok=0
        fi

        if [ "$ok" -eq 0 ]; then
            count=$((count-1)); continue
        fi

        MAPPINGS_YAML+="$new_entries"

        echo ""
        read -r -p "    Add another mapping? [y/N]: " more
        [[ "$more" =~ ^[Yy]$ ]] || break
    done
}

# Helper: build mapping YAML lines into $_MENTRY
_MENTRY=""
_add_mapping_entry() {
    local proto="$1" bip="$2" bp="$3" tip="$4" tp="$5"
    _MENTRY=""
    if [ "$proto" = "both" ]; then
        _MENTRY+="  - type: tcp\n    bind: \"${bip}:${bp}\"\n    target: \"${tip}:${tp}\"\n"
        _MENTRY+="  - type: udp\n    bind: \"${bip}:${bp}\"\n    target: \"${tip}:${tp}\"\n"
    else
        _MENTRY+="  - type: ${proto}\n    bind: \"${bip}:${bp}\"\n    target: \"${tip}:${tp}\"\n"
    fi
}

# ============================================================================
# SYSTEMD SERVICE
# ============================================================================

create_service() {
    local mode="$1"
    local svc="daggerbridge-${mode}"
    cat > "${SYSTEMD_DIR}/${svc}.service" << EOF
[Unit]
Description=DaggerBridge Reverse Tunnel - ${mode^}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${CONFIG_DIR}
ExecStart=${BINARY_PATH} -c ${CONFIG_DIR}/${mode}.yaml
Restart=always
RestartSec=3
StartLimitInterval=0
LimitNOFILE=1048576
LimitNPROC=65536
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    echo -e "  ${GREEN}✓ Service created: ${svc}${NC}"
}

# ============================================================================
# CONFIG WRITER - SERVER
# ============================================================================

write_server_config() {
    local cfg="$CONFIG_DIR/server.yaml"
    mkdir -p "$CONFIG_DIR"
    : > "$cfg"

    # ── Base ──
    cat >> "$cfg" << EOF
# DaggerBridge Server Config (Iran)
# Generated: $(date)
# Profile: ${PROFILE}

mode: "server"
listen: "0.0.0.0:${LISTEN_PORT}"
transport: "${TRANSPORT}"
psk: "${PSK}"
profile: "${PROFILE}"
verbose: ${VERBOSE}
heartbeat: 2

EOF

    # ── TLS certs ──
    if [ -n "$CERT_FILE" ]; then
        cat >> "$cfg" << EOF
cert_file: "${CERT_FILE}"
key_file: "${KEY_FILE}"

EOF
    fi

    # ── Port mappings ──
    if [ -n "$MAPPINGS_YAML" ]; then
        printf "maps:\n%b\n" "$MAPPINGS_YAML" >> "$cfg"
    fi

    # ── Obfuscation ──
    cat >> "$cfg" << EOF

obfuscation:
  enabled: ${OBFUS_ENABLED}
  min_padding: ${OBFUS_MIN_PAD}
  max_padding: ${OBFUS_MAX_PAD}
  min_delay_ms: ${OBFUS_MIN_DELAY}
  max_delay_ms: ${OBFUS_MAX_DELAY}
  burst_chance: ${OBFUS_BURST}
EOF

    # ── HTTP Mimicry ──
    if [ "$USE_HTTP_MIMIC" = "true" ]; then
        cat >> "$cfg" << EOF

http_mimic:
  fake_domain: "${HTTP_DOMAIN}"
  fake_path: "${HTTP_PATH}"
  user_agent: "${HTTP_UA}"
  chunked_encoding: ${HTTP_CHUNKED}
  session_cookie: ${HTTP_COOKIES}
  custom_headers:
    - "X-Requested-With: XMLHttpRequest"
    - "Referer: https://${HTTP_DOMAIN}/"
    - "Accept-Language: en-US,en;q=0.9"
    - "Accept-Encoding: gzip, deflate, br"
EOF
    fi

    # ── SMUX ──
    cat >> "$cfg" << EOF

smux:
  keepalive: ${SMUX_KEEPALIVE}
  max_recv: ${SMUX_MAXRECV}
  max_stream: ${SMUX_MAXSTREAM}
  frame_size: ${SMUX_FRAMESIZE}
  version: 2
EOF

    # ── Advanced ──
    cat >> "$cfg" << EOF

advanced:
  tcp_nodelay: ${TCP_NODELAY}
  tcp_keepalive: ${TCP_KEEPALIVE}
  tcp_read_buffer: ${TCP_READBUF}
  tcp_write_buffer: ${TCP_WRITEBUF}
  websocket_read_buffer: ${WS_READBUF}
  websocket_write_buffer: ${WS_WRITEBUF}
  websocket_compression: ${WS_COMPRESSION}
  max_connections: ${MAX_CONN}
  connection_timeout: ${CONN_TIMEOUT}
  stream_timeout: ${STREAM_TIMEOUT}
  session_timeout: ${SESSION_TIMEOUT}
  cleanup_interval: ${CLEANUP_INTERVAL}
  max_udp_flows: ${MAX_UDP_FLOWS}
  udp_flow_timeout: ${UDP_FLOW_TIMEOUT}
  udp_buffer_size: ${UDP_BUFSIZE}
EOF

    chmod 600 "$cfg"
    echo -e "  ${GREEN}✓ Config written: ${cfg}${NC}"
}

# ============================================================================
# CONFIG WRITER - CLIENT
# ============================================================================

write_client_config() {
    local cfg="$CONFIG_DIR/client.yaml"
    mkdir -p "$CONFIG_DIR"
    : > "$cfg"

    cat >> "$cfg" << EOF
# DaggerBridge Client Config (Foreign)
# Generated: $(date)
# Profile: ${PROFILE}

mode: "client"
psk: "${PSK}"
profile: "${PROFILE}"
verbose: ${VERBOSE}
heartbeat: 2

paths:
EOF

    local i
    for (( i=0; i<${#PATH_TRANSPORTS[@]}; i++ )); do
        cat >> "$cfg" << EOF
  - transport: "${PATH_TRANSPORTS[$i]}"
    addr: "${PATH_ADDRS[$i]}"
    connection_pool: ${PATH_POOLS[$i]}
    aggressive_pool: ${PATH_AGGPOOL[$i]}
    retry_interval: ${PATH_RETRY[$i]}
    dial_timeout: ${PATH_TIMEOUT[$i]}
EOF
    done

    # ── Obfuscation ──
    cat >> "$cfg" << EOF

obfuscation:
  enabled: ${OBFUS_ENABLED}
  min_padding: ${OBFUS_MIN_PAD}
  max_padding: ${OBFUS_MAX_PAD}
  min_delay_ms: ${OBFUS_MIN_DELAY}
  max_delay_ms: ${OBFUS_MAX_DELAY}
  burst_chance: ${OBFUS_BURST}
EOF

    # ── HTTP Mimicry ──
    if [ "$USE_HTTP_MIMIC" = "true" ]; then
        cat >> "$cfg" << EOF

http_mimic:
  fake_domain: "${HTTP_DOMAIN}"
  fake_path: "${HTTP_PATH}"
  user_agent: "${HTTP_UA}"
  chunked_encoding: ${HTTP_CHUNKED}
  session_cookie: ${HTTP_COOKIES}
  custom_headers:
    - "X-Requested-With: XMLHttpRequest"
    - "Referer: https://${HTTP_DOMAIN}/"
    - "Accept-Language: en-US,en;q=0.9"
    - "Accept-Encoding: gzip, deflate, br"
EOF
    fi

    # ── SMUX ──
    cat >> "$cfg" << EOF

smux:
  keepalive: ${SMUX_KEEPALIVE}
  max_recv: ${SMUX_MAXRECV}
  max_stream: ${SMUX_MAXSTREAM}
  frame_size: ${SMUX_FRAMESIZE}
  version: 2
EOF

    # ── Advanced ──
    cat >> "$cfg" << EOF

advanced:
  tcp_nodelay: ${TCP_NODELAY}
  tcp_keepalive: ${TCP_KEEPALIVE}
  tcp_read_buffer: ${TCP_READBUF}
  tcp_write_buffer: ${TCP_WRITEBUF}
  websocket_read_buffer: ${WS_READBUF}
  websocket_write_buffer: ${WS_WRITEBUF}
  websocket_compression: ${WS_COMPRESSION}
  max_connections: ${MAX_CONN}
  connection_timeout: ${CONN_TIMEOUT}
  stream_timeout: ${STREAM_TIMEOUT}
  session_timeout: ${SESSION_TIMEOUT}
  cleanup_interval: ${CLEANUP_INTERVAL}
  max_udp_flows: ${MAX_UDP_FLOWS}
  udp_flow_timeout: ${UDP_FLOW_TIMEOUT}
  udp_buffer_size: ${UDP_BUFSIZE}
EOF

    chmod 600 "$cfg"
    echo -e "  ${GREEN}✓ Config written: ${cfg}${NC}"
}

# ============================================================================
# INSTALL SERVER
# ============================================================================

install_server() {
    show_banner
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo -e "${CYAN}       SERVER SETUP  (Iran)${NC}"
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}Mode:${NC}"
    echo "    1) Quick  — gaming + httpsmux + google mimicry (best defaults)"
    echo "    2) Custom — choose everything manually"
    echo ""
    read -r -p "  Choice [1]: " mode_choice

    # ── PSK ──
    echo ""
    while true; do
        read -r -s -p "  PSK (Pre-Shared Key): " PSK; echo
        [ -n "$PSK" ] && break
        echo -e "  ${RED}PSK cannot be empty!${NC}"
    done

    # ── Quick Mode ──
    if [ "${mode_choice:-1}" != "2" ]; then
        echo ""
        echo -e "  ${CYAN}Quick Mode: gaming + httpsmux + google.com mimicry${NC}"

        read -r -p "  Tunnel listen port [2020]: " LISTEN_PORT
        LISTEN_PORT="${LISTEN_PORT:-2020}"

        TRANSPORT="httpsmux"
        PROFILE="gaming"
        VERBOSE="false"
        USE_HTTP_MIMIC="true"

        # Gaming profile settings
        SMUX_KEEPALIVE=1; SMUX_MAXRECV=524288; SMUX_MAXSTREAM=524288; SMUX_FRAMESIZE=2048
        TCP_NODELAY="true"; TCP_KEEPALIVE=3; TCP_READBUF=32768; TCP_WRITEBUF=32768
        MAX_CONN=300; CONN_TIMEOUT=20; STREAM_TIMEOUT=45; CLEANUP_INTERVAL=1; SESSION_TIMEOUT=15
        MAX_UDP_FLOWS=150; UDP_FLOW_TIMEOUT=90; UDP_BUFSIZE=262144
        OBFUS_ENABLED="true"; OBFUS_MIN_PAD=8; OBFUS_MAX_PAD=32
        OBFUS_MIN_DELAY=0; OBFUS_MAX_DELAY=0; OBFUS_BURST="0"

        # Generate SSL cert
        echo ""
        echo -e "  ${YELLOW}Generating TLS certificate (needed for httpsmux)...${NC}"
        generate_ssl_cert

        collect_port_mappings

    # ── Custom Mode ──
    else
        read -r -p "  Tunnel listen port [2020]: " LISTEN_PORT
        LISTEN_PORT="${LISTEN_PORT:-2020}"
        while ! validate_port "$LISTEN_PORT"; do
            echo -e "  ${RED}Invalid port${NC}"
            read -r -p "  Tunnel listen port: " LISTEN_PORT
        done

        select_transport
        select_profile

        # TLS cert for wssmux / httpsmux
        CERT_FILE=""; KEY_FILE=""
        if [ "$TRANSPORT" = "wssmux" ] || [ "$TRANSPORT" = "httpsmux" ]; then
            echo ""
            echo "  TLS Certificate:"
            echo "    1) Generate self-signed"
            echo "    2) Use existing files"
            read -r -p "  Choice [1]: " cc
            if [ "${cc:-1}" = "2" ]; then
                read -r -p "  Cert file path: " CERT_FILE
                read -r -p "  Key file path:  " KEY_FILE
                if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
                    echo -e "  ${YELLOW}Files not found, generating...${NC}"
                    generate_ssl_cert
                fi
            else
                generate_ssl_cert
            fi
        fi

        # HTTP Mimicry
        USE_HTTP_MIMIC="false"
        if [ "$TRANSPORT" = "httpmux" ] || [ "$TRANSPORT" = "httpsmux" ]; then
            configure_http_mimicry
        fi

        configure_obfuscation
        configure_advanced
        collect_port_mappings

        read -r -p "  Enable verbose logging? [y/N]: " vb
        [[ "$vb" =~ ^[Yy]$ ]] && VERBOSE="true" || VERBOSE="false"
    fi

    write_server_config
    create_service "server"

    echo ""
    read -r -p "  Run system optimizer? [Y/n]: " opt
    [[ "$opt" =~ ^[Nn]$ ]] || optimize_system "iran"

    systemctl enable --now daggerbridge-server

    echo ""
    echo -e "  ${GREEN}══════════════════════════════════════${NC}"
    echo -e "  ${GREEN}    ✓ Server installation complete!${NC}"
    echo -e "  ${GREEN}══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Tunnel port : ${GREEN}${LISTEN_PORT}${NC}"
    echo -e "  ${CYAN}Transport   : ${GREEN}${TRANSPORT}${NC}"
    echo -e "  ${CYAN}Profile     : ${GREEN}${PROFILE}${NC}"
    echo -e "  ${CYAN}PSK         : ${GREEN}${PSK}${NC}"
    echo -e "  ${CYAN}Config      : ${GREEN}${CONFIG_DIR}/server.yaml${NC}"
    echo ""
    echo -e "  ${YELLOW}Logs:${NC} journalctl -u daggerbridge-server -f"
    echo ""
    press_enter
    main_menu
}

# ============================================================================
# INSTALL CLIENT
# ============================================================================

install_client() {
    show_banner
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo -e "${CYAN}       CLIENT SETUP  (Foreign)${NC}"
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}Mode:${NC}"
    echo "    1) Quick  — gaming + httpsmux + google mimicry"
    echo "    2) Custom — choose everything manually"
    echo ""
    read -r -p "  Choice [1]: " mode_choice

    # ── PSK ──
    echo ""
    while true; do
        read -r -s -p "  PSK (must match server): " PSK; echo
        [ -n "$PSK" ] && break
        echo -e "  ${RED}PSK cannot be empty!${NC}"
    done

    # ── Reset path arrays ──
    PATH_TRANSPORTS=(); PATH_ADDRS=(); PATH_POOLS=()
    PATH_AGGPOOL=(); PATH_RETRY=(); PATH_TIMEOUT=()

    # ── Quick Mode ──
    if [ "${mode_choice:-1}" != "2" ]; then
        echo ""
        echo -e "  ${CYAN}Quick Mode: gaming + httpsmux + google.com mimicry${NC}"
        echo ""

        read -r -p "  Iran server IP or domain: " IRAN_IP
        while [ -z "$IRAN_IP" ]; do
            echo -e "  ${RED}Cannot be empty${NC}"
            read -r -p "  Iran server IP or domain: " IRAN_IP
        done

        read -r -p "  Tunnel port [2020]: " TPORT
        TPORT="${TPORT:-2020}"

        TRANSPORT="httpsmux"
        PROFILE="gaming"
        VERBOSE="false"
        USE_HTTP_MIMIC="true"
        HTTP_DOMAIN="www.google.com"; HTTP_PATH="/search"
        HTTP_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
        HTTP_CHUNKED="true"; HTTP_COOKIES="true"

        SMUX_KEEPALIVE=1; SMUX_MAXRECV=524288; SMUX_MAXSTREAM=524288; SMUX_FRAMESIZE=2048
        TCP_NODELAY="true"; TCP_KEEPALIVE=3; TCP_READBUF=32768; TCP_WRITEBUF=32768
        MAX_CONN=300; CONN_TIMEOUT=20; STREAM_TIMEOUT=45; CLEANUP_INTERVAL=1; SESSION_TIMEOUT=15
        MAX_UDP_FLOWS=150; UDP_FLOW_TIMEOUT=90; UDP_BUFSIZE=262144
        OBFUS_ENABLED="true"; OBFUS_MIN_PAD=8; OBFUS_MAX_PAD=32
        OBFUS_MIN_DELAY=0; OBFUS_MAX_DELAY=0; OBFUS_BURST="0"

        PATH_TRANSPORTS+=("httpsmux")
        PATH_ADDRS+=("${IRAN_IP}:${TPORT}")
        PATH_POOLS+=("3")
        PATH_AGGPOOL+=("true")
        PATH_RETRY+=("1")
        PATH_TIMEOUT+=("5")

    # ── Custom Mode ──
    else
        select_profile

        USE_HTTP_MIMIC="false"
        configure_obfuscation
        configure_advanced

        # Multi-path
        echo ""
        echo -e "  ${CYAN}══════════════════════════════════════${NC}"
        echo -e "  ${CYAN}      CONNECTION PATHS${NC}"
        echo -e "  ${CYAN}══════════════════════════════════════${NC}"
        echo -e "  ${YELLOW}  Multiple paths = automatic failover${NC}"
        echo ""

        local pcount=0
        while true; do
            pcount=$((pcount+1))
            echo -e "  ${YELLOW}Path #${pcount}:${NC}"
            select_transport
            local t="$TRANSPORT"

            read -r -p "  Server IP:TunnelPort (e.g. 1.2.3.4:2020): " addr
            while [ -z "$addr" ]; do
                echo -e "  ${RED}Cannot be empty${NC}"
                read -r -p "  Server IP:Port: " addr
            done

            read -r -p "  Connection pool [2]: " pool;   pool="${pool:-2}"
            read -r -p "  Aggressive pool? [y/N]: " agg
            [[ "$agg" =~ ^[Yy]$ ]] && aggp="true" || aggp="false"
            read -r -p "  Retry interval s [3]: " retry; retry="${retry:-3}"
            read -r -p "  Dial timeout s [10]: " dtout;  dtout="${dtout:-10}"

            PATH_TRANSPORTS+=("$t")
            PATH_ADDRS+=("$addr")
            PATH_POOLS+=("$pool")
            PATH_AGGPOOL+=("$aggp")
            PATH_RETRY+=("$retry")
            PATH_TIMEOUT+=("$dtout")

            if [ "$t" = "httpmux" ] || [ "$t" = "httpsmux" ]; then
                if [ "$USE_HTTP_MIMIC" = "false" ]; then
                    configure_http_mimicry
                fi
            fi

            echo -e "  ${GREEN}✓ Path added: $t → $addr${NC}"
            read -r -p "  Add another path? [y/N]: " more
            [[ "$more" =~ ^[Yy]$ ]] || break
        done

        read -r -p "  Verbose logging? [y/N]: " vb
        [[ "$vb" =~ ^[Yy]$ ]] && VERBOSE="true" || VERBOSE="false"
    fi

    write_client_config
    create_service "client"

    echo ""
    read -r -p "  Run system optimizer? [Y/n]: " opt
    [[ "$opt" =~ ^[Nn]$ ]] || optimize_system "foreign"

    systemctl enable --now daggerbridge-client

    echo ""
    echo -e "  ${GREEN}══════════════════════════════════════${NC}"
    echo -e "  ${GREEN}    ✓ Client installation complete!${NC}"
    echo -e "  ${GREEN}══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Server    : ${GREEN}${PATH_ADDRS[0]}${NC}"
    echo -e "  ${CYAN}Transport : ${GREEN}${PATH_TRANSPORTS[0]}${NC}"
    echo -e "  ${CYAN}Profile   : ${GREEN}${PROFILE}${NC}"
    echo -e "  ${CYAN}Config    : ${GREEN}${CONFIG_DIR}/client.yaml${NC}"
    echo ""
    echo -e "  ${YELLOW}Logs:${NC} journalctl -u daggerbridge-client -f"
    echo ""
    press_enter
    main_menu
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

manage_service() {
    local mode="$1"
    local svc="daggerbridge-${mode}"
    local cfg="${CONFIG_DIR}/${mode}.yaml"

    show_banner
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo -e "${CYAN}    ${mode^^} SERVICE MANAGEMENT${NC}"
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo ""
    echo -e "  Status: $(svc_status "$svc")"
    echo ""
    echo "    1) Start          6) Enable Auto-start"
    echo "    2) Stop           7) Disable Auto-start"
    echo "    3) Restart        8) View Config"
    echo "    4) Status         9) Edit Config"
    echo "    5) Live Logs     10) Delete"
    echo ""
    echo "    0) Back"
    echo ""
    read -r -p "  Select: " ch

    case "$ch" in
        1)  systemctl start "$svc"   && echo -e "  ${GREEN}✓ Started${NC}"   || echo -e "  ${RED}✖ Failed${NC}"; sleep 1; manage_service "$mode" ;;
        2)  systemctl stop "$svc"    && echo -e "  ${GREEN}✓ Stopped${NC}";  sleep 1; manage_service "$mode" ;;
        3)  systemctl restart "$svc" && echo -e "  ${GREEN}✓ Restarted${NC}" || echo -e "  ${RED}✖ Failed${NC}"; sleep 1; manage_service "$mode" ;;
        4)  systemctl status "$svc" --no-pager; press_enter; manage_service "$mode" ;;
        5)  echo -e "  ${YELLOW}Ctrl+C to stop${NC}"; journalctl -u "$svc" -f; manage_service "$mode" ;;
        6)  systemctl enable "$svc"  && echo -e "  ${GREEN}✓ Enabled${NC}";  sleep 1; manage_service "$mode" ;;
        7)  systemctl disable "$svc" && echo -e "  ${GREEN}✓ Disabled${NC}"; sleep 1; manage_service "$mode" ;;
        8)  echo ""; [ -f "$cfg" ] && cat "$cfg" || echo -e "  ${RED}Not found${NC}"; press_enter; manage_service "$mode" ;;
        9)  if [ -f "$cfg" ]; then
                "${EDITOR:-nano}" "$cfg"
                read -r -p "  Restart to apply? [Y/n]: " rs
                [[ "$rs" =~ ^[Nn]$ ]] || { systemctl restart "$svc"; echo -e "  ${GREEN}✓ Restarted${NC}"; sleep 1; }
            else
                echo -e "  ${RED}Config not found${NC}"; sleep 1
            fi
            manage_service "$mode" ;;
        10) if confirm "Delete $mode config and service?"; then
                systemctl stop    "$svc" 2>/dev/null || true
                systemctl disable "$svc" 2>/dev/null || true
                rm -f "$cfg" "${SYSTEMD_DIR}/${svc}.service"
                systemctl daemon-reload
                echo -e "  ${GREEN}✓ Deleted${NC}"; sleep 1
            fi
            settings_menu ;;
        0)  settings_menu ;;
        *)  manage_service "$mode" ;;
    esac
}

settings_menu() {
    show_banner
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo -e "${CYAN}           SETTINGS MENU${NC}"
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo ""
    echo -e "  Server : $(svc_status "daggerbridge-server")"
    echo -e "  Client : $(svc_status "daggerbridge-client")"
    echo ""
    echo "    1) Manage Server"
    echo "    2) Manage Client"
    echo "    0) Back"
    echo ""
    read -r -p "  Select: " ch
    case "$ch" in
        1) manage_service "server" ;;
        2) manage_service "client" ;;
        0) main_menu ;;
        *) settings_menu ;;
    esac
}

# ============================================================================
# UNINSTALL
# ============================================================================

uninstall_menu() {
    show_banner
    echo -e "${RED}  ══════════════════════════════════════${NC}"
    echo -e "${RED}         UNINSTALL DAGGERBRIDGE${NC}"
    echo -e "${RED}  ══════════════════════════════════════${NC}"
    echo ""
    echo "  Will remove:"
    echo "    - Systemd services"
    echo "    - Configs: $CONFIG_DIR"
    echo "    - Sysctl: /etc/sysctl.d/99-daggerbridge.conf"
    echo ""
    echo -e "  ${YELLOW}Note: DaggerConnect binary is NOT removed${NC}"
    echo ""
    confirm "Are you sure?" || { main_menu; return; }
    confirm "Really? Cannot be undone!" || { main_menu; return; }

    for svc in daggerbridge-server daggerbridge-client; do
        systemctl stop    "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        rm -f "${SYSTEMD_DIR}/${svc}.service"
    done
    systemctl daemon-reload
    rm -rf "$CONFIG_DIR"
    rm -f /etc/sysctl.d/99-daggerbridge.conf
    sysctl --system > /dev/null 2>&1 || true

    echo -e "  ${GREEN}✓ DaggerBridge uninstalled${NC}"
    exit 0
}

# ============================================================================
# MAIN MENU
# ============================================================================

main_menu() {
    show_banner
    local bver
    bver=$("$BINARY_PATH" -v 2>&1 | grep -oP 'v[\d.]+' | head -1 || echo "unknown")

    echo -e "  ${CYAN}Binary  : ${GREEN}DaggerConnect ${bver}${NC}"
    echo -e "  ${CYAN}Server  : $(svc_status "daggerbridge-server")${NC}"
    echo -e "  ${CYAN}Client  : $(svc_status "daggerbridge-client")${NC}"
    echo ""
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo -e "${CYAN}             MAIN MENU${NC}"
    echo -e "${CYAN}  ══════════════════════════════════════${NC}"
    echo ""
    echo "    1) Install Server  (Iran)"
    echo "    2) Install Client  (Foreign)"
    echo "    3) Manage Services"
    echo "    4) System Optimizer"
    echo "    5) Uninstall"
    echo ""
    echo "    0) Exit"
    echo ""
    read -r -p "  Select: " ch
    case "$ch" in
        1) install_server ;;
        2) install_client ;;
        3) settings_menu ;;
        4) optimizer_menu ;;
        5) uninstall_menu ;;
        0) echo -e "  ${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "  ${RED}Invalid${NC}"; sleep 1; main_menu ;;
    esac
}

# ============================================================================
# ENTRY POINT
# ============================================================================

check_root
install_deps

if ! find_binary; then
    echo ""
    echo -e "${RED}  ══════════════════════════════════════════════════${NC}"
    echo -e "${RED}    DaggerConnect binary not found!${NC}"
    echo -e "${RED}  ══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Searched in:"
    for p in "${SEARCH_PATHS[@]}"; do echo "    $p"; done
    echo ""
    echo -e "  ${YELLOW}Copy your existing binary manually:${NC}"
    echo -e "    cp /path/to/DaggerConnect ${BINARY_PATH}"
    echo -e "    chmod +x ${BINARY_PATH}"
    echo -e "    sudo ./daggerbridge.sh"
    echo ""
    exit 1
fi

main_menu
