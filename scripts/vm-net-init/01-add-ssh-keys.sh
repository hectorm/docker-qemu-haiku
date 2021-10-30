#!/bin/sh

set -eu

B_USER_SETTINGS_DIRECTORY="$(finddir B_USER_SETTINGS_DIRECTORY)"

if [ ! -e "${B_USER_SETTINGS_DIRECTORY:?}"/ssh/ ]; then
	mkdir "${B_USER_SETTINGS_DIRECTORY:?}"/ssh/
fi

awk -f- > "${B_USER_SETTINGS_DIRECTORY:?}"/ssh/authorized_keys2 <<-'EOF'
	BEGIN {
		for (v in ENVIRON) {
			if (v ~ /^VM_SSH_KEY/) {
				print(ENVIRON[v]);
			}
		}
	}
EOF
