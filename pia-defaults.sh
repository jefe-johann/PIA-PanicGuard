#!/bin/bash

# PIA-PanicGuard - Shared Default Configuration Values
# This file is sourced by all scripts for consistent defaults
# Actual values can be overridden by /usr/local/etc/pia-sleep.conf

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-/usr/local/etc/pia-sleep.conf}"

# Logging configuration
LOG_FILE="${LOG_FILE:-/var/log/pia-sleep.log}"
VERBOSE_LOGGING="${VERBOSE_LOGGING:-true}"

# Feature toggles
MANAGE_TORRENTS="${MANAGE_TORRENTS:-true}"
MANAGE_EXTERNAL_DRIVE="${MANAGE_EXTERNAL_DRIVE:-true}"
AUTO_RECONNECT="${AUTO_RECONNECT:-true}"
AUTO_REOPEN_APPS="${AUTO_REOPEN_APPS:-false}"

# External drive configuration
EXTERNAL_DRIVE_NAME="${EXTERNAL_DRIVE_NAME:-Big Dawg}"
DRIVE_EJECTION_ATTEMPTS="${DRIVE_EJECTION_ATTEMPTS:-3}"
DRIVE_EJECTION_WAIT="${DRIVE_EJECTION_WAIT:-5}"

# Torrent application configuration
if [ -z "$TORRENT_APPS" ]; then
    TORRENT_APPS=("Transmission" "qbittorrent" "Nicotine+" "VLC" "BiglyBT")
fi
APP_SHUTDOWN_TIMEOUT="${APP_SHUTDOWN_TIMEOUT:-10}"

# Load configuration file if it exists (overrides defaults above)
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi
