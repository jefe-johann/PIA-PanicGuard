#!/bin/bash

# <xbar.title>PIA Sleep Manager</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>VPN Shutdown Project</xbar.author>
# <xbar.desc>Manages PIA VPN sleep/wake automation service</xbar.desc>
# <xbar.dependencies>bash,sleepwatcher,piactl</xbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>false</swiftbar.hideRunInTerminal>

# Configuration
CONFIG_FILE="/usr/local/etc/pia-sleep.conf"
LOG_FILE="/var/log/pia-sleep.log"
PIA_CTL="/usr/local/bin/piactl"
HELPER_SCRIPT="/usr/local/bin/pia-config-helper.sh"

# Default values (used if config not found)
MANAGE_TORRENTS="true"
MANAGE_EXTERNAL_DRIVE="false"
AUTO_RECONNECT="true"
AUTO_REOPEN_APPS="true"
EXTERNAL_DRIVE_NAME="Big Dawg"
TORRENT_APPS=("Transmission" "qbittorrent" "Nicotine+" "VLC" "BiglyBT")

# Load configuration if it exists
if [ -r "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# === ACTION HANDLERS ===
# Execute when plugin called with parameters

if [ -n "$1" ]; then
    case "$1" in
        toggle)
            # Toggle a configuration setting
            setting="$2"
            if [ -z "$setting" ]; then
                echo "Error: No setting specified"
                exit 1
            fi

            # Source config to get current value
            if [ -r "$CONFIG_FILE" ]; then
                source "$CONFIG_FILE"
            fi

            # Get current value and compute new value
            current="${!setting}"
            if [ "$current" = "true" ]; then
                new_value="false"
            else
                new_value="true"
            fi

            # Use helper script with osascript for sudo
            osascript -e "do shell script \"$HELPER_SCRIPT $setting $new_value\" with administrator privileges" 2>/dev/null
            exit 0
            ;;

        disable-service)
            # Disable (unload) the LaunchDaemon
            osascript -e 'do shell script "launchctl unload /Library/LaunchDaemons/com.pia.sleephandler.plist" with administrator privileges' 2>/dev/null
            exit 0
            ;;

        enable-service)
            # Enable (load) the LaunchDaemon
            osascript -e 'do shell script "launchctl load /Library/LaunchDaemons/com.pia.sleephandler.plist" with administrator privileges' 2>/dev/null
            exit 0
            ;;

        reconnect-vpn)
            # Reconnect PIA VPN
            if [ -x "$PIA_CTL" ]; then
                "$PIA_CTL" connect &
            fi
            exit 0
            ;;

        show-logs)
            # Show recent logs in terminal
            line_count="${2:-10}"
            echo "=== PIA Sleep Manager - Last $line_count Log Entries ==="
            echo ""
            if [ -f "$LOG_FILE" ]; then
                tail -n "$line_count" "$LOG_FILE" 2>/dev/null
            else
                echo "Log file not found: $LOG_FILE"
            fi
            echo ""
            echo "Press any key to close..."
            read -n 1
            exit 0
            ;;

        restart-service)
            # Restart the service (unload and reload)
            osascript -e 'do shell script "launchctl unload /Library/LaunchDaemons/com.pia.sleephandler.plist && launchctl load /Library/LaunchDaemons/com.pia.sleephandler.plist" with administrator privileges' 2>/dev/null
            exit 0
            ;;
    esac
fi

# === STATUS DETECTION ===

# Detect if service is running
service_running=false
if [ -f "/Library/LaunchDaemons/com.pia.sleephandler.plist" ] && \
   pgrep -f "sleepwatcher.*pia-sleep.sh" > /dev/null 2>&1; then
    service_running=true
fi

# Detect VPN state
vpn_state="Unknown"
vpn_connected=false
if [ -x "$PIA_CTL" ]; then
    vpn_state=$("$PIA_CTL" get connectionstate 2>/dev/null || echo "Error")
    if [ "$vpn_state" = "Connected" ]; then
        vpn_connected=true
    fi
fi

# Detect external drive status
drive_status="Unknown"
if [ "$MANAGE_EXTERNAL_DRIVE" = "true" ]; then
    drive_info=$(diskutil info "$EXTERNAL_DRIVE_NAME" 2>&1)
    if [[ $drive_info == *"could not find disk"* ]]; then
        drive_status="Not Connected"
    elif echo "$drive_info" | grep -q "Mounted:[[:space:]]*Yes"; then
        drive_status="Mounted"
    else
        drive_status="Connected, Not Mounted"
    fi
