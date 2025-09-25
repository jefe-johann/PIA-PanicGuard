#!/bin/bash

# PIA VPN Sleep Handler
# Gracefully disconnects PIA VPN before system sleep to prevent kernel panics

LOG_FILE="/var/log/pia-sleep.log"
STATE_FILE="/tmp/pia-was-connected"
TIMEOUT=10
PIA_CTL="/usr/local/bin/piactl"

# Function to log messages with timestamps
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SLEEP] $1" >> "$LOG_FILE"
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

# Function to verify PIA is disconnected
verify_disconnected() {
    local state=$("$PIA_CTL" get connectionstate 2>/dev/null)
    if [ "$state" = "Disconnected" ]; then
        log_message "Verified: PIA is disconnected"
        return 0
    else
        log_message "WARNING: PIA may still be connected (state: $state)"
        return 1
    fi
}

# Main execution
log_message "=== PIA Sleep Handler Started ==="

# Check if piactl is available
if [ ! -x "$PIA_CTL" ]; then
    log_message "ERROR: piactl not found at $PIA_CTL"
    exit 1
fi

# Check current connection state
connection_state=$("$PIA_CTL" get connectionstate 2>/dev/null)
log_message "Current PIA connection state: $connection_state"

# If not connected, nothing to do
if [ "$connection_state" = "Disconnected" ]; then
    log_message "PIA is already disconnected. Nothing to do."
    rm -f "$STATE_FILE"
    exit 0
fi

# Save the fact that PIA was connected (for wake script)
echo "connected" > "$STATE_FILE"
log_message "Saved connection state for wake handler"

# Attempt graceful disconnect
if disconnect_pia; then
    # Verify disconnection
    if verify_disconnected; then
        log_message "SUCCESS: PIA gracefully disconnected"
        log_message "=== Sleep Handler Completed Successfully ===\n"
        exit 0
    else
        log_message "Graceful disconnect claimed success but verification failed"
        force_kill_pia
    fi
else
    log_message "Graceful disconnect failed, attempting force kill"
    force_kill_pia
fi

# Final verification after force kill
if verify_disconnected; then
    log_message "SUCCESS: PIA disconnected after force kill"
else
    log_message "CRITICAL: PIA may still be running after all disconnect attempts"
fi

log_message "=== Sleep Handler Completed ===\n"
exit 0