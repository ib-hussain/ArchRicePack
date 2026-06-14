#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase10-fetch-topbar-dock-final-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase10-${STAMP}"

BASHRC="$HOME/.bashrc"
BASH_PROFILE="$HOME/.bash_profile"
PROFILE="$HOME/.profile"
FF_BLUE="$HOME/.local/bin/ff-blue"

HIDE_TOP_BAR_PK="545"
HIDE_TOP_BAR_UUID="hidetopbar@mathieu.bidon.ca"
HIDE_TOP_BAR_ZIP="$BACKUP_DIR/hide-top-bar.zip"

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

backup_file() {
    local file="$1"
    if [[ -e "$file" || -L "$file" ]]; then
        mkdir -p "$BACKUP_DIR/home"
        cp "$file" "$BACKUP_DIR/home/$(basename "$file").before"
        log "Backed up: $file"
    else
        log "Backup skip, missing: $file"
    fi
}

clean_fetch_from_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    log "Cleaning fetch startup noise from $file"

    python - "$file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
lines = path.read_text(errors="ignore").splitlines()

remove_blocks = [
    ("# >>> phase8-rice-terminal-toolkit >>>", "# <<< phase8-rice-terminal-toolkit <<<"),
    ("# >>> phase9-rice-terminal-final >>>", "# <<< phase9-rice-terminal-final <<<"),
    ("# >>> phase10-rice-terminal-final >>>", "# <<< phase10-rice-terminal-final <<<"),
]

out = []
skip = False
end_marker = None

for line in lines:
    stripped = line.strip()

    if not skip:
        started = False
        for start, end in remove_blocks:
            if stripped == start:
                skip = True
                end_marker = end
                started = True
                break
        if started:
            continue
    else:
        if stripped == end_marker:
            skip = False
            end_marker = None
        continue

    # Remove the common two/three-line autostart blocks:
    # if [[ $- == *i* ]] && command -v neofetch ...
    #     neofetch
    # fi
    if "neofetch" in stripped or "fastfetch" in stripped:
        # Keep comments out too; we are making this file deterministic.
        continue

    out.append(line)

path.write_text("\n".join(out).rstrip() + "\n")
PY
}

trap 'fail "Phase 10 failed at line ${LINENO}. Check log: ${LOG}"' ERR

if [[ "$(id -un)" != "ibrahim" ]]; then
    fail "Run this as ibrahim, not root."
fi

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
    fail "DBus/session environment missing. Log out and back into GNOME, then rerun."
fi

mkdir -p "$BACKUP_DIR"

log "Starting PHASE 10 - fetch cleanup, top bar removal, dock finalisation."
log "This phase preserves Files transparency, GTK opacity, Shell opacity, wallpaper rotation, fonts, icon theme, and power modes."

log "Backing up shell files and GNOME settings."
backup_file "$BASHRC"
backup_file "$BASH_PROFILE"
backup_file "$PROFILE"
dconf dump /org/gnome/shell/ > "$BACKUP_DIR/gnome-shell-before-phase10.ini" 2>/dev/null || true
dconf dump /org/gnome/shell/extensions/dash-to-dock/ > "$BACKUP_DIR/dash-to-dock-before-phase10.ini" 2>/dev/null || true

log "Cleaning old Neofetch/Fastfetch startup lines from shell startup files."
touch "$BASHRC"
clean_fetch_from_file "$BASHRC"
clean_fetch_from_file "$BASH_PROFILE"
clean_fetch_from_file "$PROFILE"

log "Removing Neofetch package if installed."
if command -v neofetch >/dev/null 2>&1; then
    NEOFETCH_BIN="$(command -v neofetch)"
    if pacman -Qo "$NEOFETCH_BIN" >/dev/null 2>&1; then
        NEOFETCH_PKG="$(pacman -Qo "$NEOFETCH_BIN" | awk '{print $5}')"
        log "Removing package owning neofetch: $NEOFETCH_PKG"
        sudo pacman -Rns --noconfirm "$NEOFETCH_PKG" || warn "Could not remove $NEOFETCH_PKG; startup has still been cleaned."
    else
        warn "Neofetch exists but is not owned by pacman: $NEOFETCH_BIN"
    fi
else
    log "Neofetch command already absent."
fi

hash -r || true

log "Creating final blue Arch Fastfetch wrapper."
mkdir -p "$HOME/.local/bin"

cat > "$FF_BLUE" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/fastfetch --logo arch --logo-color-1 blue --logo-color-2 blue --logo-color-3 blue "$@"
EOF

