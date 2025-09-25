#!/bin/bash

# PIA VPN Sleep Handler Status Check
# Shows comprehensive status of the PIA sleep handler service

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PIA VPN Sleep Handler Status ===${NC}"
echo

# Check LaunchDaemon status
echo -e "${BLUE}LaunchDaemon Status:${NC}"
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

# Check auto-reconnect setting
echo -e "\n${BLUE}Configuration:${NC}"
if [ -f "/usr/local/bin/pia-wake.sh" ]; then
    auto_reconnect=$(grep '^AUTO_RECONNECT=' /usr/local/bin/pia-wake.sh | cut -d'"' -f2)
    if [ "$auto_reconnect" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} Auto-reconnect: enabled"
    else
        echo -e "  ${YELLOW}ℹ${NC} Auto-reconnect: disabled"
    fi
else
    echo -e "  ${RED}✗${NC} Wake script not found"
fi

# Check recent activity
echo -e "\n${BLUE}Recent Activity:${NC}"
if [ -f "/var/log/pia-sleep.log" ]; then
    recent_lines=$(tail -3 /var/log/pia-sleep.log 2>/dev/null)
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
    echo -e "  ${GREEN}✓ Service is running and configured correctly${NC}"
else
    echo -e "  ${RED}✗ Service has issues - see details above${NC}"
    echo -e "  ${YELLOW}→ Try: sudo ./install.sh (to reinstall) or check troubleshooting in README${NC}"
fi

echo