else
    drive_status="Management Disabled"
fi

# Detect torrent application status
running_count=0
total_count=${#TORRENT_APPS[@]}
if [ "$MANAGE_TORRENTS" = "true" ]; then
    for app in "${TORRENT_APPS[@]}"; do
        if pgrep -f "$app" > /dev/null 2>&1; then
            ((running_count++))
        fi
    done
fi

# === MENU RENDERING ===

# Header (what appears in menubar)
# Use SF Symbol: eye when service running, eye.slash when disabled
if $service_running; then
    echo "| sfimage=eye"
else
    echo "| sfimage=eye.slash"
fi
echo "---"

# === STATUS SECTION ===
echo "📊 Status"

# Service status
if $service_running; then
    echo "--Sleepwatcher: ✓ Running | color=green"
else
    echo "--Sleepwatcher: ✗ Stopped | color=red"
fi

# VPN status
if [ "$vpn_state" = "Connected" ]; then
    echo "--PIA VPN: Connected | color=green"
elif [ "$vpn_state" = "Disconnected" ]; then
    echo "--PIA VPN: Disconnected | color=yellow"
elif [ "$vpn_state" = "Error" ]; then
    echo "--PIA VPN: Daemon Not Responding | color=red"
else
    echo "--PIA VPN: $vpn_state | color=gray"
fi

# External drive status (if management enabled)
if [ "$MANAGE_EXTERNAL_DRIVE" = "true" ]; then
    if [ "$drive_status" = "Mounted" ]; then
        echo "--External Drive: ✓ $drive_status | color=green"
    elif [ "$drive_status" = "Not Connected" ]; then
        echo "--External Drive: $drive_status | color=gray"
    else
        echo "--External Drive: $drive_status | color=yellow"
    fi
fi

# Torrent apps status (if management enabled)
if [ "$MANAGE_TORRENTS" = "true" ]; then
    if [ $running_count -gt 0 ]; then
        echo "--Torrent Apps: $running_count of $total_count running | color=green"
    else
        echo "--Torrent Apps: None running | color=gray"
    fi
fi

echo "---"

# === QUICK ACTIONS SECTION ===
echo "⚡ Quick Actions"

# Service control
if $service_running; then
    echo "--Disable Service | bash='$0' param1=disable-service terminal=false refresh=true"
else
    echo "--Enable Service | bash='$0' param1=enable-service terminal=false refresh=true"
fi

# VPN reconnect
if [ -x "$PIA_CTL" ]; then
    echo "--Reconnect VPN Now | bash='$0' param1=reconnect-vpn terminal=false refresh=true"
fi

# Manual refresh
echo "--Refresh Status | refresh=true"

echo "---"

# === FEATURE TOGGLES SECTION ===
echo "⚙️ Feature Toggles"

# Render toggle helper function
render_toggle() {
    local setting="$1"
    local display_name="$2"
    local current="${!setting}"

    if [ "$current" = "true" ]; then
        echo "--✓ $display_name | bash='$0' param1=toggle param2=$setting terminal=false refresh=true color=green"
    else
        echo "--  $display_name | bash='$0' param1=toggle param2=$setting terminal=false refresh=true color=gray"
    fi
}

# Render each toggle
render_toggle "MANAGE_TORRENTS" "Auto Close Torrents"
render_toggle "MANAGE_EXTERNAL_DRIVE" "Manage External Drive"
render_toggle "AUTO_RECONNECT" "Auto Reconnect VPN"
render_toggle "AUTO_REOPEN_APPS" "Auto Reopen Torrents"

echo "---"

# === LOGS SECTION ===
echo "📄 View Logs"
echo "--Last 10 Lines | bash='$0' param1=show-logs param2=10 terminal=true"
echo "--Last 20 Lines | bash='$0' param1=show-logs param2=20 terminal=true"
echo "--Last 50 Lines | bash='$0' param1=show-logs param2=50 terminal=true"
if [ -f "$LOG_FILE" ]; then
    echo "--Open Full Log | bash='open' param1='$LOG_FILE' terminal=false"
fi

echo "---"

# === ADVANCED SECTION ===
echo "🔧 Advanced"
echo "--Edit Configuration | bash='open' param1='-t' param2='$CONFIG_FILE' terminal=false"
echo "--Restart Service | bash='$0' param1=restart-service terminal=false refresh=true"
echo "-----"
echo "--Run Status Script | bash='/Users/jeff/Jeff/Random_Projects/Sleepy_Time/VPN_Shutdown/status.sh' terminal=true"
