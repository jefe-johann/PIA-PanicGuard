#!/bin/bash

# Realtek Sleepwatcher Uninstall Script
# Removes the old Realtek network adapter sleep fix

set -e

LOG_FILE="/tmp/realtek-uninstall.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log and display messages
log_and_echo() {
    local level=$1
    local message=$2
    local color=""
    
    case $level in
        "INFO") color=$BLUE ;;
        "SUCCESS") color=$GREEN ;;
        "WARNING") color=$YELLOW ;;
        "ERROR") color=$RED ;;
    esac
    
    echo -e "${color}[$level]${NC} $message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_and_echo "ERROR" "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Stop and remove Realtek sleepwatcher setup
remove_realtek_setup() {
    log_and_echo "INFO" "Removing Realtek sleepwatcher setup..."
    
    local removed_something=false
    
    # Stop and unload LaunchDaemon if exists
    if [ -f "/Library/LaunchDaemons/com.realtek.sleepfix.plist" ]; then
        log_and_echo "INFO" "Stopping and unloading Realtek LaunchDaemon..."
        launchctl unload "/Library/LaunchDaemons/com.realtek.sleepfix.plist" 2>/dev/null || true
        rm -f "/Library/LaunchDaemons/com.realtek.sleepfix.plist"
        log_and_echo "SUCCESS" "Realtek LaunchDaemon removed"
        removed_something=true
    else
        log_and_echo "INFO" "Realtek LaunchDaemon not found"
    fi
    
    # Remove Realtek scripts
    for script in "/usr/local/bin/realtek-sleep.sh" "/usr/local/bin/realtek-wake.sh"; do
        if [ -f "$script" ]; then
            rm -f "$script"
            log_and_echo "SUCCESS" "Removed script: $script"
            removed_something=true
        else
            log_and_echo "INFO" "Script not found: $script"
        fi
    done
    
    # Clean up log files
    read -p "Remove Realtek log files? (/var/log/realtek-*.log) [y/N]: " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f /var/log/realtek-*.log
        log_and_echo "SUCCESS" "Realtek log files removed"
        removed_something=true
    else
        log_and_echo "INFO" "Realtek log files preserved"
    fi
    
    if [ "$removed_something" = true ]; then
        log_and_echo "SUCCESS" "Realtek sleepwatcher setup has been removed"
    else
        log_and_echo "INFO" "No Realtek sleepwatcher setup found to remove"
    fi
}

# Verify removal
verify_removal() {
    log_and_echo "INFO" "Verifying Realtek removal..."
    
    local issues=0
    
    # Check for running processes
    if pgrep -f "sleepwatcher.*realtek" >/dev/null; then
        log_and_echo "WARNING" "Realtek sleepwatcher process still running"
        ((issues++))
    fi
    
    # Check for remaining files
    for file in "/Library/LaunchDaemons/com.realtek.sleepfix.plist" "/usr/local/bin/realtek-sleep.sh" "/usr/local/bin/realtek-wake.sh"; do
        if [ -f "$file" ]; then
            log_and_echo "WARNING" "File still exists: $file"
            ((issues++))
        fi
    done
    
    if [ $issues -eq 0 ]; then
        log_and_echo "SUCCESS" "Realtek removal verified successfully"
    else
        log_and_echo "WARNING" "Removal completed with $issues issues"
    fi
}

# Main execution
main() {
    log_and_echo "INFO" "Starting Realtek sleepwatcher uninstallation..."
    log_and_echo "INFO" "Uninstall log: $LOG_FILE"
    
    check_root
    remove_realtek_setup
    verify_removal
    
    log_and_echo "SUCCESS" "Realtek uninstallation completed!"
    echo
    log_and_echo "INFO" "The Realtek network adapter sleep fix has been removed."
    log_and_echo "INFO" "You can now install other sleepwatcher solutions if needed."
}

# Run main function
main "$@"