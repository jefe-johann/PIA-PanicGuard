#!/bin/bash

# PIA VPN Wake Handler
# Handles external drive mounting, optional torrent app reopening, and PIA VPN reconnection

LOG_FILE="/var/log/pia-sleep.log"
STATE_FILE="/tmp/pia-was-connected"
TORRENT_STATE_FILE="/tmp/torrents-were-running"
DRIVE_STATE_FILE="/tmp/drive-was-mounted"
CONFIG_FILE="/usr/local/etc/pia-sleep.conf"
PIA_CTL="/usr/local/bin/piactl"

# Default configuration values
AUTO_RECONNECT="true"
MANAGE_TORRENTS="true"
MANAGE_EXTERNAL_DRIVE="true"
AUTO_REOPEN_APPS="false"
EXTERNAL_DRIVE_NAME="Big Dawg"
TORRENT_APPS=("Transmission" "qbittorrent" "Nicotine+" "VLC" "BiglyBT")
VERBOSE_LOGGING="true"

# Load configuration file if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Function to log messages with timestamps
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WAKE] $1" >> "$LOG_FILE"
    if [ "$VERBOSE_LOGGING" = "true" ]; then
        echo "[WAKE] $1"
    fi
}

# Function to mount external drive
mount_external_drive() {
    if [ "$MANAGE_EXTERNAL_DRIVE" != "true" ]; then
        log_message "External drive management disabled, skipping"
        return 0
    fi
    
    # Check if drive was mounted before sleep
    if [ ! -f "$DRIVE_STATE_FILE" ]; then
        log_message "Drive was not mounted before sleep. Nothing to do."
        return 0
    fi
    
    log_message "=== Mounting External Drive: $EXTERNAL_DRIVE_NAME ==="
    
    # Clean up state file
    rm -f "$DRIVE_STATE_FILE"
    
    # Wait for system to fully wake up
    sleep 3
    
    # Attempt to mount the drive
    local mount_output=$(diskutil mount "$EXTERNAL_DRIVE_NAME" 2>&1)
    local mount_status=$?
    log_message "Mount command output: $mount_output"
    
    if [ $mount_status -eq 0 ]; then
        # Wait and verify mount
        sleep 5
        local mount_info=$(diskutil info "$EXTERNAL_DRIVE_NAME" 2>&1)
        if echo "$mount_info" | grep -q "Mounted:[[:space:]]*Yes"; then
            log_message "SUCCESS: '$EXTERNAL_DRIVE_NAME' mounted successfully"
            return 0
        else
            log_message "WARNING: Mount command succeeded but verification failed"
            return 1
        fi
    else
        log_message "ERROR: Failed to mount '$EXTERNAL_DRIVE_NAME'"
        return 1
    fi
}

# Function to reopen torrent applications
reopen_torrent_apps() {
    local vpn_safe="$1"
    
    if [ "$MANAGE_TORRENTS" != "true" ]; then
        log_message "Torrent management disabled, skipping"
        return 0
    fi
    
    if [ "$AUTO_REOPEN_APPS" != "true" ]; then
        log_message "Auto-reopen disabled. Torrent apps remain closed."
        return 0
    fi
    
    # CRITICAL SAFETY CHECK: Only open torrents if VPN is connected
    if [ "$vpn_safe" != "true" ]; then
        log_message "SECURITY: VPN not verified as connected - skipping torrent app reopening for safety"
        log_message "Torrents will remain closed to prevent IP leakage"
        return 0
    fi
    
    # Check if any apps were running before sleep
    if [ ! -f "$TORRENT_STATE_FILE" ]; then
        log_message "No torrent apps were running before sleep. Nothing to reopen."
        return 0
    fi
    
    log_message "=== Reopening Torrent Applications ==="
    
    # Wait for drive to be ready if it was mounted
    if [ -f "$DRIVE_STATE_FILE" ]; then
        sleep 5
    fi
    
    # Read list of apps that were running and reopen them
    while IFS= read -r app_name; do
        log_message "Reopening: $app_name"
        case "$app_name" in
            "Transmission")
                open -a Transmission
                ;;
            "qbittorrent")
                open -a qBittorrent
                ;;
            "Nicotine+")
                open -a "Nicotine+"
                ;;
            "VLC")
                open -a VLC
                ;;
            "BiglyBT")
                open -a BiglyBT
                ;;
            *)
                log_message "Unknown app: $app_name, attempting generic open"
                open -a "$app_name" 2>/dev/null || log_message "Failed to open $app_name"
                ;;
        esac
    done < "$TORRENT_STATE_FILE"
    
    # Clean up state file
    rm -f "$TORRENT_STATE_FILE"
    log_message "Torrent application reopening complete"
}