chmod +x "$FF_BLUE"

log "Adding exactly one final interactive terminal block."
cat >> "$BASHRC" <<'EOF'

# >>> phase10-rice-terminal-final >>>
# Final interactive terminal banner/tooling for this Arch GNOME rice.
case $- in
    *i*) ;;
    *) return ;;
esac

export PATH="$HOME/.local/bin:$PATH"

alias fastfetch='ff-blue'
alias ff='ff-blue'

if [[ -z "${RICE_FASTFETCH_SHOWN:-}" && ! -f "$HOME/.no_fastfetch" ]]; then
    export RICE_FASTFETCH_SHOWN=1
    ff-blue
fi

if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -lah --icons=auto --group-directories-first --git'
    alias la='eza -a --icons=auto --group-directories-first'
    alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never --style=plain'
    alias preview='bat --paging=always'
fi

if command -v btop >/dev/null 2>&1; then
    alias top='btop'
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

alias cls='clear'
alias please='sudo'
alias ports='ss -tulpen'
alias myip='ip -brief addr'
# <<< phase10-rice-terminal-final <<<
EOF

log "Checking shell syntax."
bash -n "$BASHRC"
[[ -f "$BASH_PROFILE" ]] && bash -n "$BASH_PROFILE" || true
[[ -f "$PROFILE" ]] && bash -n "$PROFILE" || true

log "Installing Hide Top Bar extension for GNOME Shell 50."
sudo pacman -S --needed --noconfirm curl unzip python

python - "$HIDE_TOP_BAR_PK" "$HIDE_TOP_BAR_ZIP" <<'PY'
import json
import sys
import urllib.request
from pathlib import Path

pk = sys.argv[1]
zip_path = Path(sys.argv[2])
shell_major = "50"

with urllib.request.urlopen(f"https://extensions.gnome.org/extension-info/?pk={pk}", timeout=30) as r:
    data = json.loads(r.read().decode("utf-8"))

uuid = data["uuid"]
version_map = data.get("shell_version_map", {})
version = None

if shell_major in version_map:
    version = version_map[shell_major]["version"]
else:
    best = []
    for shell, meta in version_map.items():
        try:
            if str(shell_major) in str(shell):
                best.append(int(meta["version"]))
        except Exception:
            pass
    if best:
        version = max(best)

if version is None:
    # Known current GNOME Shell 50 compatible Hide Top Bar release.
    version = 124

download_uuid = uuid.replace("@", "")
url = f"https://extensions.gnome.org/extension-data/{download_uuid}.v{version}.shell-extension.zip"

print(uuid)
print(version)
print(url)

urllib.request.urlretrieve(url, zip_path)
PY

gnome-extensions install --force "$HIDE_TOP_BAR_ZIP" || warn "Hide Top Bar install returned non-zero; it may already be installed."

log "Finding Hide Top Bar UUID."
if gnome-extensions list | grep -qx "$HIDE_TOP_BAR_UUID"; then
    log "Hide Top Bar found: $HIDE_TOP_BAR_UUID"
else
    FOUND_UUID="$(gnome-extensions list | grep -Ei 'hide.*top|top.*bar|hidetopbar' | head -n 1 || true)"
    if [[ -n "$FOUND_UUID" ]]; then
        HIDE_TOP_BAR_UUID="$FOUND_UUID"
        log "Hide Top Bar detected as: $HIDE_TOP_BAR_UUID"
    else
        warn "Hide Top Bar UUID not visible yet. Log out/in after this phase. The extension may appear after session reload."
    fi
fi

if gnome-extensions list | grep -qx "$HIDE_TOP_BAR_UUID"; then
    gnome-extensions enable "$HIDE_TOP_BAR_UUID" || warn "Could not enable Hide Top Bar immediately; logout/login may be required."
fi

log "Applying Hide Top Bar settings where schemas are visible."
if gsettings list-schemas | grep -qx "org.gnome.shell.extensions.hidetopbar"; then
    gsettings set org.gnome.shell.extensions.hidetopbar enable-intellihide false || true
    gsettings set org.gnome.shell.extensions.hidetopbar mouse-sensitive false || true
    gsettings set org.gnome.shell.extensions.hidetopbar pressure-threshold 1000 || true
    gsettings set org.gnome.shell.extensions.hidetopbar animation-time 0.18 || true
else
    warn "Hide Top Bar settings schema not visible yet; this usually resolves after logout/login."
