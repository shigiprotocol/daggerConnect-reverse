#!/bin/bash

# DaggerConnect Installer v2.2 (Corrected Profiles)

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
    echo -e "${GREEN}        DaggerConnect Installer v2.2 - Corrected Edition${NC}"
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

        if "$INSTALL_DIR/DaggerConnect" -v &>/dev/null; then
            VERSION=$("$INSTALL_DIR/DaggerConnect" -v 2>&1 | grep -oP 'v\d+\.\d+\.\d+' || echo "v1.1.3")
            echo -e "${CYAN}ℹ️  Version: $VERSION${NC}"
        fi
    else
        echo -e "${RED}✖ Failed to download DaggerConnect binary${NC}"
        echo -e "${YELLOW}Please check your internet connection and try again${NC}"
        exit 1
    fi
}

# Create systemd service
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
LimitNOFILE=1048576

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
    echo "  1) tcpmux  - TCP Multiplexing"
    echo "  2) kcpmux  - KCP Multiplexing (UDP based)"
    echo "  3) wsmux   - WebSocket"
    echo "  4) wssmux  - WebSocket Secure (TLS)"
    echo ""
    read -p "Choice [1-4]: " transport_choice
    case $transport_choice in
        1) TRANSPORT="tcpmux" ;;
        2) TRANSPORT="kcpmux" ;;
        3) TRANSPORT="wsmux" ;;
        4) TRANSPORT="wssmux" ;;
        *) TRANSPORT="tcpmux" ;;
    esac

    # Listen port (Tunnel Port)
    echo ""
    echo -e "${CYAN}Tunnel Port: Port for communication between Server and Client${NC}"
    read -p "Tunnel Port [2020]: " LISTEN_PORT
    LISTEN_PORT=${LISTEN_PORT:-2020}

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

    # Profile (Corrected profiles)
    echo ""
    echo -e "${YELLOW}Select Performance Profile:${NC}"
    echo "  1) balanced      - Standard balanced performance"
    echo "  2) aggressive    - High speed, aggressive settings"
    echo "  3) latency       - Optimized for low latency"
    echo "  4) cpu-efficient - Low CPU usage"
    echo ""
    read -p "Choice [1-5]: " profile_choice
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
        echo -e "${YELLOW}TLS Configuration (Required for wssmux):${NC}"
        read -p "Certificate file path: " CERT_FILE
        read -p "Private key file path: " KEY_FILE
        if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
            echo -e "${YELLOW}⚠️  Certificate files not found. You can add them later.${NC}"
            CERT_FILE=""
            KEY_FILE=""
        fi
    fi

    # Port mappings
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
        echo "Protocol:"
        echo "  1) tcp"
        echo "  2) udp"
        echo "  3) both (tcp + udp)"
        read -p "Choice [1-3]: " proto_choice

        while true; do
            read -p "Port Script (required): " BIND_PORT
            if [[ -n "$BIND_PORT" ]] && [[ "$BIND_PORT" =~ ^[0-9]+$ ]] && [ "$BIND_PORT" -ge 1 ] && [ "$BIND_PORT" -le 65535 ]; then
                break
            else
                echo -e "${RED}⚠ Invalid port! Enter a number between 1-65535${NC}"
            fi
        done

        # Build mappings
        BIND="0.0.0.0:${BIND_PORT}"
        TARGET="0.0.0.0:${BIND_PORT}"

        case $proto_choice in
            1)
                MAPPINGS="${MAPPINGS}  - type: tcp\n    bind: \"${BIND}\"\n    target: \"${TARGET}\"\n"
                ;;
            2)
                MAPPINGS="${MAPPINGS}  - type: udp\n    bind: \"${BIND}\"\n    target: \"${TARGET}\"\n"
                ;;
            3)
                MAPPINGS="${MAPPINGS}  - type: tcp\n    bind: \"${BIND}\"\n    target: \"${TARGET}\"\n"
                MAPPINGS="${MAPPINGS}  - type: udp\n    bind: \"${BIND}\"\n    target: \"${TARGET}\"\n"
                ;;
            *)
                echo -e "${RED}Invalid choice, skipping...${NC}"
                continue
                ;;
        esac

        COUNT=$((COUNT+1))
        read -p "Add another port mapping? (y/n) [n]: " add_more
        [[ "$add_more" =~ ^[Yy] ]] || break
    done

    # Verbose
    echo ""
    read -p "Enable verbose logging? [y/N]: " VERBOSE
    [[ $VERBOSE =~ ^[Yy]$ ]] && VERBOSE="true" || VERBOSE="false"

    # Write config (Profile values will be applied by the Go application)
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

    # Add default settings (will be overridden by profile in Go code)
    cat >> "$CONFIG_FILE" << 'EOF'
