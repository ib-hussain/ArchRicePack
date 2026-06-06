#!/usr/bin/env bash

sudo cpupower frequency-set -g performance

for f in /sys/devices/system/cpu/cpu*/power/energy_perf_bias; do
    [[ -w "$f" ]] && echo 0 | sudo tee "$f" >/dev/null
done

echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null

echo "Performance enabled."