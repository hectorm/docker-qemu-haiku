#!/bin/sh

set -eu

# Wait until the Haiku repository is reachable (the network may not be ready yet)
until nc -z eu.hpkg.haiku-os.org 80; do sleep 5; done

# Synchronize the installed packages with the Haiku repository
until pkgman full-sync -y; do sleep 30; done
