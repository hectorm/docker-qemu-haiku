#!/bin/sh

set -eu

until nc -z haiku-os.org 80; do sleep 5; done
until pkgman full-sync -y; do sleep 30; done
