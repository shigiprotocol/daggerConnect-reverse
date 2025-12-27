#!/bin/bash

# DaggerConnect Installer v2.0 (Optimized)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Installation directories
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/DaggerConnect"
SYSTEMD_DIR="/etc/systemd/system"

GITHUB_REPO="https://github.com/itsFLoKi/DaggerConnect"
BINARY_URL="$GITHUB_REPO/raw/main/DaggerConnect"

# Banner
show_banner() {
    # Define colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color

    # Display the ASCII Art banner in a distinct color (e.g., CYAN or GREEN)
    echo -e "${CYAN}"
    echo "
  ██████  █████  ██████  ██████  ███████  ██████  ███
  ██   ██ ██  ██ ██   ██ ██   ██ ██      ██    ██  ██
  ██████  ██   ██ ██████  ██   ██ █████   ██    ██  ██
  ██   ██ ██  ██ ██   ██ ██   ██ ██      ██    ██  ██
  ██████  █████  ██   ██ ██████  ███████  ██████  ███

             __o__
            /  / \  \
           /  /   \  \  DaggerConnect
          /  / | | \  \ Reverse Tunnel Installer
         /  /  | |  \  \
        /  /   | |   \  \
       /  /____| |____\  \
      /____________________\
"
    echo -e "${NC}"
    echo -e "${GREEN}        DaggerConnect Installer v2.0 - Optimized Edition${NC}"
    echo ""
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root${NC}"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    if command -v apt &>/dev/null; then
        apt update -qq
        apt install -y wget curl tar git > /dev/null 2>&1 || { echo -e "${RED}Failed to install dependencies${NC}"; exit 1; }
    elif command -v yum &>/dev/null; then
        yum install -y wget curl tar git > /dev/null 2>&1 || { echo -e "${RED}Failed to install dependencies${NC}"; exit 1; }
    else
        echo -e "${RED}❌ Unsupported package manager${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# Download binary
download_binary() {
    echo -e "${YELLOW}⬇️  Downloading DaggerConnect binary...${NC}"
    mkdir -p "$INSTALL_DIR"

    if wget -q --show-progress "$BINARY_URL" -O "$INSTALL_DIR/DaggerConnect"; then
        chmod +x "$INSTALL_DIR/DaggerConnect"
        echo -e "${GREEN}✓ DaggerConnect downloaded successfully${NC}"

        if "$INSTALL_DIR/DaggerConnect" -version &>/dev/null; then
            VERSION=$("$INSTALL_DIR/DaggerConnect" -version 2>&1 | grep -oP 'v\d+\.\d+\.\d+' || echo "unknown")
            echo -e "${CYAN}ℹ️  Version: $VERSION${NC}"
        fi
    else
        echo -e "${RED}✖ Failed to download DaggerConnect binary${NC}"
        echo -e "${YELLOW}Please check your internet connection and try again${NC}"
        exit 1
    fi
}

# Create systemd service (Uses mode-specific naming)
create_systemd_service() {
    local MODE=$1
    local SERVICE_NAME="DaggerConnect-${MODE}"
    local SERVICE_FILE="$SYSTEMD_DIR/${SERVICE_NAME}.service"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=DaggerConnect Reverse Tunnel ${MODE^}
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$CONFIG_DIR
ExecStart=$INSTALL_DIR/DaggerConnect -c $CONFIG_DIR/${MODE}.yaml
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo -e "${GREEN}✓ Systemd service for ${MODE^} created: ${SERVICE_NAME}.service${NC}"
}

# ---------------------------
# Server Installation
# ---------------------------
install_server() {
    show_banner
    mkdir -p "$CONFIG_DIR"

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}      SERVER CONFIGURATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # Transport type
    echo -e "${YELLOW}Select Transport Type:${NC}"
    echo "  1) TCP (tcpmux)"
    echo "  2) KCP (kcpmux)"
    echo "  3) WebSocket (wsmux)"
    echo "  4) WebSocket Secure (wssmux)"
    echo ""
    read -p "Choice [1-4]: " transport_choice
    case $transport_choice in
        1) TRANSPORT="tcpmux" ;;
        2) TRANSPORT="kcpmux" ;;
        3) TRANSPORT="wsmux" ;;
        4) TRANSPORT="wssmux" ;;
        *) TRANSPORT="tcpmux" ;;
    esac

    # Listen port
    echo ""
    read -p "Listen Port Example 4000: " LISTEN_PORT
    LISTEN_PORT=${LISTEN_PORT:-4000}

    # PSK
    echo ""
    while true; do
        read -sp "Enter PSK (Pre-Shared Key): " PSK
        echo ""
        if [ -z "$PSK" ]; then
            echo -e "${RED}PSK cannot be empty!${NC}"
        else
            break
        fi
    done

    # Profile
    echo ""
    echo -e "${YELLOW}Select Performance Profile:${NC}"
    echo "  1) balanced (recommended)"
    echo "  2) aggressive"
    echo "  3) latency"
    echo "  4) cpu-efficient"
    echo ""
    read -p "Choice [1-4]: " profile_choice
    case $profile_choice in
        1) PROFILE="balanced" ;;
        2) PROFILE="aggressive" ;;
        3) PROFILE="latency" ;;
        4) PROFILE="cpu-efficient" ;;
        *) PROFILE="balanced" ;;
    esac

    # TLS for wssmux
    CERT_FILE=""
    KEY_FILE=""
    if [ "$TRANSPORT" == "wssmux" ]; then
        echo ""
        echo -e "${YELLOW}TLS Configuration:${NC}"
        read -p "Certificate file path: " CERT_FILE
        read -p "Private key file path: " KEY_FILE
        if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
            echo -e "${YELLOW}⚠️  Certificate files not found. You can add them later.${NC}"
            CERT_FILE=""
            KEY_FILE=""
        fi
    fi

    # Port mappings (simplified - only ports)
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}      PORT MAPPINGS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    MAPPINGS=""
    COUNT=0
    while true; do
        echo ""
        echo -e "${YELLOW}Add Port Mapping #$((COUNT+1))${NC}"

        # Protocol
        read -p "Protocol (tcp/udp) [tcp]: " PROTO
        PROTO=${PROTO:-tcp}

        # Bind port (simplified to only ask for port)
        read -p "Bind Port (e.g., 2020): " BIND_PORT
        if [ -z "$BIND_PORT" ]; then
            echo -e "${RED}Port cannot be empty!${NC}"
            continue
        fi

        # Target port
        read -p "Target Port (e.g., 22): " TARGET_PORT
        if [ -z "$TARGET_PORT" ]; then
            echo -e "${RED}Port cannot be empty!${NC}"
            continue
        fi

        # Build mapping with 0.0.0.0 for bind and 127.0.0.1 for target
        BIND="0.0.0.0:${BIND_PORT}"
        TARGET="127.0.0.1:${TARGET_PORT}"

        if [ $COUNT -eq 0 ]; then
            MAPPINGS="  - type: \"$PROTO\"\n    bind: \"$BIND\"\n    target: \"$TARGET\""
        else
            MAPPINGS="$MAPPINGS\n  - type: \"$PROTO\"\n    bind: \"$BIND\"\n    target: \"$TARGET\""
        fi
        COUNT=$((COUNT+1))

        echo -e "${GREEN}✓ Mapping added: $PROTO $BIND -> $TARGET${NC}"

        read -p "Add another mapping? [y/N]: " MORE
        [[ ! $MORE =~ ^[Yy]$ ]] && break
    done

    # Verbose
    echo ""
    read -p "Enable verbose logging? [y/N]: " VERBOSE
    [[ $VERBOSE =~ ^[Yy]$ ]] && VERBOSE="true" || VERBOSE="false"

    # Write config
    CONFIG_FILE="$CONFIG_DIR/server.yaml"
    cat > "$CONFIG_FILE" << EOF
