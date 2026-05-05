#!/bin/bash

BRIDGE="$1"
FLAG="$2"
IP="$3"
SUBNET="$4"


add_ip() {
    sudo ip addr add "$IP"/"$SUBNET" dev "$BRIDGE"
    if [[ $? > 0 ]]; then
        return 0
    fi
}

if [[ $# -lt 1 ]]; then
    echo "Usage $0 -h"
    exit 2
fi


if [[ "$1" == "-h" ]]; then
    echo "$0 <Bridge> <add> <ip> <subnet>"
    exit 2
fi


if [[ "$FLAG" == "add" ]]; then
    add_ip
    exit 0
    
else
    echo "unknown argument"
fi

