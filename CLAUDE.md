# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This is a macOS system utility that automatically disconnects Private Internet Access (PIA) VPN before system sleep to prevent kernel panics. It uses Homebrew's `sleepwatcher` to monitor system power events and PIA's `piactl` command-line tool for VPN control.

## Architecture Overview

The solution consists of two main bash scripts orchestrated by a macOS LaunchDaemon:

- **Sleep Handler (`pia-sleep.sh`)**: Intercepts sleep events, gracefully disconnects PIA with timeout handling, falls back to process termination if needed, and saves connection state
- **Wake Handler (`pia-wake.sh`)**: Handles wake events and optionally reconnects PIA based on saved state and configuration
- **LaunchDaemon**: Runs `sleepwatcher` as root at boot, pointing to the sleep/wake scripts

## Key Design Principles

1. **Graceful-first approach**: Always attempt PIA's official `piactl disconnect` before force-killing processes
2. **Timeout handling**: 10-second timeout on graceful disconnect with fallback mechanisms
3. **State persistence**: Uses `/tmp/pia-was-connected` to track connection state across sleep/wake cycles
4. **Comprehensive logging**: All actions logged to `/var/log/pia-sleep.log` with timestamps
5. **Verification**: Confirms disconnection before allowing sleep to proceed

## Essential Commands

```bash
# Check comprehensive service status
./status.sh

# Install the service (requires sudo)
sudo ./install.sh

# Remove the service completely
sudo ./uninstall.sh

# Remove conflicting Realtek sleepwatcher setup
sudo ./realtek-uninstall.sh

# View live activity logs
tail -f /var/log/pia-sleep.log

# Test sleep script manually
sudo /usr/local/bin/pia-sleep.sh

# Control the LaunchDaemon service
sudo launchctl unload /Library/LaunchDaemons/com.pia.sleephandler.plist
sudo launchctl load /Library/LaunchDaemons/com.pia.sleephandler.plist

# Check if sleepwatcher process is running with our scripts
pgrep -fl sleepwatcher
```

## File Structure and Installation Model

This project uses a "source + system installation" model:

- **Project directory**: Contains source scripts and installation tools
- **System installation**: Scripts copied to `/usr/local/bin/`, LaunchDaemon to `/Library/LaunchDaemons/`
- **Configuration**: Auto-reconnect setting is in the installed wake script at `/usr/local/bin/pia-wake.sh` (line 11: `AUTO_RECONNECT="true"`)

The installation process copies files from the project directory to proper system locations, so changes to project files require re-running `install.sh` to take effect.

## Critical Dependencies

- **sleepwatcher**: Must be installed via `brew install sleepwatcher`
- **Private Internet Access**: Must be installed with `piactl` available at `/usr/local/bin/piactl`
- **Root privileges**: Required for LaunchDaemon installation and sleep/wake event monitoring

## Troubleshooting Integration Points

The system integrates with macOS power management at the kernel level through sleepwatcher. Key integration points:

- **Power events**: Sleepwatcher receives kernel notifications about sleep/wake transitions
- **Process management**: Scripts interact with PIA daemon and GUI processes
- **LaunchDaemon lifecycle**: Service starts at boot and persists through user login/logout
- **Log integration**: Uses standard `/var/log/` location for system log tools compatibility