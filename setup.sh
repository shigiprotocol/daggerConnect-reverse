#!/bin/bash
# ============================================================================
#  DaggerBridge Quick Installer
#  GitHub: github.com/shigiprotocol/daggerConnect-reverse
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
REPO_OWNER="shigiprotocol"
REPO_NAME="daggerConnect-reverse"
RELEASE_TAG="reversetunnel"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="DaggerConnect"
SCRIPT_NAME="daggerbridge.sh"

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════╗"
echo "║     DaggerBridge Installer v1.0                    ║"
echo "║     github.com/shigiprotocol/daggerConnect-reverse ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo -e "   Usage: sudo bash setup.sh"
    exit 1
fi

# Install dependencies
echo -e "${YELLOW}📦 Checking dependencies...${NC}"
if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}   Installing curl...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update -qq && apt-get install -y curl -qq
    elif command -v yum &> /dev/null; then
        yum install -y curl -q
    elif command -v dnf &> /dev/null; then
        dnf install -y curl -q
    else
        echo -e "${RED}❌ curl not found. Please install it manually.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Dependencies ready${NC}"

# Download binary from release
echo ""
echo -e "${CYAN}📥 Downloading DaggerConnect binary...${NC}"
BINARY_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${RELEASE_TAG}/${BINARY_NAME}"

echo -e "   ${CYAN}Source: ${BINARY_URL}${NC}"
echo ""

if curl -fL --progress-bar -o "/tmp/${BINARY_NAME}" "${BINARY_URL}"; then
    # Check if file is valid
    FILE_SIZE=$(stat -c%s "/tmp/${BINARY_NAME}" 2>/dev/null || stat -f%z "/tmp/${BINARY_NAME}" 2>/dev/null)
    
    if [ "$FILE_SIZE" -lt 1000000 ]; then
        echo -e "${RED}❌ Downloaded file is too small (${FILE_SIZE} bytes)${NC}"
        echo -e "${YELLOW}   Expected: ~11 MB${NC}"
        rm -f "/tmp/${BINARY_NAME}"
        exit 1
    fi
    
    # Install binary
    mkdir -p "${INSTALL_DIR}"
    mv "/tmp/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
    
    SIZE_MB=$(echo "scale=1; $FILE_SIZE / 1024 / 1024" | bc 2>/dev/null || echo "$(($FILE_SIZE / 1024 / 1024))")
    echo -e "${GREEN}✓ Binary installed successfully (${SIZE_MB} MB)${NC}"
else
    echo -e "${RED}❌ Failed to download binary${NC}"
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting:${NC}"
    echo -e "   1. Check internet connection"
    echo -e "   2. Verify release exists: ${BINARY_URL}"
    echo -e "   3. Try manual download:"
    echo -e "      wget ${BINARY_URL}"
    echo -e "      sudo mv ${BINARY_NAME} ${INSTALL_DIR}/"
    echo -e "      sudo chmod +x ${INSTALL_DIR}/${BINARY_NAME}"
    exit 1
fi

# Download management script
echo ""
echo -e "${CYAN}📥 Downloading management script...${NC}"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/${SCRIPT_NAME}"

if curl -fL --progress-bar -o "${INSTALL_DIR}/${SCRIPT_NAME}" "${SCRIPT_URL}"; then
    chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"
    echo -e "${GREEN}✓ Management script installed${NC}"
else
    echo -e "${YELLOW}⚠ Management script download failed (non-critical)${NC}"
    echo -e "   Binary is installed and can be used directly"
fi

# Test binary
echo ""
echo -e "${CYAN}🧪 Testing binary...${NC}"
if "${INSTALL_DIR}/${BINARY_NAME}" -v &>/dev/null; then
    VERSION=$("${INSTALL_DIR}/${BINARY_NAME}" -v 2>&1 | head -1 || echo "")
    echo -e "${GREEN}✓ Binary works correctly${NC}"
    [ -n "$VERSION" ] && echo -e "   ${CYAN}Version: ${VERSION}${NC}"
elif "${INSTALL_DIR}/${BINARY_NAME}" --version &>/dev/null; then
    VERSION=$("${INSTALL_DIR}/${BINARY_NAME}" --version 2>&1 | head -1 || echo "")
    echo -e "${GREEN}✓ Binary works correctly${NC}"
    [ -n "$VERSION" ] && echo -e "   ${CYAN}Version: ${VERSION}${NC}"
elif "${INSTALL_DIR}/${BINARY_NAME}" -h &>/dev/null; then
    echo -e "${GREEN}✓ Binary installed (help command responds)${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify binary version${NC}"
    echo -e "   This is normal - binary should still work"
fi

# Success
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Installation completed successfully!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📍 Installed files:${NC}"
echo -e "   ${INSTALL_DIR}/${BINARY_NAME}"
[ -f "${INSTALL_DIR}/${SCRIPT_NAME}" ] && echo -e "   ${INSTALL_DIR}/${SCRIPT_NAME}"
echo ""
echo -e "${CYAN}🚀 Quick start:${NC}"
if [ -f "${INSTALL_DIR}/${SCRIPT_NAME}" ]; then
    echo -e "   ${YELLOW}sudo daggerbridge.sh${NC}     (recommended - management interface)"
    echo ""
    echo -e "${CYAN}Or use binary directly:${NC}"
    echo -e "   ${YELLOW}DaggerConnect -h${NC}          (show help)"
else
    echo -e "   ${YELLOW}DaggerConnect -h${NC}          (show help)"
fi
echo ""
echo -e "${CYAN}📚 Documentation:${NC}"
echo -e "   https://github.com/${REPO_OWNER}/${REPO_NAME}"
echo ""