mode: "server"
listen: "0.0.0.0:${LISTEN_PORT}"
transport: "${TRANSPORT}"
psk: "${PSK}"
profile: "${PROFILE}"
verbose: ${VERBOSE}

EOF

    # Add TLS if provided
    if [[ -n "$CERT_FILE" ]]; then
        cat >> "$CONFIG_FILE" << EOF
cert_file: "$CERT_FILE"
key_file: "$KEY_FILE"

EOF
    fi

    # Add mappings
    echo -e "maps:\n$MAPPINGS\n" >> "$CONFIG_FILE"

    # Add SMUX, KCP, Advanced settings (Using the consolidated settings from our previous chat)
    cat >> "$CONFIG_FILE" << 'EOF'
smux:
  keepalive: 10
  max_recv: 16777216
  max_stream: 16777216
  frame_size: 32768
  version: 2
  mux_con: 10

kcp:
  datashard: 10
  parityshard: 3
  acknodelay: false

advanced:
  tcp_nodelay: true
  tcp_keepalive: 30
  tcp_read_buffer: 16777216        # 16MB
  tcp_write_buffer: 16777216       # 16MB
  websocket_read_buffer: 262144    # 256KB
  websocket_write_buffer: 262144   # 256KB
  websocket_compression: false
  cleanup_interval: 60
  session_timeout: 180
  connection_timeout: 600
  stream_timeout: 21600
  stream_idle_timeout: 600
  max_connections: 0
  max_udp_flows: 10000
  udp_flow_timeout: 600

