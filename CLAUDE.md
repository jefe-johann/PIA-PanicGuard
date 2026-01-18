# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This is an enhanced macOS system utility that automatically manages torrent clients, external drives, and Private Internet Access (PIA) VPN before/after system sleep to prevent kernel panics and data loss. It uses Homebrew's `sleepwatcher` to monitor system power events and integrates with multiple applications.

## Architecture Overview

The solution consists of enhanced bash scripts with comprehensive system management:

- **Enhanced Sleep Handler (`pia-sleep.sh`)**: Closes torrent apps → ejects external drive → disconnects PIA VPN with timeout handling and state persistence
- **Enhanced Wake Handler (`pia-wake.sh`)**: Mounts external drive → reconnects PIA VPN → optionally reopens torrent apps
- **Configuration File (`pia-sleep.conf`)**: Centralized control of all features, installed to `/usr/local/etc/`
- **LaunchDaemon**: Runs `sleepwatcher` as root at boot, pointing to the enhanced scripts

## Key Design Principles

1. **Data Safety First**: Proper shutdown order (torrents → drive → VPN) prevents data corruption
2. **Graceful Operations**: Uses official APIs (`piactl`, `diskutil`, `open`) before force-kill fallbacks
3. **State Persistence**: Tracks what was running/mounted for proper wake restoration
4. **Configurable Features**: All components independently controllable via `/usr/local/etc/pia-sleep.conf`
5. **Comprehensive Logging**: All operations logged to `/var/log/pia-sleep.log` with timestamps
6. **Verification**: Confirms all operations completed successfully before proceeding

## Essential Commands

```bash
# Check enhanced service status (shows all managed components)
./status.sh

# Install/upgrade the enhanced service
sudo ./install.sh

# Remove the service completely
sudo ./uninstall.sh

# View live enhanced activity logs (includes torrents/drive/VPN)
tail -f /var/log/pia-sleep.log

# Edit centralized configuration (all features)
sudo nano /usr/local/etc/pia-sleep.conf

# Test enhanced scripts manually
sudo /usr/local/bin/pia-sleep.sh    # Test full sleep sequence
sudo /usr/local/bin/pia-wake.sh     # Test full wake sequence

# CRITICAL: Service restart workflow (use after script changes)
sudo launchctl unload /Library/LaunchDaemons/com.pia.sleephandler.plist
sudo launchctl load /Library/LaunchDaemons/com.pia.sleephandler.plist

# Quick status checks
pgrep -fl sleepwatcher              # Check if sleepwatcher is running
sudo launchctl list | grep pia      # Check LaunchDaemon status
```

## File Structure and Installation Model

This project uses a "source + system installation" model:

- **Project directory**: Contains source scripts, configuration symlink, and installation tools
- **System installation**:
  - Config: `/usr/local/etc/pia-sleep.conf` (centralized settings, owned by user for easy editing)
  - Scripts: `/usr/local/bin/pia-sleep.sh` and `/usr/local/bin/pia-wake.sh`
  - LaunchDaemon: `/Library/LaunchDaemons/com.pia.sleephandler.plist`
  - State files: `/tmp/pia-was-connected`, `/tmp/torrents-were-running`, `/tmp/drive-was-mounted`

**Config File Note**: The `pia-sleep.conf` file in the project directory is a **symlink** to `/usr/local/etc/pia-sleep.conf`. You can edit it directly in your editor (VSCode, etc.) and changes take effect immediately - no installation step needed.

**IMPORTANT**: Changes to project scripts require service restart (unload/load LaunchDaemon). Configuration file changes take effect immediately.

## Critical Dependencies

- **sleepwatcher**: Must be installed via `brew install sleepwatcher`
- **Private Internet Access**: Must be installed with `piactl` available at `/usr/local/bin/piactl`
- **External Drive**: "Big Dawg" (configurable in pia-sleep.conf)
- **Torrent Applications**: Transmission, qBittorrent, Nicotine+, VLC, BiglyBT (configurable)
- **Root privileges**: Required for LaunchDaemon installation and system-level sleep/wake monitoring

## Troubleshooting Integration Points

The enhanced system integrates with multiple macOS subsystems. Key integration points:

- **Power Management**: Sleepwatcher receives kernel notifications about sleep/wake transitions
- **Process Management**: Scripts interact with PIA daemon, torrent applications, and system processes
- **Disk Management**: Uses `diskutil` for safe external drive ejection and mounting
- **Application Management**: Uses `open` and process control for torrent application lifecycle
- **LaunchDaemon Lifecycle**: Service starts at boot and persists through user login/logout
- **Log Integration**: Uses standard `/var/log/` location for system log tools compatibility

## Development Workflow

When modifying this project as Claude Code:

