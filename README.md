# Enhanced PIA VPN Sleep Handler

Automatically manages torrent clients, external drives, and Private Internet Access VPN before/after macOS sleep to prevent kernel panics and data loss.

## Overview

This solution uses `sleepwatcher` (via Homebrew) to monitor system sleep events and gracefully disconnect PIA VPN before sleep occurs. This prevents kernel panics that can occur when PIA VPN is active during sleep transitions.

## Features

### Core VPN Management
- **Graceful VPN Disconnection**: Uses PIA's official `piactl disconnect` command
- **Timeout Handling**: Falls back to force-kill if graceful disconnect times out
- **Auto Reconnect**: Automatically reconnects VPN after wake (enabled by default)

### New: Torrent Client Management
- **Graceful App Shutdown**: Closes torrent clients before VPN disconnect
- **Multiple Client Support**: Handles Transmission, qBittorrent, Nicotine+, VLC, BiglyBT
- **Optional Auto-Reopen**: Can reopen torrent clients after wake (disabled by default)
- **State Persistence**: Remembers which apps were running before sleep

### New: External Drive Management
- **Safe Drive Ejection**: Ejects external drive "Big Dawg" before sleep
- **Automatic Remounting**: Remounts drive after wake if it was mounted before
- **Verification**: Confirms successful ejection before allowing sleep

### System Integration
- **Configurable Features**: All features controlled via `/usr/local/etc/pia-sleep.conf`
- **Comprehensive Logging**: All actions logged to `/var/log/pia-sleep.log`
- **Automatic Startup**: Runs automatically at boot via LaunchDaemon
- **Enhanced Status Checking**: Shows status of all managed components

## Prerequisites

- macOS system with Private Internet Access installed
- `sleepwatcher` installed via Homebrew: `brew install sleepwatcher`
- Administrator privileges for installation

## Installation

1. **If you have an old Realtek sleepwatcher setup, remove it first**:
   ```bash
   sudo ./realtek-uninstall.sh
   ```

2. **Run the PIA installation script**:
   ```bash
   sudo ./install.sh
   ```

   The script will:
   - Check for conflicting sleepwatcher installations
   - Install PIA sleep/wake scripts to `/usr/local/bin/`
   - Install and load the LaunchDaemon
   - Start the sleepwatcher service

3. **Verify installation**:
   ```bash
   # Check if sleepwatcher is running
   pgrep -f sleepwatcher
   
   # Check service status
   sudo launchctl list | grep pia
   ```

## Configuration

### Configuration File: `/usr/local/etc/pia-sleep.conf`

All features are controlled via the configuration file:

```bash
# Features to enable/disable
MANAGE_TORRENTS="true"           # Enable torrent client management
MANAGE_EXTERNAL_DRIVE="true"     # Enable external drive management
AUTO_RECONNECT="true"            # Auto-reconnect PIA after wake
AUTO_REOPEN_APPS="false"         # Auto-reopen torrent apps after wake

# External drive configuration
EXTERNAL_DRIVE_NAME="Big Dawg"   # Name of external drive to manage

# Torrent applications to manage
TORRENT_APPS=("Transmission" "qbittorrent" "Nicotine+" "VLC" "BiglyBT")

# Timeout settings (in seconds)
APP_SHUTDOWN_TIMEOUT=10          # Time to wait for app shutdown
DRIVE_EJECTION_ATTEMPTS=3        # Number of ejection verification attempts
DRIVE_EJECTION_WAIT=5            # Wait time between verification attempts

# Logging
VERBOSE_LOGGING="true"           # Show detailed output during operations
```

**To modify configuration:**
1. Edit `/usr/local/etc/pia-sleep.conf`
2. Changes take effect immediately (no service restart needed)

### Logging

- **Activity logs**: `/var/log/pia-sleep.log` - All sleep/wake actions
- **Service logs**: `/var/log/pia-sleepwatcher.log` - Sleepwatcher daemon output
- **Error logs**: `/var/log/pia-sleepwatcher-error.log` - Service errors

## How It Works

### Sleep Sequence (pia-sleep.sh)
1. **Torrent Management**: Gracefully closes running torrent applications
   - Records which apps were running for wake handler
   - 10-second timeout per app, then force-kill if needed
2. **Drive Management**: Safely ejects external drive "Big Dawg"
   - Records mount state for wake handler
   - Multiple verification attempts to ensure safe ejection
3. **VPN Management**: Disconnects PIA VPN
   - Saves connection state for wake reconnect
   - Graceful disconnect with timeout, force-kill fallback
   - Verifies disconnection before allowing sleep

### Wake Sequence (pia-wake.sh)
1. **Drive Management**: Remounts external drive if it was mounted before sleep
2. **VPN Management**: Reconnects PIA VPN if it was connected before sleep
3. **App Management**: Optionally reopens torrent applications (if enabled)

### Order of Operations
**Before Sleep**: Torrents → Drive → VPN → Sleep  
**After Wake**: Drive → VPN → Apps (optional)

## File Locations

### Installed System Files
- **`/usr/local/etc/pia-sleep.conf`** - Main configuration file
- **`/usr/local/bin/pia-sleep.sh`** - Enhanced sleep handler script
- **`/usr/local/bin/pia-wake.sh`** - Enhanced wake handler script
- **`/Library/LaunchDaemons/com.pia.sleephandler.plist`** - LaunchDaemon configuration

