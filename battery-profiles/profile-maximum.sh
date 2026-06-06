#!/usr/bin/env bash

sudo cpupower frequency-set -g performance

for f in /sys/devices/system/cpu/cpu*/power/energy_perf_bias; do
    [[ -w "$f" ]] && echo 0 | sudo tee "$f" >/dev/null
done

echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1 || true
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag >/dev/null 2>&1 || true

for f in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    [[ -w "$f" ]] && echo 1 | sudo tee "$f" >/dev/null
done

echo "Maximum Performance enabled."