#!/bin/bash

# PIA VPN Wake Handler
# Optionally reconnects PIA VPN after system wake if it was connected before sleep

LOG_FILE="/var/log/pia-sleep.log"
STATE_FILE="/tmp/pia-was-connected"
PIA_CTL="/usr/local/bin/piactl"

# Configuration: Set to "true" to auto-reconnect, "false" to just log
AUTO_RECONNECT="true"

# Function to log messages with timestamps
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WAKE] $1" >> "$LOG_FILE"
}

# Main execution
log_message "=== PIA Wake Handler Started ==="

# Check if piactl is available
if [ ! -x "$PIA_CTL" ]; then
    log_message "ERROR: piactl not found at $PIA_CTL"
    exit 1
fi

# Check if PIA was connected before sleep
if [ ! -f "$STATE_FILE" ]; then
    log_message "PIA was not connected before sleep. Nothing to do."
    exit 0
fi

log_message "PIA was connected before sleep"

# Clean up state file
rm -f "$STATE_FILE"

# Check if auto-reconnect is enabled
if [ "$AUTO_RECONNECT" = "true" ]; then
    log_message "Auto-reconnect enabled. Attempting to reconnect PIA..."
    
    # Wait a moment for system to fully wake up
    sleep 3
    
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
        else
            log_message "WARNING: PIA reconnection may have failed (state: $connection_state)"
        fi
    else
        log_message "ERROR: Failed to initiate PIA reconnection"
    fi
else
    log_message "Auto-reconnect disabled. PIA remains disconnected."
    log_message "To enable auto-reconnect, set AUTO_RECONNECT=\"true\" in this script"
fi

log_message "=== Wake Handler Completed ===\n"
exit 0