### Log Files (Created Automatically)
- **`/var/log/pia-sleep.log`** - Main activity log (sleep/wake actions, PIA disconnect/reconnect)
- **`/var/log/pia-sleepwatcher.log`** - Sleepwatcher daemon stdout
- **`/var/log/pia-sleepwatcher-error.log`** - Sleepwatcher daemon errors

### Temporary Files (Created/Removed Automatically)
- **`/tmp/pia-was-connected`** - PIA connection state
- **`/tmp/torrents-were-running`** - List of torrent apps that were running
- **`/tmp/drive-was-mounted`** - External drive mount state

### Project Directory Files (This Directory)
- **`pia-sleep.conf`** - Source configuration file with all features enabled
- **`pia-sleep.sh`** - Source version of enhanced sleep script
- **`pia-wake.sh`** - Source version of enhanced wake script
- **`com.pia.sleephandler.plist`** - Source LaunchDaemon configuration
- **`install.sh`** - Installation script (handles new config file)
- **`uninstall.sh`** - Complete removal script (removes all components)
- **`realtek-uninstall.sh`** - Separate Realtek cleanup script
- **`status.sh`** - Enhanced status checker (shows torrent/drive status)
- **`README.md`** - This documentation

## Uninstallation

To completely remove the PIA sleep handler:

```bash
sudo ./uninstall.sh
```

This will:
- Stop and unload the LaunchDaemon
- Remove all installed scripts and configuration files
- Optionally remove log files
- Clean up temporary state files

## Quick Reference

### Most Common Commands
```bash
# Check enhanced service status (shows all features)
./status.sh

# View recent activity (now includes torrent/drive actions)
tail -f /var/log/pia-sleep.log

# Edit configuration (all features)
sudo nano /usr/local/etc/pia-sleep.conf

# Test enhanced sleep handler manually
sudo /usr/local/bin/pia-sleep.sh

# Test enhanced wake handler manually
sudo /usr/local/bin/pia-wake.sh

# Quick service check
sudo launchctl list | grep pia

# Restart the service
sudo launchctl unload /Library/LaunchDaemons/com.pia.sleephandler.plist
sudo launchctl load /Library/LaunchDaemons/com.pia.sleephandler.plist
```

### Feature-Specific Commands
```bash
# Disable torrent management only
sudo sed -i '' 's/MANAGE_TORRENTS="true"/MANAGE_TORRENTS="false"/' /usr/local/etc/pia-sleep.conf

# Disable external drive management only
sudo sed -i '' 's/MANAGE_EXTERNAL_DRIVE="true"/MANAGE_EXTERNAL_DRIVE="false"/' /usr/local/etc/pia-sleep.conf

# Enable auto-reopen of torrent apps after wake
sudo sed -i '' 's/AUTO_REOPEN_APPS="false"/AUTO_REOPEN_APPS="true"/' /usr/local/etc/pia-sleep.conf

# Check what torrent apps are currently running
pgrep -fl "Transmission\|qbittorrent\|Nicotine\+\|VLC\|BiglyBT"

# Check external drive status
diskutil info "Big Dawg"
```

## Troubleshooting

### Check if sleepwatcher is running
```bash
pgrep -fl sleepwatcher
```

### View recent activity logs
```bash
tail -f /var/log/pia-sleep.log
```

### Manual service control
```bash
# Stop service
sudo launchctl unload /Library/LaunchDaemons/com.pia.sleephandler.plist

# Start service
sudo launchctl load /Library/LaunchDaemons/com.pia.sleephandler.plist
```

### Test sleep script manually
```bash
sudo /usr/local/bin/pia-sleep.sh
```

## Design Priorities

1. **Data Safety**: Torrent clients closed before drive ejection, drive ejected before VPN disconnect
2. **Graceful Operations**: Uses proper APIs (piactl, diskutil) before force-kill fallbacks
3. **State Preservation**: Remembers what was running/mounted for proper wake restoration
4. **Configurability**: All features can be independently enabled/disabled
5. **Comprehensive Logging**: All operations logged with timestamps for troubleshooting
6. **Verification**: Confirms all operations completed successfully before proceeding

## Migration from Basic Version

If you're upgrading from the basic VPN-only version:

1. **Automatic**: Run `sudo ./install.sh` - it will create the new config file with all features enabled
2. **Manual**: Edit `/usr/local/etc/pia-sleep.conf` to disable unwanted features
3. **Your existing PIA settings are preserved** - AUTO_RECONNECT remains "true"

## Changelog

### v2.0 - Enhanced Features
- **NEW**: Torrent client management (Transmission, qBittorrent, Nicotine+, VLC, BiglyBT)
- **NEW**: External drive "Big Dawg" ejection/mounting
- **NEW**: Centralized configuration file `/usr/local/etc/pia-sleep.conf`
- **NEW**: Optional auto-reopen of torrent applications after wake
- **IMPROVED**: Enhanced status checker shows all managed components
- **IMPROVED**: Better logging with verbose mode option
- **IMPROVED**: State tracking for wake restoration

### v1.0 - Basic VPN Management
- PIA VPN disconnect before sleep
- Optional VPN reconnect after wake
- Basic sleepwatcher integration

## License

This project is provided as-is for personal use. Private Internet Access, sleepwatcher, and all managed applications are products of their respective owners.