smux:
  keepalive: 8
  max_recv: 8388608
  max_stream: 8388608
  frame_size: 32768
  version: 2

kcp:
  nodelay: 1
  interval: 10
  resend: 2
  nc: 1
  sndwnd: 1024
  rcvwnd: 1024
  mtu: 1400

advanced:
  tcp_nodelay: true
  tcp_keepalive: 15
  tcp_read_buffer: 8388608
  tcp_write_buffer: 8388608
  websocket_read_buffer: 262144
  websocket_write_buffer: 262144
  websocket_compression: false
  cleanup_interval: 3
  session_timeout: 30
  connection_timeout: 60
  stream_timeout: 120
  max_connections: 2000
  max_udp_flows: 1000
  udp_flow_timeout: 300
  udp_buffer_size: 4194304

heartbeat: 10
EOF

    create_systemd_service "server"

    systemctl start DaggerConnect-server
    systemctl enable DaggerConnect-server

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✓ Server installation complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Important Info:${NC}"
    echo "  Tunnel Port: ${GREEN}${LISTEN_PORT}${NC}"
    echo "  PSK: ${GREEN}${PSK}${NC}"
    echo "  Transport: ${GREEN}${TRANSPORT}${NC}"
    echo "  Profile: ${GREEN}${PROFILE}${NC}"
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

    # Profile (Corrected profiles)
    echo ""
    echo -e "${YELLOW}Select Performance Profile:${NC}"
    echo "  1) balanced      - Standard balanced performance"
    echo "  2) aggressive    - High speed, aggressive settings"
    echo "  3) latency       - Optimized for low latency"
    echo "  4) cpu-efficient - Low CPU usage"
    echo ""
    read -p "Choice [1-5]: " profile_choice
    case $profile_choice in
        1) PROFILE="balanced" ;;
        2) PROFILE="aggressive" ;;
        3) PROFILE="latency" ;;
        4) PROFILE="cpu-efficient" ;;
        *) PROFILE="balanced" ;;
    esac

   echo ""
   echo -e "${CYAN}═══════════════════════════════════════${NC}"
   echo -e "${CYAN}      CONNECTION PATHS${NC}"
   echo -e "${CYAN}═══════════════════════════════════════${NC}"
   
   # تغییر: از آرایه استفاده کنید
   declare -a PATH_ENTRIES=()
   COUNT=0
   
   while true; do
       echo ""
       echo -e "${YELLOW}Add Connection Path #$((COUNT+1))${NC}"
   
       echo "Select Transport Type:"
       echo "  1) tcpmux  - TCP Multiplexing"
       echo "  2) kcpmux  - KCP Multiplexing (UDP based)"
       echo "  3) wsmux   - WebSocket"
       echo "  4) wssmux  - WebSocket Secure (TLS)"
       echo ""
       read -p "Choice [1-4]: " transport_choice
       case $transport_choice in
           1) T="tcpmux" ;;
           2) T="kcpmux" ;;
           3) T="wsmux" ;;
           4) T="wssmux" ;;
           *) T="tcpmux" ;;
       esac
   
       read -p "Server address with Tunnel Port (e.g., 1.2.3.4:2020): " ADDR
       if [ -z "$ADDR" ]; then
           echo -e "${RED}Address cannot be empty!${NC}"
           continue
       fi
   
       read -p "Connection pool size [2]: " POOL
       POOL=${POOL:-2}
   
       read -p "Enable aggressive pool? [y/N]: " AGG
       [[ $AGG =~ ^[Yy]$ ]] && AGG_POOL="true" || AGG_POOL="false"
   
       # ذخیره در آرایه
       PATH_ENTRIES+=("  - transport: \"$T\"
       addr: \"$ADDR\"
       connection_pool: $POOL
       aggressive_pool: $AGG_POOL
       retry_interval: 3
       dial_timeout: 10")
   
       COUNT=$((COUNT+1))
       echo -e "${GREEN}✓ Path added: $T -> $ADDR (pool: $POOL, aggressive: $AGG_POOL)${NC}"
   
       read -p "Add another path? [y/N]: " MORE
       [[ ! $MORE =~ ^[Yy]$ ]] && break
   done
   
   # Verbose
   echo ""
   read -p "Enable verbose logging? [y/N]: " VERBOSE
   [[ $VERBOSE =~ ^[Yy]$ ]] && VERBOSE="true" || VERBOSE="false"
   
   CONFIG_FILE="$CONFIG_DIR/client.yaml"
   cat > "$CONFIG_FILE" << EOF
   mode: "client"
   psk: "${PSK}"
   profile: "${PROFILE}"
   verbose: ${VERBOSE}
   
   paths:
   EOF
   
   for path_entry in "${PATH_ENTRIES[@]}"; do
       printf "%s\n" "$path_entry" >> "$CONFIG_FILE"
   done
   
   cat >> "$CONFIG_FILE" << 'EOF'
   
   smux:
     keepalive: 8
     max_recv: 8388608
     max_stream: 8388608
     frame_size: 32768
     version: 2
   
   kcp:
     nodelay: 1
     interval: 10
     resend: 2
     nc: 1
     sndwnd: 1024
     rcvwnd: 1024
     mtu: 1400
   
   advanced:
     tcp_nodelay: true
     tcp_keepalive: 15
     tcp_read_buffer: 8388608
     tcp_write_buffer: 8388608
     websocket_read_buffer: 262144
     websocket_write_buffer: 262144
     websocket_compression: false
     cleanup_interval: 3
     session_timeout: 30
     connection_timeout: 60
     stream_timeout: 120
     max_connections: 2000
     max_udp_flows: 1000
     udp_flow_timeout: 300
     udp_buffer_size: 4194304
   
   heartbeat: 10
EOF

    create_systemd_service "client"

    systemctl start DaggerConnect-client
    systemctl enable DaggerConnect-client

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✓ Client installation complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo "  View logs: journalctl -u DaggerConnect-client -f"
    echo ""
    read -p "Press Enter to return to menu..."
    main_menu
}