max_sessions: 0
heartbeat: 10
EOF

    create_systemd_service "server"

    # Start and enable the mode-specific service
    systemctl start DaggerConnect-server
    systemctl enable DaggerConnect-server

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✓ Server installation complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo "  View logs: journalctl -u DaggerConnect-server -f"
    echo ""
    read -p "Press Enter to return to menu..."
    main_menu
}

# ---------------------------
# Client Installation
# ---------------------------
install_client() {
    show_banner
    mkdir -p "$CONFIG_DIR"

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}      CLIENT CONFIGURATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # PSK
    while true; do
        read -sp "Enter PSK (must match server): " PSK
        echo ""
        if [ -z "$PSK" ]; then
            echo -e "${RED}PSK cannot be empty!${NC}"
        else
            break
        fi
    done

    # Profile
    echo ""
    echo -e "${YELLOW}Select Performance Profile:${NC}"
    echo "  1) balanced (recommended)"
    echo "  2) aggressive"
    echo "  3) latency"
    echo "  4) cpu-efficient"
    echo ""
    read -p "Choice [1-4]: " profile_choice
    case $profile_choice in
        1) PROFILE="balanced" ;;
        2) PROFILE="aggressive" ;;
        3) PROFILE="latency" ;;
        4) PROFILE="cpu-efficient" ;;
        *) PROFILE="balanced" ;;
    esac

    # Connection paths
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}      CONNECTION PATHS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    PATHS=""
    COUNT=0
    while true; do
        echo ""
        echo -e "${YELLOW}Add Connection Path #$((COUNT+1))${NC}"

        echo "Select Transport Type:"
        echo "  1) TCP (tcpmux)"
        echo "  2) KCP (kcpmux)"
        echo "  3) WebSocket (wsmux)"
        echo "  4) WebSocket Secure (wssmux)"
        echo ""
        read -p "Choice [1-4]: " transport_choice
        case $transport_choice in
            1) T="tcpmux" ;;
            2) T="kcpmux" ;;
            3) T="wsmux" ;;
            4) T="wssmux" ;;
            *) T="tcpmux" ;;
        esac

        read -p "Server address With Port Tunnel (e.g., 1.2.3.4:4000): " ADDR
        if [ -z "$ADDR" ]; then
            echo -e "${RED}Address cannot be empty!${NC}"
            continue
        fi

        read -p "Connection pool size [2]: " POOL
        POOL=${POOL:-2}

        if [ $COUNT -eq 0 ]; then
            PATHS="  - transport: \"$T\"\n    addr: \"$ADDR\"\n    connection_pool: $POOL\n    aggressive_pool: false\n    retry_interval: 3\n    dial_timeout: 10"
        else
            PATHS="$PATHS\n  - transport: \"$T\"\n    addr: \"$ADDR\"\n    connection_pool: $POOL\n    aggressive_pool: false\n    retry_interval: 3\n    dial_timeout: 10"
        fi
        COUNT=$((COUNT+1))

        echo -e "${GREEN}✓ Path added: $T -> $ADDR (pool: $POOL)${NC}"

        read -p "Add another path? [y/N]: " MORE
        [[ ! $MORE =~ ^[Yy]$ ]] && break
    done

    # Verbose
    echo ""
    read -p "Enable verbose logging? [y/N]: " VERBOSE
    [[ $VERBOSE =~ ^[Yy]$ ]] && VERBOSE="true" || VERBOSE="false"

    # Write config
    CONFIG_FILE="$CONFIG_DIR/client.yaml"
    cat > "$CONFIG_FILE" << EOF
