#!/bin/bash

# PIA VPN Wake Handler
# Handles external drive mounting, optional torrent app reopening, and PIA VPN reconnection

LOG_FILE="/var/log/pia-sleep.log"
STATE_FILE="/tmp/pia-was-connected"
PIA_RUNNING_STATE_FILE="/tmp/pia-was-running"
TORRENT_STATE_FILE="/tmp/torrents-were-running"
DRIVE_STATE_FILE="/tmp/drive-was-mounted"
LOCK_FILE="/tmp/pia-sleep-in-progress"
CONFIG_FILE="/usr/local/etc/pia-sleep.conf"
PIA_CTL="/usr/local/bin/piactl"

# Load shared defaults (includes config file sourcing)
source /usr/local/lib/pia-defaults.sh

# Function to log messages with timestamps
log_message() {
    echo "$(date '+%b %d %Y %I:%M%p') [WAKE] $1" >> "$LOG_FILE"
    if [ "$VERBOSE_LOGGING" = "true" ]; then
        echo "[WAKE] $1"
    fi
}

# Function to mount external drive
mount_external_drive() {
    if [ "$MANAGE_EXTERNAL_DRIVE" != "true" ] || [ ! -f "$DRIVE_STATE_FILE" ]; then
        return 0
    fi

    log_message "=== Mounting Drive ==="
    rm -f "$DRIVE_STATE_FILE"
    sleep 3

    if diskutil mount "$EXTERNAL_DRIVE_NAME" >/dev/null 2>&1; then
        sleep 5
        if diskutil info "$EXTERNAL_DRIVE_NAME" 2>&1 | grep -q "Mounted:[[:space:]]*Yes"; then
            log_message "Drive mounted successfully"
            return 0
        fi
        log_message "WARNING: Mount verification failed"
        return 1
    else
        log_message "ERROR: Failed to mount drive"
        return 1
    fi
}

# Function to resume all Transmission torrents via its RPC API
resume_transmission_torrents() {
    log_message "Resuming Transmission torrents..."

    # Wait for RPC to become available (up to 30s)
    local session_id=""
    for attempt in $(seq 1 12); do
        sleep 2.5
        local response
        response=$(curl -s -i --max-time 3 http://localhost:9091/transmission/rpc 2>/dev/null)
        session_id=$(echo "$response" | grep -i "X-Transmission-Session-Id:" | tr -d '\r' | awk '{print $2}')
        [ -n "$session_id" ] && break
    done

    if [ -z "$session_id" ]; then
        log_message "WARNING: Could not reach Transmission RPC - torrents not resumed"
        return 1
    fi

    local result
    result=$(curl -s --max-time 5 \
        -H "X-Transmission-Session-Id: $session_id" \
        -d '{"method":"torrent-start","arguments":{}}' \
        http://localhost:9091/transmission/rpc 2>/dev/null)

    if echo "$result" | grep -q '"result":"success"'; then
        log_message "Transmission torrents started successfully"
    else
        log_message "WARNING: Transmission RPC start-all failed: $result"
    fi
}

# Function to reopen torrent applications
reopen_torrent_apps() {
    local vpn_safe="$1"

    if [ "$MANAGE_TORRENTS" != "true" ] || [ "$AUTO_REOPEN_APPS" != "true" ]; then
        return 0
    fi

    if [ "$vpn_safe" != "true" ]; then
        log_message "SECURITY: VPN not connected - torrents will remain closed"
        return 0
    fi

    if [ ! -f "$TORRENT_STATE_FILE" ]; then
        return 0
    fi

    log_message "=== Reopening Torrents ==="
    [ -f "$DRIVE_STATE_FILE" ] && sleep 5

    while IFS= read -r app_name; do
        log_message "Opening: $app_name"
        case "$app_name" in
            "Transmission") open -a Transmission; resume_transmission_torrents ;;
            "qbittorrent") open -a qBittorrent ;;
            "Nicotine+") open -a "Nicotine+" ;;
            "VLC") open -a VLC ;;
            "BiglyBT") open -a BiglyBT ;;
            *) open -a "$app_name" 2>/dev/null ;;
        esac
    done < "$TORRENT_STATE_FILE"

    rm -f "$TORRENT_STATE_FILE"
}

