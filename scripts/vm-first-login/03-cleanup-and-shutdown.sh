#!/bin/sh

set -eu

B_SYSTEM_PACKAGES_DIRECTORY="$(finddir B_SYSTEM_PACKAGES_DIRECTORY)"
B_SYSTEM_SETTINGS_DIRECTORY="$(finddir B_SYSTEM_SETTINGS_DIRECTORY)"
B_SYSTEM_TEMP_DIRECTORY="$(finddir B_SYSTEM_TEMP_DIRECTORY)"
B_USER_SETTINGS_DIRECTORY="$(finddir B_USER_SETTINGS_DIRECTORY)"

# Remove SSH host keys
rm -f "${B_SYSTEM_SETTINGS_DIRECTORY:?}"/ssh/ssh_host_*_key*

# Remove previous states and transactions
rm -rf "${B_SYSTEM_PACKAGES_DIRECTORY:?}"/administrative/state_*/
rm -rf "${B_SYSTEM_PACKAGES_DIRECTORY:?}"/administrative/transaction-*/

# Remove installer packages and sources
rm -rf /boot/_packages_/ /boot/_sources_/

# Remove temporary files
find "${B_SYSTEM_TEMP_DIRECTORY:?}" -mindepth 1 -delete

# Recreate magic file so "package_daemon" processes the first boot of all packages
touch "${B_SYSTEM_PACKAGES_DIRECTORY:?}"/administrative/FirstBootProcessingNeeded

# Fill unused space with zeros
cat /dev/zero > /zero ||:; sync; rm -f /zero

# Shutdown system when "first_login" file is removed
nohup sh -eu >/dev/null 2>&1 <<-EOF &
	while [ -e "${B_USER_SETTINGS_DIRECTORY:?}"/first_login ]; do sleep 1; done
	exec shutdown
EOF
