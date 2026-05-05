#!/bin/bash

IFACE="$1"
FLAG="$2"

# checks if interface exists if exists then it returns 1
check_iface() {

    if [[ -d "/sys/class/net/$IFACE" ]]; then
        return 0
    fi
    return 1
}

check_is_tap() {
    local flag

    if check_iface && [[ -e "/sys/class/net/$IFACE/tun_flags" ]]; then
        flag=$(< "/sys/class/net/$IFACE/tun_flags")
    fi

    if check_iface && (( $flag & 0x0002 )); then
        return 0
    fi
    return 1
}

# checks for interface and creates the interface
create_iface() {

    if  ! check_iface ; then           # if check_iface returns 1 then creates an interface         damm bash....
        echo "Creating $IFACE interface "
        sudo ip tuntap add "$IFACE" mode tap
        ip -br link | grep "$IFACE"
        return
    else
        echo "Interface $IFACE already exists"
        return
    fi
}

delete_iface() {

    if  check_iface && check_is_tap ; then             # if check_iface returns 0 then it delets interface
        echo "deleting interface $IFACE"
        sudo ip link delete "$IFACE"
        ip -br link
        return
    fi
    echo "Unable to delete interface $1 doesn't exits"
    return
}

if [[ $# -lt 1 ]]; then
    echo "Usage $0 -h"
    exit 2
fi

if [[ "$1" == "-h" ]]; then
    echo "$0 <interfacename> <create|delete|up>"
    exit 2
fi

if [[ "$FLAG" == "create" ]]; then
    create_iface
    exit 0
    

elif [[ "$FLAG" == "delete" ]]; then
    delete_iface
    exit 0

elif [[ "$FLAG" == "up" ]]; then
    if  check_iface "$IFACE" ; then
        sudo ip link set "$IFACE" up
        sleep 1
        ip -brief link | grep "$IFACE"
        exit 0
    fi
else
    echo "Unknown argument"
fi