# ---------------------------
# Service Management
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
    echo "  5) View ${MODE^} Logs (Live)"
    echo "  6) Enable ${MODE^} Auto-start"
    echo "  7) Disable ${MODE^} Auto-start"
    echo ""
    echo "  8) View ${MODE^} Config"
    echo "  9) Edit ${MODE^} Config"
    echo "  10) Delete ${MODE^} Config & Service"
    echo ""
    echo "  0) Back to Settings"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1) systemctl start "$SERVICE_NAME"; echo -e "${GREEN}✓ ${MODE^} started${NC}"; sleep 2; service_management "$MODE" ;;
        2) systemctl stop "$SERVICE_NAME"; echo -e "${GREEN}✓ ${MODE^} stopped${NC}"; sleep 2; service_management "$MODE" ;;
        3) systemctl restart "$SERVICE_NAME"; echo -e "${GREEN}✓ ${MODE^} restarted${NC}"; sleep 2; service_management "$MODE" ;;
        4) systemctl status "$SERVICE_NAME" --no-pager; read -p "Press Enter to continue..."; service_management "$MODE" ;;
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
                echo ""
                read -p "Restart service to apply changes? [y/N]: " restart
                if [[ $restart =~ ^[Yy]$ ]]; then
                    systemctl restart "$SERVICE_NAME"
                    echo -e "${GREEN}✓ Service restarted${NC}"
                    sleep 2
                fi
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
# Settings Menu
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
        3) settings_menu ;;
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
