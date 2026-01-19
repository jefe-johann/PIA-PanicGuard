#!/bin/bash

# PIA VPN Sleep Handler Update Script
# Copies updated scripts to system location and restarts the service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Status tracking
SWIFTBAR_COPIED=false

echo -e "${BLUE}=== PIA VPN Sleep Handler Update ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR:${NC} This script must be run as root (use sudo)"
    exit 1
fi

# Step 1: Copy updated scripts
echo -e "${BLUE}Step 1: Copying updated scripts to system location...${NC}"

if [ -f "$SCRIPT_DIR/pia-sleep.sh" ]; then
    cp "$SCRIPT_DIR/pia-sleep.sh" /usr/local/bin/
    chmod 755 /usr/local/bin/pia-sleep.sh
    chown root:wheel /usr/local/bin/pia-sleep.sh
    echo -e "  ${GREEN}✓${NC} pia-sleep.sh updated"
else
    echo -e "  ${RED}✗${NC} pia-sleep.sh not found in project directory"
    exit 1
fi

if [ -f "$SCRIPT_DIR/pia-wake.sh" ]; then
    cp "$SCRIPT_DIR/pia-wake.sh" /usr/local/bin/
    chmod 755 /usr/local/bin/pia-wake.sh
    chown root:wheel /usr/local/bin/pia-wake.sh
    echo -e "  ${GREEN}✓${NC} pia-wake.sh updated"
else
    echo -e "  ${RED}✗${NC} pia-wake.sh not found in project directory"
    exit 1
fi

# Update helper script if it exists (optional component for SwiftBar)
if [ -f "$SCRIPT_DIR/pia-config-helper.sh" ]; then
    cp "$SCRIPT_DIR/pia-config-helper.sh" /usr/local/bin/
    chmod 755 /usr/local/bin/pia-config-helper.sh
    chown root:wheel /usr/local/bin/pia-config-helper.sh
    echo -e "  ${GREEN}✓${NC} pia-config-helper.sh updated"
fi

# Update SwiftBar plugin if it exists (optional)
if [ -n "$SUDO_USER" ]; then
    SWIFTBAR_PLUGINS="/Users/$SUDO_USER/Library/Application Support/SwiftBar/plugins"
    if [ -d "$SWIFTBAR_PLUGINS" ] && [ -f "$SCRIPT_DIR/swiftbar/pia-sleep-manager.1m.sh" ]; then
        cp "$SCRIPT_DIR/swiftbar/pia-sleep-manager.1m.sh" "$SWIFTBAR_PLUGINS/"
        chmod +x "$SWIFTBAR_PLUGINS/pia-sleep-manager.1m.sh"
        chown "$SUDO_USER" "$SWIFTBAR_PLUGINS/pia-sleep-manager.1m.sh"
        echo -e "  ${GREEN}✓${NC} SwiftBar plugin updated"
        SWIFTBAR_COPIED=true
    fi
fi

# Step 2: Restart the service
echo -e "\n${BLUE}Step 2: Restarting the service...${NC}"

if launchctl list | grep -q "com.pia.sleephandler"; then
    launchctl unload /Library/LaunchDaemons/com.pia.sleephandler.plist
    echo -e "  ${GREEN}✓${NC} Service unloaded"
else
    echo -e "  ${YELLOW}ℹ${NC} Service was not running"
fi

launchctl load /Library/LaunchDaemons/com.pia.sleephandler.plist
echo -e "  ${GREEN}✓${NC} Service loaded"

# Step 3: Verify installation
echo -e "\n${BLUE}Step 3: Verifying update...${NC}"

# Check if sleepwatcher is running
if pgrep -f "sleepwatcher.*pia-sleep.sh" >/dev/null; then
    echo -e "  ${GREEN}✓${NC} Sleepwatcher is running with updated PIA scripts"
else
    echo -e "  ${YELLOW}⚠${NC} Sleepwatcher process not detected (check logs if needed)"
fi

# Verify SwiftBar plugin copy
if [ "$SWIFTBAR_COPIED" = true ]; then
    SWIFTBAR_PLUGINS="/Users/$SUDO_USER/Library/Application Support/SwiftBar/plugins"
    if [ -f "$SWIFTBAR_PLUGINS/pia-sleep-manager.1m.sh" ]; then
        echo -e "  ${GREEN}✓${NC} SwiftBar plugin verified at destination"
    else
        echo -e "  ${RED}✗${NC} SwiftBar plugin copy verification failed"
    fi
fi

# Show status
echo -e "\n${BLUE}Current Status:${NC}"
if [ -x "$SCRIPT_DIR/status.sh" ]; then
    "$SCRIPT_DIR/status.sh"
else
    echo -e "${YELLOW}status.sh not found - run manually to check system status${NC}"
fi

echo -e "\n${GREEN}Update completed successfully!${NC}"
echo -e "${BLUE}Updated scripts are now active and will be used for sleep/wake events.${NC}"