#!/usr/bin/env bash

set -eu

PSPIN_IF="eth0"
PSPIN_NS="pspin"
BYPASS_IF="eth1"
BYPASS_NS="bypass"

on() {
    echo "Creating $PSPIN_NS namespace..."
    ip netns add $PSPIN_NS
    ip link set $PSPIN_IF netns $PSPIN_NS
    ip -n $PSPIN_NS addr add 10.0.0.1/24 dev $PSPIN_IF
    ip -n $PSPIN_NS link set $PSPIN_IF up
    ip -n $PSPIN_NS link set lo up

    echo "Creating $BYPASS_NS namespace..."
    ip netns add $BYPASS_NS
    ip link set $BYPASS_IF netns $BYPASS_NS
    ip -n $BYPASS_NS addr add 10.0.0.2/24 dev $BYPASS_IF
    ip -n $BYPASS_NS link set $BYPASS_IF up
    ip -n $BYPASS_NS link set lo up

    echo "Route to PsPIN from $BYPASS_NS:"
    ip -n $BYPASS_NS route get 10.0.0.1

    echo "Route to bypass from $PSPIN_NS:"
    ip -n $PSPIN_NS route get 10.0.0.2

    echo "Pinging pspin from $BYPASS_NS:"
    ip netns exec $BYPASS_NS ping -c 4 10.0.0.1

    echo "Pinging bypass from $PSPIN_NS:"
    ip netns exec $PSPIN_NS ping -c 4 10.0.0.2

    echo Done!
}

off() {
    echo "Destroying netns $PSPIN_NS and $BYPASS_NS..."

    ip netns delete $PSPIN_NS
    ip netns delete $BYPASS_NS

    echo Done!
}

if [[ $# != 1 ]]; then
    echo "usage: $0 <on|off>"
    exit 1
fi

if [[ $1 == "on" ]]; then
    on
elif [[ $1 == "off" ]]; then
    off
else
    echo "unknown action $1"
    exit 1
fi