# Main execution
log_message "=== Enhanced PIA Wake Handler Started ==="
log_message "Configuration: Torrents=$MANAGE_TORRENTS, Drive=$MANAGE_EXTERNAL_DRIVE, Auto-reopen=$AUTO_REOPEN_APPS"

# Initialize VPN safety flag - only set to true if PIA is verified connected
pia_connected=false

# Step 1: Mount external drive first
mount_external_drive

# Step 2: Handle PIA VPN (existing logic)
log_message "=== Managing PIA VPN ==="

# Check if piactl is available
if [ ! -x "$PIA_CTL" ]; then
    log_message "ERROR: piactl not found at $PIA_CTL"
    exit 1
fi

# Check if PIA was running before sleep
if [ ! -f "$STATE_FILE" ]; then
    log_message "PIA was not running before sleep. No VPN reconnection needed."
    # Step 3: Don't reopen torrents since PIA wasn't running (pia_connected remains false)
    reopen_torrent_apps "$pia_connected"
    log_message "=== Enhanced Wake Handler Completed ===\\n"
    exit 0
fi

log_message "PIA was running before sleep - will restart and reconnect"

# Clean up state file
rm -f "$STATE_FILE"

# Check if auto-reconnect is enabled
if [ "$AUTO_RECONNECT" = "true" ]; then
    log_message "Auto-reconnect enabled. Ensuring PIA is running and connected..."
    
    # Wait a moment for system to fully wake up
    sleep 3
    
    # Check if PIA is already running, if not try to start it
    if ! pgrep -f "Private Internet Access\|pia-daemon" > /dev/null; then
        log_message "PIA not running, attempting to start..."
        # Try to start PIA application - this will start the daemon
        open -a "Private Internet Access" 2>/dev/null || log_message "WARNING: Could not start PIA application"
        sleep 5
    else
        log_message "PIA processes already running"
    fi
    
    # Attempt reconnection
    if "$PIA_CTL" connect 2>&1 | while IFS= read -r line; do
        log_message "piactl: $line"
    done; then
        log_message "PIA reconnection initiated successfully"
        
        # Wait and verify connection
        sleep 5
        connection_state=$("$PIA_CTL" get connectionstate 2>/dev/null)
        log_message "PIA connection state after reconnect: $connection_state"
        
        if [ "$connection_state" = "Connected" ]; then
            log_message "SUCCESS: PIA reconnected successfully"
            pia_connected=true
        else
            log_message "WARNING: PIA reconnection may have failed (state: $connection_state)"
            pia_connected=false
        fi
    else
        log_message "ERROR: Failed to initiate PIA reconnection"
        pia_connected=false
    fi
else
    log_message "Auto-reconnect disabled. PIA remains disconnected."
    log_message "To enable auto-reconnect, set AUTO_RECONNECT=\"true\" in the config file"
    pia_connected=false
fi

# Step 3: Optionally reopen torrent applications (only if VPN is safe)
reopen_torrent_apps "$pia_connected"

log_message "=== Enhanced Wake Handler Completed ===\\n"
exit 0