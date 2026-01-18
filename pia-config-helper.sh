#!/bin/bash

# PIA Configuration Helper Script
# Safely modifies /usr/local/etc/pia-sleep.conf settings
# Called by SwiftBar plugin via osascript with administrator privileges

CONFIG_FILE="/usr/local/etc/pia-sleep.conf"

# Valid settings that can be modified
VALID_SETTINGS=("MANAGE_TORRENTS" "MANAGE_EXTERNAL_DRIVE" "AUTO_RECONNECT" "AUTO_REOPEN_APPS")

# Validate arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <setting_name> <value>"
    echo "Valid settings: ${VALID_SETTINGS[*]}"
    echo "Valid values: true, false"
    exit 1
fi

SETTING_NAME="$1"
NEW_VALUE="$2"

# Validate setting name
is_valid_setting=false
for valid_setting in "${VALID_SETTINGS[@]}"; do
    if [ "$SETTING_NAME" = "$valid_setting" ]; then
        is_valid_setting=true
        break
    fi
done

if [ "$is_valid_setting" = false ]; then
    echo "Error: Invalid setting name '$SETTING_NAME'"
    echo "Valid settings: ${VALID_SETTINGS[*]}"
    exit 1
fi

# Validate value
if [ "$NEW_VALUE" != "true" ] && [ "$NEW_VALUE" != "false" ]; then
    echo "Error: Value must be 'true' or 'false', got '$NEW_VALUE'"
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Backup config file
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Update the configuration file
# Use sed to find and replace the setting
if sed -i '' "s/^${SETTING_NAME}=.*/${SETTING_NAME}=\"${NEW_VALUE}\"/" "$CONFIG_FILE"; then
    echo "Successfully updated ${SETTING_NAME} to ${NEW_VALUE}"
    rm "${CONFIG_FILE}.bak"
    exit 0
else
    echo "Error: Failed to update configuration file"
    # Restore backup on failure
    mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
    exit 1
fi
