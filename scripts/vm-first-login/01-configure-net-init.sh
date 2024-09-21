#!/bin/sh
# shellcheck disable=SC2317

set -eu

B_USER_BOOT_DIRECTORY="$(finddir B_USER_BOOT_DIRECTORY)"

sed '1,/^# START OF SCRIPT #$/d' -- "$0" > "${B_USER_BOOT_DIRECTORY:?}"/launch/vm-net-init.sh
chmod 755 "${B_USER_BOOT_DIRECTORY:?}"/launch/vm-net-init.sh

exit 0

# START OF SCRIPT #
#!/bin/sh

set -eu

B_SYSTEM_LOG_DIRECTORY="$(finddir B_SYSTEM_LOG_DIRECTORY)"

exec 1>"${B_SYSTEM_LOG_DIRECTORY:?}"/vm_net_init.log
exec 2>&1

TMP_SCRIPTS_DIR="$(mktemp -d)"
# shellcheck disable=SC2154
trap 'ret="$?"; rm -rf -- "${TMP_SCRIPTS_DIR:?}"; trap - EXIT; exit "${ret:?}"' EXIT TERM INT HUP

printf 'Downloading scripts...\n'
wget -T 5 -t 30 --retry-connrefused -rl 1 -np -nd -A sh,pl,py,env -P "${TMP_SCRIPTS_DIR:?}" 'http://10.0.2.2:1337'

_LC_COLLATE="${LC_COLLATE-}"; LC_COLLATE='C'
for f in "${TMP_SCRIPTS_DIR:?}"/*; do
	[ -f "${f:?}" ] || continue
	[ -x "${f:?}" ] || chmod 755 "${f:?}"
	# shellcheck disable=SC1090
	if [ "${f##*.}" = 'env' ]; then
		printf 'Sourcing "%s"...\n' "${f:?}"
		set -a; . "${f:?}"; set +a
	else
		printf 'Executing "%s"...\n' "${f:?}"
		"${f:?}"
	fi
done
LC_COLLATE="${_LC_COLLATE?}"