fi

log "Finalising dock layout and favourites."
DASH_UUID="dash-to-dock@micxgx.gmail.com"
gnome-extensions enable "$DASH_UUID" || true

dconf write /org/gnome/shell/extensions/dash-to-dock/dock-position "'BOTTOM'"
dconf write /org/gnome/shell/extensions/dash-to-dock/extend-height false
dconf write /org/gnome/shell/extensions/dash-to-dock/dock-fixed true
dconf write /org/gnome/shell/extensions/dash-to-dock/intellihide false
dconf write /org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size 52
dconf write /org/gnome/shell/extensions/dash-to-dock/show-show-apps-button true
dconf write /org/gnome/shell/extensions/dash-to-dock/show-trash true
dconf write /org/gnome/shell/extensions/dash-to-dock/click-action "'minimize-or-previews'"
dconf write /org/gnome/shell/extensions/dash-to-dock/scroll-action "'cycle-windows'"
dconf write /org/gnome/shell/extensions/dash-to-dock/running-indicator-style "'DOTS'"
dconf write /org/gnome/shell/extensions/dash-to-dock/custom-theme-shrink true || true
dconf write /org/gnome/shell/extensions/dash-to-dock/force-straight-corner false || true

log "Setting clean dock favourites based on installed desktop files."
python - <<'PY'
from pathlib import Path
import subprocess

candidates = [
    ["org.gnome.Nautilus.desktop", "nautilus.desktop"],
    ["org.gnome.Terminal.desktop", "gnome-terminal.desktop"],
    ["firefox.desktop"],
    ["code.desktop", "visual-studio-code.desktop", "com.visualstudio.code.desktop"],
    ["org.gnome.Settings.desktop", "gnome-control-center.desktop"],
    ["org.gnome.Extensions.desktop", "com.mattjakeman.ExtensionManager.desktop"],
]

app_dirs = [Path.home()/".local/share/applications", Path("/usr/share/applications")]
chosen = []

for group in candidates:
    for desktop in group:
        if any((d / desktop).exists() for d in app_dirs):
            chosen.append(desktop)
            break

value = "[" + ", ".join("'" + x + "'" for x in chosen) + "]"
subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", value], check=True)
print(value)
PY

log "Reconfirming preserved settings."
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.gnome.shell.keybindings toggle-overview "['<Super>Tab']"

log "Verification."
echo "Neofetch command:" | tee -a "$LOG"
if command -v neofetch >/dev/null 2>&1; then
    command -v neofetch | tee -a "$LOG"
else
    echo "removed" | tee -a "$LOG"
fi

echo "Fetch startup references still present:" | tee -a "$LOG"
grep -nE 'neofetch|^[[:space:]]*fastfetch\b|alias[[:space:]]+neofetch' "$BASHRC" "$BASH_PROFILE" "$PROFILE" 2>/dev/null | tee -a "$LOG" || true

echo "Fastfetch wrapper test:" | tee -a "$LOG"
"$FF_BLUE" --version | tee -a "$LOG"

echo "Enabled extensions:" | tee -a "$LOG"
gnome-extensions list --enabled | grep -Ei 'user-theme|dash.*dock|hide.*top|top.*bar|hidetopbar' | tee -a "$LOG" || true

echo "Dock favourites:" | tee -a "$LOG"
gsettings get org.gnome.shell favorite-apps | tee -a "$LOG"

echo "Dash to Dock settings:" | tee -a "$LOG"
dconf dump /org/gnome/shell/extensions/dash-to-dock/ | tee -a "$LOG" || true

echo "GNOME/rice state preserved:" | tee -a "$LOG"
echo "GTK: $(gsettings get org.gnome.desktop.interface gtk-theme)" | tee -a "$LOG"
echo "Shell: $(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Icons: $(gsettings get org.gnome.desktop.interface icon-theme)" | tee -a "$LOG"
echo "Buttons: $(gsettings get org.gnome.desktop.wm.preferences button-layout)" | tee -a "$LOG"
echo "Super+Tab: $(gsettings get org.gnome.shell.keybindings toggle-overview)" | tee -a "$LOG"
echo "Power profile: $(powerprofilesctl get 2>/dev/null || echo unavailable)" | tee -a "$LOG"

log "PHASE 10 complete."
log "Now log out and log back in once. If the top bar is still visible after login, reboot once."
log "After login, open Terminal: only one blue Arch Fastfetch should appear."
log "Log saved at: $LOG"
