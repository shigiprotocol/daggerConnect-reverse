#!/bin/bash
# Quick installer for DaggerConnect
# Usage: curl -fsSL https://raw.githubusercontent.com/shigiprotocol/daggerConnect-reverse/main/install.sh | sudo bash

set -e

REPO="shigiprotocol/daggerConnect-reverse"
RELEASE="reversetunnel"
INSTALL_DIR="/usr/local/bin"

echo "╔════════════════════════════════════════╗"
echo "║  DaggerConnect Quick Installer         ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check root
if [ $EUID -ne 0 ]; then
    echo "❌ Run as root: sudo bash install.sh"
    exit 1
fi

# Install curl if needed
if ! command -v curl >/dev/null; then
    echo "📦 Installing curl..."
    apt-get update -qq && apt-get install -y curl -qq 2>/dev/null || yum install -y curl -q 2>/dev/null
fi

# Download binary
echo "📥 Downloading DaggerConnect (11MB)..."
BINARY_URL="https://github.com/${REPO}/releases/download/${RELEASE}/DaggerConnect"

if ! curl -fL --progress-bar -o /tmp/DaggerConnect "${BINARY_URL}"; then
    echo "❌ Download failed"
    echo "   URL: ${BINARY_URL}"
    exit 1
fi

# Verify size
SIZE=$(stat -c%s /tmp/DaggerConnect 2>/dev/null || stat -f%z /tmp/DaggerConnect)
if [ "$SIZE" -lt 1000000 ]; then
    echo "❌ Invalid file size: $SIZE bytes (expected ~11MB)"
    rm -f /tmp/DaggerConnect
    exit 1
fi

# Install binary
mkdir -p ${INSTALL_DIR}
mv /tmp/DaggerConnect ${INSTALL_DIR}/DaggerConnect
chmod +x ${INSTALL_DIR}/DaggerConnect
echo "✓ Binary installed ($(($SIZE / 1024 / 1024))MB)"

# Download management script
echo ""
echo "📥 Downloading management script..."
if curl -fL -o ${INSTALL_DIR}/daggerbridge.sh "https://raw.githubusercontent.com/${REPO}/main/daggerbridge.sh" 2>/dev/null; then
    chmod +x ${INSTALL_DIR}/daggerbridge.sh
    echo "✓ Script installed"
else
    echo "⚠ Script download failed (non-critical)"
fi

# Test
echo ""
echo "🧪 Testing binary..."
if ${INSTALL_DIR}/DaggerConnect -v &>/dev/null || ${INSTALL_DIR}/DaggerConnect --version &>/dev/null; then
    echo "✓ Binary works!"
else
    echo "⚠ Could not test (may still work)"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✓ Installation complete!              ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Run: sudo daggerbridge.sh"
echo "Or:  DaggerConnect -h"
echo ""
