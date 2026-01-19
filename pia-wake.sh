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
    echo "$(date '+%b %d %Y %I:%M%p') [WAKE] $1" >> "$LOG_FILE"
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

# Check if sleep handler is still running (race condition protection)
if [ -f "$LOCK_FILE" ]; then
    sleep_start_time=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    current_time=$(date '+%b %d %Y %I:%M%p')

    log_message "Found sleep handler lock file (started: $sleep_start_time)"
    log_message "Sleep handler may still be running, waiting briefly..."
    
    # Wait up to 10 seconds for sleep handler to finish
    for wait_attempt in $(seq 1 10); do
        sleep 1
        if [ ! -f "$LOCK_FILE" ]; then
            log_message "Sleep handler completed, proceeding with wake"
            break
        fi
        if [ $wait_attempt -eq 10 ]; then
            log_message "Sleep handler taking too long, removing stale lock and proceeding"
            rm -f "$LOCK_FILE"
        fi
    done
else
    log_message "No sleep handler lock found, proceeding normally"
fi

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

# Check if PIA GUI was running before sleep (new check)
if [ ! -f "$PIA_RUNNING_STATE_FILE" ]; then
    log_message "PIA GUI was not running before sleep. Will not start PIA."
    # Don't reopen torrents since PIA wasn't running (pia_connected remains false)
    reopen_torrent_apps "$pia_connected"
    log_message "=== Enhanced Wake Handler Completed ===\\n"
    exit 0
fi

log_message "PIA GUI was running before sleep - will reopen"

# Clean up the running state file
rm -f "$PIA_RUNNING_STATE_FILE"

# Wait a moment for system to fully wake up
sleep 3

# Step 1: Reopen PIA GUI (always, since it was running before sleep)
gui_needs_start=true
gui_functional=false

if pgrep -x "Private Internet Access" > /dev/null; then
    log_message "PIA GUI already running, checking if it's functional..."

    # Check if the running GUI is responsive
    if "$PIA_CTL" get connectionstate >/dev/null 2>&1; then
        log_message "PIA GUI is functional"
        gui_needs_start=false
        gui_functional=true
    else
        log_message "PIA GUI appears unresponsive, cleaning up..."
        pkill -9 -x "Private Internet Access" 2>/dev/null || true
        sleep 3
    fi
fi

# Start PIA application if needed
if [ "$gui_needs_start" = "true" ]; then
    log_message "Starting PIA GUI application..."
    if open -g -a "Private Internet Access" 2>/dev/null; then
        log_message "PIA application started in background, waiting for daemon initialization..."

        # Wait for daemon to fully initialize (up to 15 seconds)
        daemon_ready=false
        for attempt in $(seq 1 6); do
            sleep 2.5
            if "$PIA_CTL" get connectionstate >/dev/null 2>&1; then
                log_message "PIA daemon ready after ${attempt}x2.5 seconds"
                daemon_ready=true
                gui_functional=true
                break
            fi
            log_message "Waiting for PIA daemon... (attempt $attempt/6)"
        done

        if [ "$daemon_ready" != "true" ]; then
            log_message "ERROR: PIA daemon failed to initialize within 15 seconds"
            gui_functional=false
        fi
    else
        log_message "ERROR: Failed to start PIA application"
        gui_functional=false
    fi
fi

# Step 2: Check if VPN should be reconnected (only if GUI is functional and VPN was connected)
if [ "$gui_functional" = "true" ]; then
    # Check if PIA VPN was connected before sleep
    if [ -f "$STATE_FILE" ]; then
        log_message "PIA VPN was connected before sleep"
        rm -f "$STATE_FILE"

        # Check if auto-reconnect is enabled
        if [ "$AUTO_RECONNECT" = "true" ]; then
            log_message "Auto-reconnect enabled. Attempting VPN connection..."

            if "$PIA_CTL" connect 2>&1 | while IFS= read -r line; do
                log_message "piactl: $line"
            done; then
                log_message "PIA connection command sent successfully"

                # Wait for connection to complete (up to 30 seconds)
                connection_successful=false
                for connect_attempt in $(seq 1 12); do
                    sleep 2.5
                    connection_state=$("$PIA_CTL" get connectionstate 2>/dev/null)
                    log_message "PIA connection state: $connection_state (attempt $connect_attempt/12)"

                    if [ "$connection_state" = "Connected" ]; then
                        log_message "SUCCESS: PIA VPN reconnection successful"
                        connection_successful=true
                        break
                    elif [ "$connection_state" = "Connecting" ]; then
                        log_message "PIA still connecting, waiting..."
                        continue
                    elif [ "$connection_state" = "Disconnected" ]; then
                        log_message "WARNING: PIA connection failed (returned to Disconnected state)"
                        break
                    fi
                done

                if [ "$connection_successful" = "true" ]; then
                    pia_connected=true
                else
                    log_message "WARNING: PIA connection did not complete within 30 seconds (final state: $connection_state)"
                    pia_connected=false
                fi
            else
                log_message "ERROR: Failed to send PIA connection command"
                pia_connected=false
            fi
        else
            log_message "Auto-reconnect disabled. PIA GUI reopened but VPN remains disconnected."
            log_message "To enable auto-reconnect, set AUTO_RECONNECT=\"true\" in the config file"
            pia_connected=false
        fi
    else
        log_message "PIA VPN was NOT connected before sleep - GUI reopened but staying disconnected"
        rm -f "$STATE_FILE"  # Clean up in case it exists
        pia_connected=false
    fi
else
    log_message "PIA GUI could not be started or is not functional, skipping VPN reconnection"
    rm -f "$STATE_FILE"  # Clean up state file
    pia_connected=false
fi

# Step 3: Optionally reopen torrent applications (only if VPN is safe)
reopen_torrent_apps "$pia_connected"

log_message "=== Enhanced Wake Handler Completed ===\\n"
exit 0