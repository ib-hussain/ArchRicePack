#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase11-clock-topbar-dock-cleanup-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase11-${STAMP}"

CLOCK_CONF="$HOME/.config/conky/rice-clock.conf"
CLOCK_DESKTOP="$HOME/.config/autostart/rice-desktop-clock.desktop"

HIDE_TOP_BAR_PK="545"
HIDE_TOP_BAR_UUID="hidetopbar@mathieu.bidon.ca"

JUST_PERFECTION_PK="3843"
JUST_PERFECTION_UUID="just-perfection-desktop@just-perfection"

log() {
    echo "[INFO] $*" | tee -a "$LOG"
}

warn() {
    echo "[WARN] $*" | tee -a "$LOG"
}

fail() {
    echo "[ERROR] $*" | tee -a "$LOG"
    exit 1
}

trap 'fail "Phase 11 failed at line ${LINENO}. Check log: ${LOG}"' ERR

download_extension_zip() {
    local pk="$1"
    local out_zip="$2"

    python - "$pk" "$out_zip" <<'PY'
import json
import sys
import urllib.request
from pathlib import Path

pk = sys.argv[1]
out_zip = Path(sys.argv[2])

shell_major = "50"
info_url = f"https://extensions.gnome.org/extension-info/?pk={pk}"

with urllib.request.urlopen(info_url, timeout=45) as response:
    data = json.loads(response.read().decode("utf-8"))

uuid = data["uuid"]
version_map = data.get("shell_version_map", {})
version = None

if shell_major in version_map:
    version = int(version_map[shell_major]["version"])
else:
    versions = []
    for _shell, meta in version_map.items():
        try:
            versions.append(int(meta["version"]))
        except Exception:
            pass
    if versions:
        version = max(versions)

if version is None:
    raise SystemExit(f"No extension version found for pk={pk}")

filename = f"{uuid.replace('@', '')}.v{version}.shell-extension.zip"
url = f"https://extensions.gnome.org/extension-data/{filename}"

print(uuid)
print(version)
print(url)

urllib.request.urlretrieve(url, out_zip)
PY
}

manual_install_extension_zip() {
    local zip_file="$1"
    local uuid="$2"
    local dest="$HOME/.local/share/gnome-shell/extensions/$uuid"

    rm -rf "$dest"
    mkdir -p "$dest"
    unzip -q "$zip_file" -d "$dest"

    if [[ -d "$dest/schemas" ]]; then
        glib-compile-schemas "$dest/schemas" || true
    fi
}


echo "Dash to Dock settings:" | tee -a "$LOG"
dconf dump /org/gnome/shell/extensions/dash-to-dock/ | tee -a "$LOG" || true
if command -v neofetch >/dev/null 2>&1; then
    echo "neofetch still present: $(command -v neofetch)" | tee -a "$LOG"
else
    echo "neofetch removed" | tee -a "$LOG"
fi
command -v ff-blue | tee -a "$LOG"

echo "GNOME/rice state preserved:" | tee -a "$LOG"
echo "GTK: $(gsettings get org.gnome.desktop.interface gtk-theme)" | tee -a "$LOG"
echo "Shell: $(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Icons: $(gsettings get org.gnome.desktop.interface icon-theme)" | tee -a "$LOG"
echo "Buttons: $(gsettings get org.gnome.desktop.wm.preferences button-layout)" | tee -a "$LOG"
echo "Super+Tab: $(gsettings get org.gnome.shell.keybindings toggle-overview)" | tee -a "$LOG"
echo "Power profile: $(powerprofilesctl get 2>/dev/null || echo unavailable)" | tee -a "$LOG"

log "PHASE 11 complete."
log "Now log out and log back in once. If the top bar is still visible, reboot once."
log "After login, check: desktop clock visible, bottom dock stable, top bar hidden or controlled by Just Perfection."
log "Log saved at: $LOG"
