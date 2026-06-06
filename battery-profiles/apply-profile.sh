#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${1:-}"

if [[ -z "$PROFILE" ]]; then
    echo "Usage:"
    echo "  apply-profile.sh powersaver"
    echo "  apply-profile.sh balanced"
    echo "  apply-profile.sh performance"
    echo "  apply-profile.sh maximum"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

reset_all() {

    sudo cpupower frequency-set -g powersave >/dev/null 2>&1 || true

    for f in /sys/devices/system/cpu/cpu*/power/energy_perf_bias; do
        [[ -w "$f" ]] && echo 6 | sudo tee "$f" >/dev/null
    done

    echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1 || true
    echo always | sudo tee /sys/kernel/mm/transparent_hugepage/defrag >/dev/null 2>&1 || true

    for f in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
        [[ -w "$f" ]] && echo 0 | sudo tee "$f" >/dev/null
    done
}

reset_all

case "$PROFILE" in
    powersaver)
        source "$SCRIPT_DIR/profile-powersaver.sh"
        ;;
    balanced)
        source "$SCRIPT_DIR/profile-balanced.sh"
        ;;
    performance)
        source "$SCRIPT_DIR/profile-performance.sh"
        ;;
    maximum)
        source "$SCRIPT_DIR/profile-maximum.sh"
        ;;
    *)
        echo "Unknown profile."
        exit 1
        ;;
esac

echo "$PROFILE" | sudo tee /etc/ib-power-profile >/dev/null

echo
echo "Current profile: $PROFILE"