# SwiftBar Menubar Integration

A SwiftBar plugin for convenient menubar access to the PIA VPN sleep management system.

## Features

- **Real-time Status Display** - At-a-glance view of service state, VPN connection, external drive, and torrent apps
- **Service Control** - Enable/disable the sleep management system with one click
- **Feature Toggles** - Toggle individual features (torrents, drive, auto-reconnect, auto-reopen) without editing config files
- **Log Viewing** - View recent activity logs in Terminal
- **Quick Actions** - Reconnect VPN, refresh status, restart service

## Prerequisites

1. **PIA Sleep Handler** must be installed and configured
   ```bash
   cd /path/to/VPN_Shutdown
   sudo ./install.sh
   ```

2. **SwiftBar** must be installed
   ```bash
   brew install swiftbar
   ```

   Or download from: https://github.com/swiftbar/SwiftBar/releases

## Installation

1. **Copy the plugin to SwiftBar's plugins directory:**
   ```bash
   cp pia-sleep-manager.1m.sh ~/Library/Application\ Support/SwiftBar/plugins/
   ```

2. **Make it executable:**
   ```bash
   chmod +x ~/Library/Application\ Support/SwiftBar/plugins/pia-sleep-manager.1m.sh
   ```

3. **Refresh SwiftBar** or restart the app
   - The plugin should appear in your menubar

## Menubar Icons

The icon indicates the current system state:

- 🟢 **Green** - Service running, VPN connected
- 🟡 **Yellow** - Service running, VPN disconnected
- 🔴 **Red** - Service not running

## Menu Structure

### Status Section
Shows current state of:
- Sleepwatcher service (Running/Stopped)
- PIA VPN connection (Connected/Disconnected)
- External drive (if enabled)
- Torrent applications (if enabled)

### Quick Actions
- **Enable/Disable Service** - Start or stop the sleep management system
- **Reconnect VPN Now** - Manually trigger PIA connection
- **Refresh Status** - Force update the menubar display

### Feature Toggles
Click to enable/disable features:
- ✓ **Manage Torrents** - Close/reopen torrent apps during sleep/wake
- ✓ **Manage External Drive** - Eject/mount drive during sleep/wake
- ✓ **Auto Reconnect VPN** - Reconnect PIA after wake if it was connected before sleep
- ✓ **Auto Reopen Apps** - Reopen torrent apps after wake (requires VPN connected)

Changes take effect immediately and are saved to `/usr/local/etc/pia-sleep.conf`

### View Logs
- **Last 10/20/50 Lines** - Opens Terminal with recent log entries
- **Open Full Log** - Opens the complete log file in your default text viewer

### Advanced
- **Edit Configuration** - Opens config file in default editor
- **Restart Service** - Unloads and reloads the LaunchDaemon
- **Run Status Script** - Opens Terminal and runs the full status check script

## Usage

### Toggling Features

Click any feature toggle to enable/disable it. You'll be prompted for your administrator password to modify the configuration file.

**Example**: Click "Manage Torrents" to toggle torrent client management on/off.

### Enabling/Disabling the Service

Use "Disable Service" to temporarily stop sleep management without uninstalling. This stops the sleepwatcher process.

Use "Enable Service" to restart it.

### Viewing Logs

Click "Last 10 Lines" (or 20/50) to see recent activity in a Terminal window. Useful for debugging or verifying that sleep/wake events are being handled correctly.

## Refresh Rate

The plugin updates automatically every **1 minute** (indicated by `1m` in the filename).

You can change the refresh rate by renaming the file:
- `pia-sleep-manager.30s.sh` - Every 30 seconds
- `pia-sleep-manager.5m.sh` - Every 5 minutes
- `pia-sleep-manager.1h.sh` - Every hour

After renaming, refresh SwiftBar for the change to take effect.

## Troubleshooting

### Plugin doesn't appear in menubar

1. Check that SwiftBar is running
2. Verify the plugin is in the correct directory:
   ```bash
   ls -la ~/Library/Application\ Support/SwiftBar/plugins/
   ```
3. Check that it's executable:
   ```bash
   chmod +x ~/Library/Application\ Support/SwiftBar/plugins/pia-sleep-manager.1m.sh
   ```
4. Check SwiftBar's Console for errors (SwiftBar menu → Preferences → Console)

### Status not updating

1. Use "Refresh Status" from the menu
2. Restart SwiftBar
3. Check the refresh rate (1m = 1 minute between updates)

### Sudo password prompts

Some actions require administrator privileges:
- Enabling/disabling the service
- Toggling configuration settings
- Restarting the service

This is by design for security. The config file is owned by root and requires sudo to modify.

### Toggle doesn't work

1. Verify the helper script is installed:
   ```bash
   ls -la /usr/local/bin/pia-config-helper.sh
   ```
2. If missing, reinstall:
   ```bash
   cd /path/to/VPN_Shutdown
   sudo ./install.sh
   ```
   or
   ```bash
   sudo ./update.sh
   ```

### VPN state shows "Error"

This means `piactl` is available but the PIA daemon isn't responding. Try:
1. Open Private Internet Access app
2. Wait a few seconds for daemon to start
3. Refresh the plugin

## Uninstalling

To remove the menubar plugin:

```bash
rm ~/Library/Application\ Support/SwiftBar/plugins/pia-sleep-manager.1m.sh
```

Refresh SwiftBar and the icon will disappear.

**Note**: This only removes the menubar plugin. The core sleep management system remains installed and functional.

## Development

### Testing Plugin Changes

After editing the plugin:

1. Copy to SwiftBar plugins directory (or use a symlink for live editing)
2. Refresh SwiftBar (Cmd+R or menu → Refresh All)
3. Check the SwiftBar console for errors

### Plugin Output Format

SwiftBar plugins use a simple text-based format:
- First line = menubar display
- `---` = separator
- Lines starting with `--` = submenu items
- Special parameters: `bash=`, `terminal=`, `refresh=`, `color=`

See the SwiftBar documentation for details: https://github.com/swiftbar/SwiftBar

## Support

For issues with:
- **Plugin functionality** - Check this README and SwiftBar console
- **Sleep/wake behavior** - Check `/var/log/pia-sleep.log`
- **Core system** - See main project README.md

## License

Same as the main VPN Shutdown project.
