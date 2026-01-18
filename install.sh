#!/bin/bash

# PIA VPN Sleep Handler Installation Script
# Installs scripts and LaunchDaemon for automatic PIA disconnect before sleep

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/pia-sleep-install.log"

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

# Check prerequisites
check_prerequisites() {
    log_and_echo "INFO" "Checking prerequisites..."
    
    # Check if sleepwatcher is available
    if ! command -v sleepwatcher >/dev/null 2>&1; then
        log_and_echo "ERROR" "sleepwatcher is not installed. Install with: brew install sleepwatcher"
        exit 1
    fi
    
    # Check if PIA is installed
    if [ ! -x "/Applications/Private Internet Access.app/Contents/MacOS/piactl" ]; then
        log_and_echo "ERROR" "Private Internet Access is not installed"
        exit 1
    fi
    
    log_and_echo "SUCCESS" "Prerequisites check passed"
}

# Check for conflicting sleepwatcher setups
check_conflicts() {
    log_and_echo "INFO" "Checking for conflicting sleepwatcher installations..."
    
    # Check for Realtek setup
    if [ -f "/Library/LaunchDaemons/com.realtek.sleepfix.plist" ]; then
        log_and_echo "ERROR" "Found conflicting Realtek sleepwatcher setup"
        log_and_echo "ERROR" "Please run './realtek-uninstall.sh' first to remove the old setup"
        exit 1
    fi
    
    # Check for other sleepwatcher processes
    if pgrep -f sleepwatcher >/dev/null; then
        log_and_echo "WARNING" "Found running sleepwatcher process"
        log_and_echo "WARNING" "This may conflict with the PIA sleep handler"
        read -p "Continue anyway? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_and_echo "INFO" "Installation cancelled"
            exit 0
        fi
    fi
    
    log_and_echo "SUCCESS" "No conflicts detected"
}

# Install configuration file
install_config() {
    log_and_echo "INFO" "Installing configuration file..."

    # Create /usr/local/etc directory if it doesn't exist
    mkdir -p "/usr/local/etc"

    # Copy configuration file
    cp "$SCRIPT_DIR/pia-sleep.conf" "/usr/local/etc/"

    # Set permissions
    chmod 644 "/usr/local/etc/pia-sleep.conf"
    chown root:wheel "/usr/local/etc/pia-sleep.conf"

    log_and_echo "SUCCESS" "Configuration file installed"
}

# Install PIA scripts
install_scripts() {
    log_and_echo "INFO" "Installing PIA sleep handler scripts..."
    
    # Copy scripts to /usr/local/bin
    cp "$SCRIPT_DIR/pia-sleep.sh" "/usr/local/bin/"
    cp "$SCRIPT_DIR/pia-wake.sh" "/usr/local/bin/"
    
    # Set permissions
    chmod 755 "/usr/local/bin/pia-sleep.sh"
    chmod 755 "/usr/local/bin/pia-wake.sh"
    
    # Set ownership
    chown root:wheel "/usr/local/bin/pia-sleep.sh"
    chown root:wheel "/usr/local/bin/pia-wake.sh"
    
    log_and_echo "SUCCESS" "Scripts installed successfully"
}

# Install helper script for SwiftBar integration
install_helper_script() {
    log_and_echo "INFO" "Installing configuration helper script..."

    if [ -f "$SCRIPT_DIR/pia-config-helper.sh" ]; then
        # Copy helper script to /usr/local/bin
        cp "$SCRIPT_DIR/pia-config-helper.sh" "/usr/local/bin/"

        # Set permissions
        chmod 755 "/usr/local/bin/pia-config-helper.sh"

        # Set ownership
        chown root:wheel "/usr/local/bin/pia-config-helper.sh"

        log_and_echo "SUCCESS" "Helper script installed"
    else
        log_and_echo "INFO" "Helper script not found (optional component)"
    fi
}

# Install LaunchDaemon
install_launchdaemon() {
    log_and_echo "INFO" "Installing LaunchDaemon..."

    # Copy LaunchDaemon plist
    cp "$SCRIPT_DIR/com.pia.sleephandler.plist" "/Library/LaunchDaemons/"

    # Set permissions
    chmod 644 "/Library/LaunchDaemons/com.pia.sleephandler.plist"
    chown root:wheel "/Library/LaunchDaemons/com.pia.sleephandler.plist"

    log_and_echo "SUCCESS" "LaunchDaemon installed"
}

