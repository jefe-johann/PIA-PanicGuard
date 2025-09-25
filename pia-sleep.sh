#!/bin/bash

# PIA VPN Sleep Handler
# Gracefully handles torrent clients, external drives, and PIA VPN before system sleep

LOG_FILE="/var/log/pia-sleep.log"
STATE_FILE="/tmp/pia-was-connected"
TORRENT_STATE_FILE="/tmp/torrents-were-running"
DRIVE_STATE_FILE="/tmp/drive-was-mounted"
CONFIG_FILE="/usr/local/etc/pia-sleep.conf"
TIMEOUT=10
PIA_CTL="/usr/local/bin/piactl"

# Default configuration values
MANAGE_TORRENTS="true"
MANAGE_EXTERNAL_DRIVE="true"
EXTERNAL_DRIVE_NAME="Big Dawg"
TORRENT_APPS=("Transmission" "qbittorrent" "Nicotine+" "VLC" "BiglyBT")
APP_SHUTDOWN_TIMEOUT=10
DRIVE_EJECTION_ATTEMPTS=3
DRIVE_EJECTION_WAIT=5
VERBOSE_LOGGING="true"

# Load configuration file if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Function to log messages with timestamps
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SLEEP] $1" >> "$LOG_FILE"
    if [ "$VERBOSE_LOGGING" = "true" ]; then
        echo "[SLEEP] $1"
    fi
}

# Function to disconnect PIA gracefully with timeout
disconnect_pia() {
    log_message "Attempting graceful PIA disconnect..."
    
    # Try graceful disconnect with timeout
    timeout $TIMEOUT "$PIA_CTL" disconnect 2>&1 | while IFS= read -r line; do
        log_message "piactl: $line"
    done
    
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        log_message "Graceful disconnect successful"
        return 0
    elif [ $exit_code -eq 124 ]; then
        log_message "WARNING: Graceful disconnect timed out after ${TIMEOUT}s"
        return 1
    else
        log_message "WARNING: Graceful disconnect failed with exit code $exit_code"
        return 1
    fi
}

# Function to force kill PIA processes if graceful disconnect fails
force_kill_pia() {
    log_message "Attempting to force kill PIA processes..."
    
    # Kill main PIA processes
    local killed=0
    for process in "Private Internet Access" "pia-daemon" "pia-wireguard-go"; do
        if pgrep -f "$process" > /dev/null; then
            log_message "Force killing process: $process"
            pkill -f "$process"
            killed=1
        fi
    done
    
    if [ $killed -eq 1 ]; then
        log_message "Force kill attempted. Waiting 2 seconds..."
        sleep 2
    fi
}

# Function to verify PIA processes are terminated
verify_processes_terminated() {
    if ! pgrep -f "Private Internet Access\|pia-daemon\|pia-wireguard-go" > /dev/null; then
        log_message "SUCCESS: All PIA processes terminated"
        return 0
    else
        local running_processes=$(pgrep -fl "Private Internet Access\|pia-daemon\|pia-wireguard-go" | cut -d: -f2-)
        log_message "WARNING: PIA processes still running: $running_processes"
        return 1
    fi
}

# Function to check and gracefully close torrent applications
close_torrent_app() {
    local app_name="$1"
    if pgrep -f "$app_name" > /dev/null; then
        log_message "$app_name is running. Attempting graceful shutdown..."
        
        # Record that this app was running
        echo "$app_name" >> "$TORRENT_STATE_FILE"
        
        # Try graceful shutdown
        pkill -f "$app_name"
        
        # Wait for app to close
        for i in $(seq 1 $APP_SHUTDOWN_TIMEOUT); do
            if ! pgrep -f "$app_name" > /dev/null; then
                log_message "$app_name shut down successfully"
                return 0
            fi
            sleep 1
        done
        
        log_message "WARNING: $app_name still running after ${APP_SHUTDOWN_TIMEOUT}s timeout"
        return 1
    else
        log_message "$app_name is not running"
        return 0
    fi
}