1. **Config Changes**: Edit `pia-sleep.conf` in the project directory (it's a symlink to `/usr/local/etc/pia-sleep.conf`) - changes take effect immediately, no installation needed

2. **Script Changes**: After editing `pia-sleep.sh` or `pia-wake.sh` in the project directory:

**CRITICAL**: Always inform the user to run the update script after script changes:

```bash
sudo ./update.sh
```

**What the update script does:**
- Copies updated scripts from project directory to `/usr/local/bin/`
- Sets correct permissions and ownership
- Restarts the LaunchDaemon service
- Verifies the update was successful

3. **Testing**: Use `./status.sh` to verify all components, `sudo /usr/local/bin/pia-sleep.sh` to test manually
4. **Verification**: Check `/var/log/pia-sleep.log` for detailed operation logs

## SwiftBar Plugin Development

**Location:** `swiftbar/pia-sleep-manager.1m.sh`

The SwiftBar menubar plugin provides GUI control over the sleep management system. It's an optional component that works alongside the core bash scripts.

**Key Points:**
- Plugin runs as **user** (not root), unlike the core scripts
- Uses `osascript "with administrator privileges"` for sudo operations (service control, config changes)
- Refresh rate controlled by filename: `1m` = 1 minute, `30s` = 30 seconds, etc.
- No compilation needed - pure bash script
- Reads config from `/usr/local/etc/pia-sleep.conf` (same as core scripts)

**Helper Script:** `/usr/local/bin/pia-config-helper.sh`
- Validates and modifies configuration file settings
- Installed via `install.sh`, updated via `update.sh`
- Called by plugin via osascript for secure config editing

**Testing Plugin Changes:**
1. Edit plugin in project directory: `swiftbar/pia-sleep-manager.1m.sh`
2. Copy to SwiftBar plugins directory:
   ```bash
   cp swiftbar/pia-sleep-manager.1m.sh ~/Library/Application\ Support/SwiftBar/plugins/
   ```
   Or use a symlink for live editing:
   ```bash
   ln -s "$(pwd)/swiftbar/pia-sleep-manager.1m.sh" ~/Library/Application\ Support/SwiftBar/plugins/
   ```
3. Refresh SwiftBar (Cmd+R in SwiftBar menu, or restart app)
4. Check SwiftBar console for errors (SwiftBar → Preferences → Console)

**IMPORTANT - For Claude Code:** After making ANY changes to `swiftbar/pia-sleep-manager.1m.sh`, ALWAYS remind the user to copy the updated plugin to SwiftBar:
```bash
cp swiftbar/pia-sleep-manager.1m.sh ~/Library/Application\ Support/SwiftBar/plugins/
```
Then refresh SwiftBar (Cmd+R) or restart it to see the changes.

**Plugin Behavior:**
- Updates every 1 minute automatically (1m refresh rate)
- **No system restart needed** for plugin changes (unlike core sleep/wake scripts)
- Status detection uses non-sudo commands where possible:
  - `pgrep -f "sleepwatcher.*pia-sleep.sh"` - Check if service running
  - `piactl get connectionstate` - Check VPN state
  - `diskutil info "$EXTERNAL_DRIVE_NAME"` - Check drive status
- Actions requiring sudo trigger macOS password prompt via osascript

**Common Debugging:**
- If plugin doesn't appear: Check executable permissions, verify file in correct directory
- If status not updating: Check refresh rate (1m = 1 minute), manually refresh
- If toggles don't work: Verify helper script installed at `/usr/local/bin/pia-config-helper.sh`
- Check SwiftBar console for script errors

### When Script Updates Are Required

**Script File Changes** (requires copy + restart):
- Editing `pia-sleep.sh` or `pia-wake.sh` in project directory
- Logic changes, bug fixes, new functionality
- Process detection patterns, timeout values in scripts

**LaunchDaemon Changes** (requires restart only):
- Modifying `com.pia.sleephandler.plist`

**No Restart Needed** (config changes):
- Editing `/usr/local/etc/pia-sleep.conf`
- Enabling/disabling features
- Changing timeouts, drive names, app lists

## Configuration Management

All features are controlled via `/usr/local/etc/pia-sleep.conf`:
- `MANAGE_TORRENTS="true/false"` - Enable torrent client management
- `MANAGE_EXTERNAL_DRIVE="true/false"` - Enable external drive management  
- `AUTO_RECONNECT="true/false"` - Auto-reconnect PIA after wake
- `AUTO_REOPEN_APPS="true/false"` - Auto-reopen torrent apps after wake
- `EXTERNAL_DRIVE_NAME="Big Dawg"` - Name of external drive to manage
- `TORRENT_APPS=(...)` - Array of torrent applications to manage