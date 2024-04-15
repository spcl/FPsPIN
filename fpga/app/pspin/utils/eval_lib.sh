#!/usr/bin/env bash

do_netns="sudo ip netns exec"

fatal() {
    echo "$@" >&2
    exit 1
}

kill_payload() {
    sudo killall -9 $FPSPIN_PAYLOAD &>/dev/null || true

    sleep 0.5
}

scan_till_online() {
    while true; do
        sudo bash -c 'echo 1 > /sys/bus/pci/rescan'
        if [[ -L /sys/bus/pci/devices/0000:$FPSPIN_PCIE_PATH ]]; then
            echo Device back online!
            break
        else
            echo -n R
            sleep 5
        fi
    done
}

reset_device() {
    kill_payload

    scan_till_online

    sudo $FPSPIN_UTILS/mqnic-fw -d $FPSPIN_PCIE_PATH -b -y

    scan_till_online

    sudo $FPSPIN_UTILS/setup-netns.sh off || true
    sudo $FPSPIN_UTILS/setup-netns.sh on
}

capture_stdout() {
    # start stdout capture
    sudo $FPSPIN_UTILS/cat_stdout.py --dump-files --clean &>/dev/null &
    CAT_STDOUT_PID=$!
}

kill_stdout() {
    sudo kill $CAT_STDOUT_PID
}
