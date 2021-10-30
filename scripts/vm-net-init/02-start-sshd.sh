#!/bin/sh

set -eu

if ! nc -z 127.0.0.1 22; then
	# Wait until the sshd configuration is valid
	# (usually until the SSH host keys are generated)
	timeout 600 sh -c 'until /bin/sshd -tq; do sleep 5; done'
	nohup /bin/sshd -D >/dev/null 2>&1 &
fi
