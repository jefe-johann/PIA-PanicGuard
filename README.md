# PIA VPN Sleep Handler

Automatically disconnects Private Internet Access VPN before macOS sleep to prevent kernel panics.

## Overview

This solution uses `sleepwatcher` (via Homebrew) to monitor system sleep events and gracefully disconnect PIA VPN before sleep occurs. This prevents kernel panics that can occur when PIA VPN is active during sleep transitions.

## Features

- **Graceful Disconnection**: Uses PIA's official `piactl disconnect` command
- **Timeout Handling**: Falls back to force-kill if graceful disconnect times out
- **Optional Reconnect**: Can optionally reconnect VPN after wake (disabled by default)
- **Comprehensive Logging**: All actions logged to `/var/log/pia-sleep.log`
- **Automatic Startup**: Runs automatically at boot via LaunchDaemon
- **Clean Installation**: Removes old Realtek sleepwatcher setup if present

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

### Auto-Reconnect After Wake

By default, PIA remains disconnected after wake. To enable auto-reconnect:

1. Edit `/usr/local/bin/pia-wake.sh`
2. Change `AUTO_RECONNECT="false"` to `AUTO_RECONNECT="true"`
3. The service will automatically pick up the change

### Logging

- **Activity logs**: `/var/log/pia-sleep.log` - All sleep/wake actions
- **Service logs**: `/var/log/pia-sleepwatcher.log` - Sleepwatcher daemon output
- **Error logs**: `/var/log/pia-sleepwatcher-error.log` - Service errors

## How It Works

1. **Sleep Detection**: Sleepwatcher monitors system power events
2. **Pre-Sleep Action**: When sleep is detected, `pia-sleep.sh` runs:
   - Checks if PIA is connected
   - Saves connection state for optional wake reconnect
   - Attempts graceful disconnect with 10-second timeout
   - Falls back to force-kill if graceful disconnect fails
   - Verifies disconnection before allowing sleep
3. **Wake Action**: When system wakes, `pia-wake.sh` runs:
   - Checks if PIA was connected before sleep
   - Optionally reconnects if enabled

## File Locations

### Installed System Files
- **`/usr/local/bin/pia-sleep.sh`** - Sleep handler script (runs before sleep)
- **`/usr/local/bin/pia-wake.sh`** - Wake handler script (runs after wake)
- **`/Library/LaunchDaemons/com.pia.sleephandler.plist`** - LaunchDaemon configuration

### Log Files (Created Automatically)
- **`/var/log/pia-sleep.log`** - Main activity log (sleep/wake actions, PIA disconnect/reconnect)
- **`/var/log/pia-sleepwatcher.log`** - Sleepwatcher daemon stdout
- **`/var/log/pia-sleepwatcher-error.log`** - Sleepwatcher daemon errors

### Temporary Files
- **`/tmp/pia-was-connected`** - Connection state file (created/removed automatically)

### Project Directory Files (This Directory)
- **`pia-sleep.sh`** - Source version of sleep script
- **`pia-wake.sh`** - Source version of wake script (AUTO_RECONNECT="true")
- **`com.pia.sleephandler.plist`** - Source LaunchDaemon configuration
- **`install.sh`** - Installation script
- **`uninstall.sh`** - Complete removal script
- **`realtek-uninstall.sh`** - Separate Realtek cleanup script
- **`status.sh`** - Service status checker
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
# Check service status (comprehensive check)
./status.sh

# View recent activity
tail -f /var/log/pia-sleep.log

# Check if service is running (quick check)
sudo launchctl list | grep pia

# Restart the service
sudo launchctl unload /Library/LaunchDaemons/com.pia.sleephandler.plist
sudo launchctl load /Library/LaunchDaemons/com.pia.sleephandler.plist

# Test manually
sudo /usr/local/bin/pia-sleep.sh

# Enable/disable auto-reconnect
sudo nano /usr/local/bin/pia-wake.sh
# Change AUTO_RECONNECT="true/false"
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

1. **Graceful shutdown over speed** - Uses proper PIA disconnect API first
2. **Reliability** - Multiple fallback mechanisms if graceful disconnect fails
3. **Logging** - Comprehensive logging for troubleshooting
4. **Safety** - Verifies disconnection before allowing sleep to proceed

## License

This project is provided as-is for personal use. Private Internet Access and sleepwatcher are products of their respective owners.