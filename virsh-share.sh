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
    echo "Usage: $SCRIPT_NAME [-f source] [-t dest]" 1>&2
    exit 1
}

# Check dependencies
for dep in virsh xmllint; do
    if ! type $dep >/dev/null; then
        error "$dep: Not found"
    fi
done

# Parse arguments
[ $# -lt 1 ] && usage

while getopts f:t:h opt
do      
    case "$opt" in
        f) src_domain="$OPTARG";;
        t) dst_domain="$OPTARG";;
        ?) usage;;
        esac
done

# Share between geust and host
if [ -n "$src_domain" ] && [ -z "$dst_domain" ]; then
    echo 
# Share between guest and guest
elif [ -n "$src_domain" ] && [ -n "$dst_domain" ]; then
    echo
# Share between host and guest
elif [ -z "$src_domain" ] && [ -n "$dst_domain" ]; then
    echo
fi

echo "dummy"