mode: "client"
psk: "${PSK}"
profile: "${PROFILE}"
verbose: ${VERBOSE}

paths:
$PATHS

smux:
  keepalive: 10
  max_recv: 16777216
  max_stream: 16777216
  frame_size: 32768
  version: 2
  mux_con: 10

kcp:
  datashard: 10
  parityshard: 3
  acknodelay: false

advanced:
  tcp_nodelay: true
  tcp_keepalive: 30
  tcp_read_buffer: 16777216        # 16MB
  tcp_write_buffer: 16777216       # 16MB
  websocket_read_buffer: 262144    # 256KB
  websocket_write_buffer: 262144   # 256KB
  websocket_compression: false
  cleanup_interval: 60
  session_timeout: 180
  connection_timeout: 600
  stream_timeout: 21600
  stream_idle_timeout: 600
  max_connections: 0
  max_udp_flows: 10000
  udp_flow_timeout: 600

heartbeat: 10
EOF

    create_systemd_service "client"

    # Start and enable the mode-specific service
    systemctl start DaggerConnect-client
    systemctl enable DaggerConnect-client

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✓ Client installation complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Next steps (already started):${NC}"
    echo "  View logs: journalctl -u DaggerConnect-client -f"
    echo ""
    read -p "Press Enter to return to menu..."
    main_menu
}

# ---------------------------
# Consolidated Service Management (New Function)
# ---------------------------
service_management() {
    local MODE=$1
    local SERVICE_NAME="DaggerConnect-${MODE}"
    local CONFIG_FILE="$CONFIG_DIR/${MODE}.yaml"
    local TITLE="${MODE^} MANAGEMENT"

    show_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         ${TITLE}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "  1) Start ${MODE^}"
    echo "  2) Stop ${MODE^}"
    echo "  3) Restart ${MODE^}"
    echo "  4) ${MODE^} Status"
    echo "  5) View ${MODE^} Logs"
    echo "  6) Enable ${MODE^} Auto-start"
    echo "  7) Disable ${MODE^} Auto-start"
    echo ""
    echo "  8) View ${MODE^} Config"
    echo "  9) Edit ${MODE^} Config"
    echo "  10) Delete ${MODE^} Config"
    echo ""
    echo "  0) Back to Settings"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1) systemctl start "$SERVICE_NAME"; echo -e "${GREEN}✓ ${MODE^} started${NC}"; sleep 2; service_management "$MODE" ;;
        2) systemctl stop "$SERVICE_NAME"; echo -e "${GREEN}✓ ${MODE^} stopped${NC}"; sleep 2; service_management "$MODE" ;;
        3) systemctl restart "$SERVICE_NAME"; echo -e "${GREEN}✓ ${MODE^} restarted${NC}"; sleep 2; service_management "$MODE" ;;
        4) systemctl status "$SERVICE_NAME"; read -p "Press Enter to continue..."; service_management "$MODE" ;;
        5) journalctl -u "$SERVICE_NAME" -f ;;
        6) systemctl enable "$SERVICE_NAME"; echo -e "${GREEN}✓ Auto-start enabled${NC}"; sleep 2; service_management "$MODE" ;;
        7) systemctl disable "$SERVICE_NAME"; echo -e "${GREEN}✓ Auto-start disabled${NC}"; sleep 2; service_management "$MODE" ;;
        8)
            if [ -f "$CONFIG_FILE" ]; then
                cat "$CONFIG_FILE"
            else
                echo -e "${RED}${MODE^} config not found${NC}"
            fi
            read -p "Press Enter to continue..."
            service_management "$MODE"
            ;;
        9)
            if [ -f "$CONFIG_FILE" ]; then
                ${EDITOR:-nano} "$CONFIG_FILE"
            else
                echo -e "${RED}${MODE^} config not found${NC}"
                sleep 2
            fi
            service_management "$MODE"
            ;;
        10)
            read -p "Delete ${MODE^} config and service? [y/N]: " c
            if [[ $c =~ ^[Yy]$ ]]; then
                systemctl stop "$SERVICE_NAME" 2>/dev/null
                systemctl disable "$SERVICE_NAME" 2>/dev/null
                rm -f "$CONFIG_FILE"
                rm -f "$SYSTEMD_DIR/${SERVICE_NAME}.service"
                systemctl daemon-reload
                echo -e "${GREEN}✓ ${MODE^} configuration and service deleted${NC}"
                sleep 2
            fi
            settings_menu
            ;;
        0) settings_menu ;;
        *) service_management "$MODE" ;;
    esac
}

