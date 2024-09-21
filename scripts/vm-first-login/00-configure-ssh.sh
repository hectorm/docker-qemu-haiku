#!/bin/sh

set -eu

B_SYSTEM_SETTINGS_DIRECTORY="$(finddir B_SYSTEM_SETTINGS_DIRECTORY)"
B_USER_SETTINGS_DIRECTORY="$(finddir B_USER_SETTINGS_DIRECTORY)"

cat > "${B_SYSTEM_SETTINGS_DIRECTORY:?}"/ssh/sshd_config <<-EOF
	Port                   22
	AddressFamily          any
	ListenAddress          0.0.0.0
	ListenAddress          ::
	HostKey                ${B_SYSTEM_SETTINGS_DIRECTORY:?}/ssh/ssh_host_rsa_key
	HostKey                ${B_SYSTEM_SETTINGS_DIRECTORY:?}/ssh/ssh_host_ed25519_key
	PermitRootLogin        without-password
	PermitEmptyPasswords   no
	PubkeyAuthentication   yes
	PasswordAuthentication no
	AllowTcpForwarding     yes
	AuthorizedKeysFile     ${B_USER_SETTINGS_DIRECTORY:?}/ssh/authorized_keys ${B_USER_SETTINGS_DIRECTORY:?}/ssh/authorized_keys2
	Subsystem              sftp internal-sftp
EOF