# Load and start the service
start_service() {
    log_and_echo "INFO" "Loading and starting PIA sleep handler service..."
    
    # Load LaunchDaemon
    launchctl load "/Library/LaunchDaemons/com.pia.sleephandler.plist"
    
    # Wait a moment for it to start
    sleep 2
    
    # Check if it's running
    if launchctl list | grep -q "com.pia.sleephandler"; then
        log_and_echo "SUCCESS" "PIA sleep handler service is running"
    else
        log_and_echo "ERROR" "Failed to start PIA sleep handler service"
        exit 1
    fi
}

# Verify installation
verify_installation() {
    log_and_echo "INFO" "Verifying installation..."
    
    # Check if sleepwatcher process is running with our scripts
    if pgrep -f "sleepwatcher.*pia-sleep.sh" >/dev/null; then
        log_and_echo "SUCCESS" "Sleepwatcher is running with PIA scripts"
    else
        log_and_echo "WARNING" "Sleepwatcher process not found. Check logs at /var/log/pia-sleepwatcher-error.log"
    fi
    
    # Check log files
    touch "/var/log/pia-sleep.log"
    chmod 644 "/var/log/pia-sleep.log"
    
    log_and_echo "INFO" "Installation verification complete"
}

# Main execution
main() {
    log_and_echo "INFO" "Starting PIA VPN Sleep Handler installation..."
    log_and_echo "INFO" "Installation log: $LOG_FILE"

    check_root
    check_prerequisites
    check_conflicts
    install_config
    install_scripts
    install_helper_script
    install_launchdaemon
    start_service
    verify_installation
    
    log_and_echo "SUCCESS" "Installation completed successfully!"
    echo
    log_and_echo "INFO" "Configuration:"
    log_and_echo "INFO" "  - Config file: /usr/local/etc/pia-sleep.conf"
    log_and_echo "INFO" "  - Sleep script: /usr/local/bin/pia-sleep.sh"
    log_and_echo "INFO" "  - Wake script: /usr/local/bin/pia-wake.sh"
    log_and_echo "INFO" "  - Service logs: /var/log/pia-sleepwatcher*.log"
    log_and_echo "INFO" "  - Activity logs: /var/log/pia-sleep.log"
    echo
    log_and_echo "INFO" "The service will automatically start at boot."
    echo
    log_and_echo "INFO" "New Features:"
    log_and_echo "INFO" "  - Torrent client management (enabled by default)"
    log_and_echo "INFO" "  - External drive 'Big Dawg' ejection/mounting (enabled by default)"
    log_and_echo "INFO" "  - Auto-reconnect PIA after wake (enabled by default)"
    log_and_echo "INFO" "  - Auto-reopen torrent apps after wake (disabled by default)"
    echo
    log_and_echo "INFO" "To configure features, edit: /usr/local/etc/pia-sleep.conf"
    echo

    # Check for SwiftBar and provide menubar installation hint
    if [ -d "/Applications/SwiftBar.app" ] || [ -d "$HOME/Applications/SwiftBar.app" ] || [ -d "$(eval echo ~$SUDO_USER)/Applications/SwiftBar.app" ]; then
        log_and_echo "INFO" "SwiftBar detected! Install optional menubar plugin:"
        log_and_echo "INFO" "  cp $SCRIPT_DIR/swiftbar/pia-sleep-manager.1m.sh ~/Library/Application\\ Support/SwiftBar/plugins/"
        log_and_echo "INFO" "  chmod +x ~/Library/Application\\ Support/SwiftBar/plugins/pia-sleep-manager.1m.sh"
    elif [ -d "$SCRIPT_DIR/swiftbar" ]; then
        log_and_echo "INFO" "Optional menubar plugin available in: $SCRIPT_DIR/swiftbar/"
        log_and_echo "INFO" "Install SwiftBar (brew install swiftbar) for GUI control"
    fi
}

# Run main function
main "$@"