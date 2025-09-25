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
    log_message "Auto-reconnect enabled. Performing clean PIA restart..."
    
    # Wait a moment for system to fully wake up
    sleep 3
    
    # Step 1: Clean up any lingering PIA processes (may be zombies from force kill)
    if pgrep -f "Private Internet Access|pia-daemon|pia-wireguard-go" > /dev/null; then
        log_message "Found lingering PIA processes, cleaning up..."
        pkill -9 -f "Private Internet Access" 2>/dev/null || true
        pkill -9 -f "pia-daemon" 2>/dev/null || true
        pkill -9 -f "pia-wireguard-go" 2>/dev/null || true
        sleep 3
    fi
    
    # Step 2: Start PIA application fresh
    log_message "Starting PIA application fresh..."
    if open -a "Private Internet Access" 2>/dev/null; then
        log_message "PIA application started, waiting for daemon initialization..."
        
        # Step 3: Wait for daemon to fully initialize (up to 15 seconds)
        daemon_ready=false
        for attempt in $(seq 1 6); do
            sleep 2.5
            if "$PIA_CTL" get connectionstate >/dev/null 2>&1; then
                log_message "PIA daemon ready after ${attempt}x2.5 seconds"
                daemon_ready=true
                break
            fi
            log_message "Waiting for PIA daemon... (attempt $attempt/6)"
        done
        
        if [ "$daemon_ready" = "true" ]; then
            # Step 4: Attempt connection
            log_message "Attempting PIA connection..."
            if "$PIA_CTL" connect 2>&1 | while IFS= read -r line; do
                log_message "piactl: $line"
            done; then
                log_message "PIA connection command sent successfully"
                
                # Wait and verify connection
                sleep 5
                connection_state=$("$PIA_CTL" get connectionstate 2>/dev/null)
                log_message "PIA connection state after connect: $connection_state"
                
                if [ "$connection_state" = "Connected" ]; then
                    log_message "SUCCESS: PIA clean restart and connection successful"
                    pia_connected=true
                else
                    log_message "WARNING: PIA connection may have failed (state: $connection_state)"
                    pia_connected=false
                fi
            else
                log_message "ERROR: Failed to send PIA connection command"
                pia_connected=false
            fi
        else
            log_message "ERROR: PIA daemon failed to initialize within 15 seconds"
            pia_connected=false
        fi
    else
        log_message "ERROR: Failed to start PIA application"
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