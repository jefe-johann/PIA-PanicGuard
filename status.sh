#!/bin/bash

# Enhanced PIA VPN Sleep Handler Status Check
# Shows comprehensive status of the enhanced PIA sleep handler service

# Configuration
CONFIG_FILE="/usr/local/etc/pia-sleep.conf"

# Default values
MANAGE_TORRENTS="true"
MANAGE_EXTERNAL_DRIVE="true"
EXTERNAL_DRIVE_NAME="Big Dawg"
TORRENT_APPS=("Transmission" "qbittorrent" "Nicotine+" "VLC" "BiglyBT")
AUTO_REOPEN_APPS="false"

# Load configuration if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Enhanced PIA VPN Sleep Handler Status ===${NC}"
echo

# Check configuration file status
echo -e "${BLUE}Configuration:${NC}"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "  ${GREEN}✓${NC} Configuration file exists: $CONFIG_FILE"
    echo -e "    Manage Torrents: $MANAGE_TORRENTS"
    echo -e "    Manage External Drive: $MANAGE_EXTERNAL_DRIVE"
    echo -e "    External Drive Name: $EXTERNAL_DRIVE_NAME"
    echo -e "    Auto Reopen Apps: $AUTO_REOPEN_APPS"
else
    echo -e "  ${YELLOW}⚠${NC} Configuration file missing, using defaults"
fi

# Check LaunchDaemon status
echo -e "\n${BLUE}LaunchDaemon Status:${NC}"
if sudo launchctl list | grep -q "com.pia.sleephandler"; then
    daemon_status=$(sudo launchctl list | grep "com.pia.sleephandler")
    echo -e "  ${GREEN}✓ Loaded:${NC} $daemon_status"
else
    echo -e "  ${RED}✗ Not loaded${NC}"
fi

# Check if sleepwatcher process is running
echo -e "\n${BLUE}Process Status:${NC}"
sleepwatcher_proc=$(pgrep -fl sleepwatcher 2>/dev/null)
if [ -n "$sleepwatcher_proc" ]; then
    echo -e "  ${GREEN}✓ Running:${NC} $sleepwatcher_proc"
else
    echo -e "  ${RED}✗ Not running${NC}"
fi

# Check required files
echo -e "\n${BLUE}Required Files:${NC}"
files=(
    "/usr/local/etc/pia-sleep.conf"
    "/usr/local/bin/pia-sleep.sh"
    "/usr/local/bin/pia-wake.sh"
    "/Library/LaunchDaemons/com.pia.sleephandler.plist"
)

all_files_present=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file (missing)"
        all_files_present=false
    fi
done

# Check torrent application status
if [ "$MANAGE_TORRENTS" = "true" ]; then
    echo -e "\n${BLUE}Torrent Applications:${NC}"
    
    running_count=0
    total_count=${#TORRENT_APPS[@]}
    
    for app in "${TORRENT_APPS[@]}"; do
        if pgrep -f "$app" > /dev/null; then
            echo -e "  ${GREEN}✓${NC} $app is running"
            ((running_count++))
        else
            echo -e "  ${YELLOW}ℹ${NC} $app is not running"
        fi
    done
    
    echo -e "  ${BLUE}→${NC} $running_count of $total_count configured apps are running"
    
    # Check state file
    if [ -f "/tmp/torrents-were-running" ]; then
        saved_apps=$(wc -l < "/tmp/torrents-were-running")
        echo -e "  ${YELLOW}ℹ${NC} State file exists: $saved_apps apps were running before last sleep"
    fi
else
    echo -e "\n${BLUE}Torrent Applications:${NC}"
    echo -e "  ${YELLOW}ℹ${NC} Torrent management disabled in configuration"
fi

# Check external drive status
if [ "$MANAGE_EXTERNAL_DRIVE" = "true" ]; then
    echo -e "\n${BLUE}External Drive ($EXTERNAL_DRIVE_NAME):${NC}"
    
    drive_info=$(diskutil info "$EXTERNAL_DRIVE_NAME" 2>&1)
    if [[ $drive_info == *"could not find disk"* ]]; then
        echo -e "  ${YELLOW}⚠${NC} '$EXTERNAL_DRIVE_NAME' is not currently connected"
    elif echo "$drive_info" | grep -q "Mounted:[[:space:]]*Yes"; then
        echo -e "  ${GREEN}✓${NC} '$EXTERNAL_DRIVE_NAME' is mounted and accessible"
    else
        echo -e "  ${YELLOW}⚠${NC} '$EXTERNAL_DRIVE_NAME' is connected but not mounted"
    fi
    
    # Check state file
    if [ -f "/tmp/drive-was-mounted" ]; then
        echo -e "  ${YELLOW}ℹ${NC} State file exists: Drive was mounted before last sleep"
    fi
else
    echo -e "\n${BLUE}External Drive Management:${NC}"
    echo -e "  ${YELLOW}ℹ${NC} External drive management disabled in configuration"
fi

# Check PIA availability
echo -e "\n${BLUE}PIA Status:${NC}"
if [ -x "/usr/local/bin/piactl" ]; then
    pia_state=$(piactl get connectionstate 2>/dev/null || echo "Error")
    if [ "$pia_state" = "Error" ]; then
        echo -e "  ${YELLOW}⚠${NC} piactl available but PIA daemon not responding"
    else
        echo -e "  ${GREEN}✓${NC} piactl working, current state: $pia_state"
    fi
else
    echo -e "  ${RED}✗${NC} piactl not found"
fi

# Check recent activity
echo -e "\n${BLUE}Recent Activity:${NC}"
if [ -f "/var/log/pia-sleep.log" ]; then
    recent_lines=$(tail -5 /var/log/pia-sleep.log 2>/dev/null)
    if [ -n "$recent_lines" ]; then
        echo "$recent_lines" | sed 's/^/  /'
    else
        echo -e "  ${YELLOW}ℹ${NC} No recent activity logged"
    fi
else
    echo -e "  ${YELLOW}ℹ${NC} Log file not yet created"
fi

# Overall status
echo -e "\n${BLUE}Overall Status:${NC}"
if sudo launchctl list | grep -q "com.pia.sleephandler" && [ -n "$(pgrep -f sleepwatcher)" ] && [ "$all_files_present" = true ]; then
    echo -e "  ${GREEN}✓ Enhanced service is running and configured correctly${NC}"
    echo -e "  ${GREEN}→ Features: Torrents=$MANAGE_TORRENTS, Drive=$MANAGE_EXTERNAL_DRIVE${NC}"
else
    echo -e "  ${RED}✗ Service has issues - see details above${NC}"
    echo -e "  ${YELLOW}→ Try: sudo ./install.sh (to reinstall) or check troubleshooting in README${NC}"
fi

echo