# Main execution
log_message "▄▀░▒▓█─── 🕊️ 🌞 WAKE UP TIME 🌞🕊️ ───█▓▒░▀▄"

# Wait for sleep handler if it's still running
if [ -f "$LOCK_FILE" ]; then
    log_message "Waiting for sleep handler..."
    for wait_attempt in $(seq 1 10); do
        sleep 1
        [ ! -f "$LOCK_FILE" ] && break
        [ $wait_attempt -eq 10 ] && rm -f "$LOCK_FILE"
    done
fi

pia_connected=false
mount_external_drive

log_message "=== Starting PIA ==="

if [ ! -x "$PIA_CTL" ]; then
    log_message "ERROR: piactl not found"
    exit 1
fi

if [ ! -f "$PIA_RUNNING_STATE_FILE" ]; then
    log_message "PIA was not running before sleep"
    exit 0
fi

rm -f "$PIA_RUNNING_STATE_FILE"
rm -f "$STATE_FILE"

sleep 3

# Open PIA GUI
gui_needs_start=true
gui_functional=false

if pgrep -x "Private Internet Access" > /dev/null; then
    if "$PIA_CTL" get connectionstate >/dev/null 2>&1; then
        gui_needs_start=false
        gui_functional=true
    else
        log_message "PIA unresponsive, restarting..."
        pkill -9 -x "Private Internet Access" 2>/dev/null || true
        sleep 3
    fi
fi

if [ "$gui_needs_start" = "true" ]; then
    log_message "Opening PIA..."
    if open -g -a "Private Internet Access" 2>/dev/null; then
        # Wait for daemon (up to 15 seconds)
        for attempt in $(seq 1 6); do
            sleep 2.5
            if "$PIA_CTL" get connectionstate >/dev/null 2>&1; then
                log_message "PIA ready"
                gui_functional=true
                break
            fi
        done

        [ "$gui_functional" != "true" ] && log_message "ERROR: PIA daemon timeout"
    else
        log_message "ERROR: Failed to start PIA"
    fi
fi

# Check VPN connection
if [ "$gui_functional" = "true" ]; then
    sleep 6
    actual_state=$("$PIA_CTL" get connectionstate 2>/dev/null)
    log_message "VPN state: $actual_state"

    if [ "$actual_state" = "Connected" ]; then
        pia_connected=true
    elif [ "$actual_state" = "Connecting" ]; then
        log_message "Waiting for VPN connection..."
        for wait_attempt in $(seq 1 10); do
            sleep 2
            actual_state=$("$PIA_CTL" get connectionstate 2>/dev/null)
            if [ "$actual_state" = "Connected" ]; then
                log_message "VPN connected"
                pia_connected=true
                break
            elif [ "$actual_state" = "Disconnected" ]; then
                break
            fi
        done
    fi

    # Try manual reconnect if needed
    if [ "$pia_connected" != "true" ] && [ "$AUTO_RECONNECT" = "true" ]; then
        log_message "Attempting manual reconnect..."
        "$PIA_CTL" connect >/dev/null 2>&1

        for connect_attempt in $(seq 1 12); do
            sleep 2.5
            actual_state=$("$PIA_CTL" get connectionstate 2>/dev/null)
            if [ "$actual_state" = "Connected" ]; then
                log_message "VPN connected"
                pia_connected=true
                break
            elif [ "$actual_state" = "Disconnected" ]; then
                log_message "WARNING: Manual reconnect failed"
                break
            fi
        done
    fi

    [ "$pia_connected" != "true" ] && log_message "WARNING: VPN not connected - torrents blocked"
else
    log_message "ERROR: PIA not functional"
    pia_connected=false
fi

reopen_torrent_apps "$pia_connected"

log_message "☀️ Wake complete"
exit 0