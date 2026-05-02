#!/bin/bash

BRIDGE="$1"
FLAG="$2"
TAP="$3"

# checks if interface exists if exists then it returns 1
check_iface() {
    local iface="$1"
    
    if [[ -d "/sys/class/net/$iface" ]]; then
        return 0
    fi
    return 1
}

# checking it is a tap interface
check_is_tap() {
    local flag

    if check_iface && [[ -e "/sys/class/net/$TAP/tun_flags" ]]; then
        flag=$(< "/sys/class/net/$TAP/tun_flags")
    fi

    if check_iface && (( $flag & 0x0002 )); then
        return 0
    else
        echo "unknown type"
    fi
    return 1
}

# check interface master which has a symlink to its master's interface directory
check_iface_master() {

    if [[ -L "/sys/class/net/$TAP/master" ]]; then
        return 0
    fi
    return 1
}

# to confirm is it the same master slaved the tap
is_true_master() {
    local is_master
    
    if check_iface_master ; then
        is_master=$(basename "$(readlink -f "/sys/class/net/$TAP/master")")

        if [[ "$is_master" == "$BRIDGE" ]]; then
            echo "True master"
            return 0
        fi
    fi

    return 1
}

    
# checks for interface and creates the interface
create_bridge() {

    if  ! check_iface "$BRIDGE" ; then           # if check_iface returns 1 then creates an interface
        echo "Creating $BRIDGE interface "
        sudo ip link add "$BRIDGE" type bridge
        ip -br link | grep $BRIDGE
        return
    else
        echo "Interface $BRIDGE already exists"
        return
    fi
}

# mastering the tap interface on the cli argument
master_tap() {

    if ! check_iface "$TAP" ; then
        echo "Interface $TAP doesn't exits" 
        exit 1
    fi

    if check_iface "$BRIDGE" ; then
        if is_true_master ; then
            exit 0
        else
            if check_is_tap ; then
                echo "Mastering $TAP to $BRIDGE"
                sudo ip link set $TAP master $BRIDGE
                exit 0
            fi
            exit 1
        fi

    else
        if ! check_iface "$BRIDGE" ; then
            create_bridge
        fi
        master_tap
        exit 0

    fi
}

# deletes interfaces without checking, be causious
delete_bridge() {
    if check_iface ; then
        echo "Deleting $BRIDGE"
        sudo ip link delete $BRIDGE
        ip -br link 
        return
    fi
    echo "unable to delete interface $1"
    return
}

if [[ $# -lt 1 ]]; then
    echo "Usage $0 -h"
    exit 2
fi

if [[ "$1" == "-h" ]]; then
    echo "$0 <Bridge> <create|delete|master|up> <tap>"
    exit 2
fi

if [[ "$FLAG" == "create" ]]; then
    create_bridge
    exit 0
    

elif [[ "$FLAG" == "delete" ]]; then
    delete_bridge
    exit 0

elif [[ "$FLAG" == "up" ]]; then
    if  check_iface "$TAP" check_iface $BRIDGE ; then
        sudo ip link set "$BRIDGE" up
        sleep 1
        ip -brief link | grep "$BRIDGE"
        exit 0
    fi

elif [[ "$FLAG" == "master" ]]; then
    master_tap

else
    echo "unknown argument"
fi
