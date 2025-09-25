#!/bin/bash

# PIA VPN Sleep Handler Uninstall Script
# Removes all components of the PIA sleep handler

set -e

LOG_FILE="/tmp/pia-sleep-uninstall.log"

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

# Stop and unload service
stop_service() {
    log_and_echo "INFO" "Stopping PIA sleep handler service..."
    
    if launchctl list | grep -q "com.pia.sleephandler"; then
        launchctl unload "/Library/LaunchDaemons/com.pia.sleephandler.plist" 2>/dev/null || true
        log_and_echo "SUCCESS" "Service stopped and unloaded"
    else
        log_and_echo "INFO" "Service was not running"
    fi
}

# Remove LaunchDaemon
remove_launchdaemon() {
    log_and_echo "INFO" "Removing LaunchDaemon..."
    
    if [ -f "/Library/LaunchDaemons/com.pia.sleephandler.plist" ]; then
        rm -f "/Library/LaunchDaemons/com.pia.sleephandler.plist"
        log_and_echo "SUCCESS" "LaunchDaemon removed"
    else
        log_and_echo "INFO" "LaunchDaemon was not installed"
    fi
}

# Remove configuration file
remove_config() {
    log_and_echo "INFO" "Removing configuration file..."
    
    if [ -f "/usr/local/etc/pia-sleep.conf" ]; then
        rm -f "/usr/local/etc/pia-sleep.conf"
        log_and_echo "SUCCESS" "Configuration file removed"
    else
        log_and_echo "INFO" "Configuration file was not found"
    fi
}

# Remove scripts
remove_scripts() {
    log_and_echo "INFO" "Removing PIA sleep handler scripts..."
    
    for script in "/usr/local/bin/pia-sleep.sh" "/usr/local/bin/pia-wake.sh"; do
        if [ -f "$script" ]; then
            rm -f "$script"
            log_and_echo "SUCCESS" "Removed: $script"
        else
            log_and_echo "INFO" "Script not found: $script"
        fi
    done
}

# Clean up temporary files and logs
cleanup_files() {
    log_and_echo "INFO" "Cleaning up temporary files..."
    
    # Remove state files
    rm -f "/tmp/pia-was-connected"
    rm -f "/tmp/torrents-were-running"
    rm -f "/tmp/drive-was-mounted"
    
    # Ask about log files
    echo
    read -p "Remove log files? (/var/log/pia-*.log) [y/N]: " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f /var/log/pia-*.log
        log_and_echo "SUCCESS" "Log files removed"
    else
        log_and_echo "INFO" "Log files preserved"
    fi
}

# Verify uninstallation
verify_uninstall() {
    log_and_echo "INFO" "Verifying uninstallation..."
    
    local issues=0
    
    # Check for running processes
    if pgrep -f "sleepwatcher.*pia-sleep.sh" >/dev/null; then
        log_and_echo "WARNING" "Sleepwatcher process still running with PIA scripts"
        ((issues++))
    fi
    
    # Check for remaining files
    for file in "/Library/LaunchDaemons/com.pia.sleephandler.plist" "/usr/local/etc/pia-sleep.conf" "/usr/local/bin/pia-sleep.sh" "/usr/local/bin/pia-wake.sh"; do
        if [ -f "$file" ]; then
            log_and_echo "WARNING" "File still exists: $file"
            ((issues++))
        fi
    done
    
    if [ $issues -eq 0 ]; then
        log_and_echo "SUCCESS" "Uninstallation verified successfully"
    else
        log_and_echo "WARNING" "Uninstallation completed with $issues issues"
    fi
}

# Main execution
main() {
    log_and_echo "INFO" "Starting PIA VPN Sleep Handler uninstallation..."
    log_and_echo "INFO" "Uninstall log: $LOG_FILE"
    
    check_root
    stop_service
    remove_launchdaemon
    remove_config
    remove_scripts
    cleanup_files
    verify_uninstall
    
    log_and_echo "SUCCESS" "Uninstallation completed!"
    echo
    log_and_echo "INFO" "The PIA VPN Sleep Handler has been removed from your system."
    log_and_echo "INFO" "Your PIA VPN will no longer be automatically disconnected before sleep."
}

# Run main function
main "$@"