#!/bin/sh
#
# Create domain snapshot
#
set -e

error () {
    echo "$@" 1>&2
    exit 1
}

usage () {
    echo "Usage: $(basename $0) <domain>" 1>&2
    exit 1
}

[ $# -ne 1 ] && usage

if ! type virsh >/dev/null; then
    error "virsh: Not found"
fi

virsh snapshot-create-as --domain "$1" --name "snapshot-$(date +%s)"