# ---------------------------
# Settings Menu (New Function)
# ---------------------------
settings_menu() {
    show_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}            SETTINGS MENU${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "  1) Manage Server"
    echo "  2) Manage Client"
    echo ""
    echo "  0) Back to Main Menu"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1) service_management "server" ;;
        2) service_management "client" ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; settings_menu ;;
    esac
}

# ---------------------------
# Uninstall
# ---------------------------
uninstall_DaggerConnect() {
    show_banner
    echo -e "${RED}═══════════════════════════════════════${NC}"
    echo -e "${RED}         UNINSTALL DaggerConnect${NC}"
    echo -e "${RED}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  This will remove:${NC}"
    echo "  - DaggerConnect binary"
    echo "  - All configurations (/etc/DaggerConnect)"
    echo "  - Systemd services (server/client)"
    echo ""
    read -p "Are you sure? [y/N]: " c

    if [[ ! $c =~ ^[Yy]$ ]]; then
        main_menu
        return
    fi

    echo ""
    echo -e "${YELLOW}Stopping services and removing systemd files...${NC}"
    systemctl stop DaggerConnect-server 2>/dev/null
    systemctl stop DaggerConnect-client 2>/dev/null
    systemctl disable DaggerConnect-server 2>/dev/null
    systemctl disable DaggerConnect-client 2>/dev/null

    rm -f "$SYSTEMD_DIR/DaggerConnect-server.service"
    rm -f "$SYSTEMD_DIR/DaggerConnect-client.service"

    echo -e "${YELLOW}Removing binary and configs...${NC}"
    rm -f "$INSTALL_DIR/DaggerConnect"
    rm -rf "$CONFIG_DIR"

    systemctl daemon-reload

    echo ""
    echo -e "${GREEN}✓ DaggerConnect uninstalled successfully${NC}"
    echo ""
    exit 0
}

# ---------------------------
# Main Menu
# ---------------------------
main_menu() {
    show_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}            MAIN MENU${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "  1) Install Server"
    echo "  2) Install Client"
    echo "  3) Settings (Manage Services & Configs)"
    echo "  4) Uninstall DaggerConnect"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1) install_server ;;
        2) install_client ;;
        3) settings_menu ;; # New Settings Menu
        4) uninstall_DaggerConnect ;;
        0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; main_menu ;;
    esac
}

# ---------------------------
# Execution
# ---------------------------
check_root
show_banner
install_dependencies

# Check binary
if [ ! -f "$INSTALL_DIR/DaggerConnect" ]; then
    echo -e "${YELLOW}DaggerConnect not found. Installing...${NC}"
    download_binary
    echo ""
fi

main_menu
