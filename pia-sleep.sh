#!/bin/bash

# PIA VPN Sleep Handler
# Gracefully handles torrent clients, external drives, and PIA VPN before system sleep

LOG_FILE="/var/log/pia-sleep.log"
STATE_FILE="/tmp/pia-was-connected"
PIA_RUNNING_STATE_FILE="/tmp/pia-was-running"
TORRENT_STATE_FILE="/tmp/torrents-were-running"
DRIVE_STATE_FILE="/tmp/drive-was-mounted"
LOCK_FILE="/tmp/pia-sleep-in-progress"
CONFIG_FILE="/usr/local/etc/pia-sleep.conf"
TIMEOUT=10
PIA_CTL="/usr/local/bin/piactl"

# Load shared defaults (includes config file sourcing)
source /usr/local/lib/pia-defaults.sh

# Function to log messages with timestamps
log_message() {
    echo "$(date '+%b %d %Y %I:%M%p') [SLEEP] $1" >> "$LOG_FILE"
    if [ "$VERBOSE_LOGGING" = "true" ]; then
        echo "[SLEEP] $1"
    fi
}

# Function to disconnect PIA gracefully with timeout
disconnect_pia() {
    log_message "Disconnecting and quitting PIA GUI..."

    # Disable background mode and disconnect
    "$PIA_CTL" background disable 2>/dev/null
    "$PIA_CTL" disconnect 2>/dev/null
    sleep 3

    # Try to quit gracefully
    if osascript -e 'quit app "Private Internet Access"' 2>/dev/null; then
        # Wait up to 15 seconds for graceful quit
        for attempt in $(seq 1 8); do
            sleep 2
            if ! pgrep -x "Private Internet Access" > /dev/null; then
                log_message "PIA GUI quit successfully"
                return 0
            fi
        done
        log_message "WARNING: PIA GUI still running after 15s timeout"
        return 1
    else
        log_message "WARNING: Failed to send quit command"
        return 1
    fi
}

# Function to force kill PIA GUI if graceful quit fails
force_kill_pia() {
    if pgrep -x "Private Internet Access" > /dev/null; then
        log_message "Force killing PIA GUI"
        pkill -9 -x "Private Internet Access"
        sleep 2
    fi
}

# Function to verify PIA GUI is terminated
verify_gui_terminated() {
    if ! pgrep -x "Private Internet Access" > /dev/null; then
        return 0
    else
        local gui_pid=$(pgrep -x "Private Internet Access")
        log_message "WARNING: PIA GUI still running (PID: $gui_pid)"
        return 1
    fi
}

# Function to check and gracefully close torrent applications
close_torrent_app() {
    local app_name="$1"
    if pgrep -f "$app_name" > /dev/null; then
        log_message "Closing $app_name"
        echo "$app_name" >> "$TORRENT_STATE_FILE"
        pkill -f "$app_name"

        # Wait for app to close
        for i in $(seq 1 $APP_SHUTDOWN_TIMEOUT); do
            if ! pgrep -f "$app_name" > /dev/null; then
                return 0
            fi
            sleep 1
        done

        log_message "WARNING: $app_name still running after ${APP_SHUTDOWN_TIMEOUT}s"
        return 1
    fi
    return 0
}

# Function to close all torrent applications
close_torrent_apps() {
    if [ "$MANAGE_TORRENTS" != "true" ]; then
        return 0
    fi

    log_message "=== Closing Torrents ==="
    rm -f "$TORRENT_STATE_FILE"

    local failed_apps=()
    for app in "${TORRENT_APPS[@]}"; do
        if ! close_torrent_app "$app"; then
            failed_apps+=("$app")
        fi
    done

    if [ ${#failed_apps[@]} -gt 0 ]; then
        log_message "Force killing: ${failed_apps[*]}"
        for app in "${failed_apps[@]}"; do
            pkill -9 -f "$app" 2>/dev/null
        done
        sleep 2
    fi
}

# Function to eject external drive
eject_external_drive() {
    if [ "$MANAGE_EXTERNAL_DRIVE" != "true" ]; then
        return 0
    fi

    log_message "=== Ejecting Drive ==="

    local drive_info=$(diskutil info "$EXTERNAL_DRIVE_NAME" 2>&1)
    if [[ $drive_info == *"could not find disk"* ]]; then
        log_message "Drive '$EXTERNAL_DRIVE_NAME' not found"
        rm -f "$DRIVE_STATE_FILE"
        return 0
    fi

    if [[ $drive_info == *"Mounted: Yes"* ]]; then
        echo "mounted" > "$DRIVE_STATE_FILE"
        local disk_identifier=$(echo "$drive_info" | awk '/Device Identifier:/ {print $3}')

        if diskutil eject "$disk_identifier" >/dev/null 2>&1; then
            # Verify ejection
            for attempt in $(seq 1 $DRIVE_EJECTION_ATTEMPTS); do
                sleep $DRIVE_EJECTION_WAIT
                if diskutil info "$disk_identifier" 2>&1 | grep -q "Mounted: No"; then
                    log_message "Drive ejected successfully"
                    return 0
                fi
            done
            log_message "WARNING: Drive ejection verification failed"
            return 1
        else
            log_message "ERROR: Failed to eject drive (might be in use)"
            return 1
        fi
    else
        rm -f "$DRIVE_STATE_FILE"
    fi
}

# Function to cleanup on exit
cleanup_on_exit() {
    rm -f "$LOCK_FILE"
}

# Set up trap for cleanup
trap cleanup_on_exit EXIT INT TERM

# Main execution
log_message "░▒▓█►─── ✨🌜 SLEEPY TIME 🌛✨ ───◄█▓▒░"
echo "$(date '+%b %d %Y %I:%M%p')" > "$LOCK_FILE"

# Check if PIA GUI is running
if pgrep -x "Private Internet Access" > /dev/null; then
    echo "running" > "$PIA_RUNNING_STATE_FILE"
    echo "connected" > "$STATE_FILE"
    log_message "PIA running - will reconnect on wake"
else
    log_message "PIA not running"
    rm -f "$PIA_RUNNING_STATE_FILE"
    rm -f "$STATE_FILE"
fi

# Close torrents and eject drive
close_torrent_apps
eject_external_drive

# Disconnect and quit PIA
log_message "=== Shutting Down PIA ==="

if ! pgrep -x "Private Internet Access" > /dev/null; then
    log_message "PIA already closed"
    exit 0
fi

# Try graceful quit
if disconnect_pia; then
    if verify_gui_terminated; then
        log_message "💤 Sleep complete"
        exit 0
    fi
    force_kill_pia
else
    force_kill_pia
fi

if ! verify_gui_terminated; then
    log_message "WARNING: PIA GUI may still be running"
fi

log_message "💤 Sleep complete"
exit 0