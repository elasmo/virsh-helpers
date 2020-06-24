#!/bin/sh
#
# Share filesystem between guests
#
set -e

SCRIPT_NAME=$(basename $0)

error () {
    echo "$@" 1>&2
    exit 1
}

usage () {
    echo "Usage: $SCRIPT_NAME <source> <dest>" 1>&2
    exit 1
}

[ $# -ne 2 ] && usage

# Check dependencies
for dep in virsh xmllint; do
    if ! type $dep >/dev/null; then
        error "$dep: Not found"
    fi
done

echo "dummy"