# Function to close all torrent applications
close_torrent_apps() {
    if [ "$MANAGE_TORRENTS" != "true" ]; then
        log_message "Torrent management disabled, skipping"
        return 0
    fi
    
    log_message "=== Closing Torrent Applications ==="
    
    # Clear previous state file
    rm -f "$TORRENT_STATE_FILE"
    
    local failed_apps=()
    for app in "${TORRENT_APPS[@]}"; do
        if ! close_torrent_app "$app"; then
            failed_apps+=("$app")
        fi
    done
    
    if [ ${#failed_apps[@]} -gt 0 ]; then
        log_message "WARNING: Some apps failed to close gracefully: ${failed_apps[*]}"
        log_message "Attempting force kill..."
        for app in "${failed_apps[@]}"; do
            pkill -9 -f "$app" 2>/dev/null
            log_message "Force killed: $app"
        done
        sleep 2
    fi
    
    log_message "Torrent application shutdown complete"
}

# Function to eject external drive
eject_external_drive() {
    if [ "$MANAGE_EXTERNAL_DRIVE" != "true" ]; then
        log_message "External drive management disabled, skipping"
        return 0
    fi
    
    log_message "=== Managing External Drive: $EXTERNAL_DRIVE_NAME ==="
    
    # Check if drive exists and is mounted
    local drive_info=$(diskutil info "$EXTERNAL_DRIVE_NAME" 2>&1)
    if [[ $drive_info == *"could not find disk"* ]]; then
        log_message "'$EXTERNAL_DRIVE_NAME' is not currently mounted or doesn't exist"
        rm -f "$DRIVE_STATE_FILE"
        return 0
    fi
    
    if [[ $drive_info == *"Mounted: Yes"* ]]; then
        log_message "'$EXTERNAL_DRIVE_NAME' is mounted. Recording state and ejecting..."
        
        # Record that drive was mounted
        echo "mounted" > "$DRIVE_STATE_FILE"
        
        # Get disk identifier
        local disk_identifier=$(echo "$drive_info" | awk '/Device Identifier:/ {print $3}')
        log_message "Disk identifier: $disk_identifier"
        
        # Attempt ejection
        if diskutil eject "$disk_identifier"; then
            log_message "'$EXTERNAL_DRIVE_NAME' ejection initiated. Verifying..."
            
            # Verify ejection
            for attempt in $(seq 1 $DRIVE_EJECTION_ATTEMPTS); do
                sleep $DRIVE_EJECTION_WAIT
                log_message "Verification attempt $attempt..."
                
                if diskutil info "$disk_identifier" 2>&1 | grep -q "Mounted: No"; then
                    log_message "SUCCESS: '$EXTERNAL_DRIVE_NAME' successfully ejected"
                    return 0
                fi
            done
            
            log_message "WARNING: Failed to verify '$EXTERNAL_DRIVE_NAME' ejection after $DRIVE_EJECTION_ATTEMPTS attempts"
            return 1
        else
            log_message "ERROR: Failed to eject '$EXTERNAL_DRIVE_NAME'. It might be in use"
            return 1
        fi
    else
        log_message "'$EXTERNAL_DRIVE_NAME' is already ejected"
        rm -f "$DRIVE_STATE_FILE"
        return 0
    fi
}

# Main execution
log_message "=== Enhanced PIA Sleep Handler Started ==="
log_message "Configuration: Torrents=$MANAGE_TORRENTS, Drive=$MANAGE_EXTERNAL_DRIVE"

# Step 1: Close torrent applications first (they may be using the external drive)
close_torrent_apps

# Step 2: Eject external drive
eject_external_drive

# Step 3: Handle PIA VPN (existing logic)
log_message "=== Managing PIA VPN ==="

# Check if piactl is available
if [ ! -x "$PIA_CTL" ]; then
    log_message "ERROR: piactl not found at $PIA_CTL"
    exit 1
fi

# Check current connection state
connection_state=$("$PIA_CTL" get connectionstate 2>/dev/null)
log_message "Current PIA connection state: $connection_state"

# If PIA processes are running, assume it should be reconnected after wake
# (regardless of current connection state, since PIA may auto-disconnect before sleep)
if pgrep -f "Private Internet Access\|pia-daemon\|pia-wireguard-go" > /dev/null; then
    echo "running" > "$STATE_FILE"
    log_message "PIA was running - will reconnect after wake (connection state was: $connection_state)"
else
    log_message "PIA was not running - no reconnect needed after wake"
    rm -f "$STATE_FILE"
fi

# Check if PIA processes are running (regardless of connection state)
if ! pgrep -f "Private Internet Access\|pia-daemon\|pia-wireguard-go" > /dev/null; then
    log_message "No PIA processes running. Nothing to terminate."
    log_message "=== Enhanced Sleep Handler Completed ===\\n"
    exit 0
fi

log_message "PIA processes detected - proceeding with termination to prevent kernel panic"

# Attempt graceful disconnect (which may also terminate processes)
if disconnect_pia; then
    # Verify processes are actually terminated
    if verify_processes_terminated; then
        log_message "SUCCESS: PIA gracefully disconnected and processes terminated"
        log_message "=== Enhanced Sleep Handler Completed Successfully ===\\n"
        exit 0
    else
        log_message "Graceful disconnect succeeded but processes still running"
        force_kill_pia
    fi
else
    log_message "Graceful disconnect failed, attempting force kill"
    force_kill_pia
fi

# Final verification after force kill
if verify_processes_terminated; then
    log_message "SUCCESS: PIA processes terminated after force kill"
else
    log_message "CRITICAL: PIA processes may still be running - kernel panic risk remains"
fi

log_message "=== Enhanced Sleep Handler Completed ===\\n"
exit 0