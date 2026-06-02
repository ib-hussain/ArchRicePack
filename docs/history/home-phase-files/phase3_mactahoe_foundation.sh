#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase3-mactahoe-foundation-${STAMP}.log"
SRC_ROOT="$HOME/rice-src"
THEME_REPO="$SRC_ROOT/MacTahoe-gtk-theme"
BACKUP_ROOT="$HOME/rice-reset-backups/phase3-${STAMP}"

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

trap 'fail "Phase 3 failed at line ${LINENO}. Check log: ${LOG}"' ERR

if [[ "$(id -un)" != "ibrahim" ]]; then
    fail "Run this as ibrahim, not root."
fi

if [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]]; then
    warn "Current session is not Wayland. Current XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-missing}"
fi

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
    fail "DBus/session environment is missing. Log out and log back into GNOME, then rerun."
fi

log "Starting PHASE 3 - MacTahoe theme foundation."
log "This phase preserves existing icons, fonts, terminal profile, and wallpaper rotation."

log "Session check."
echo "USER=$USER" | tee -a "$LOG"
echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}" | tee -a "$LOG"
echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-}" | tee -a "$LOG"
echo "DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-}" | tee -a "$LOG"
gnome-shell --version | tee -a "$LOG"

log "Checking user services."
systemctl --user is-active pipewire pipewire-pulse wireplumber | tee -a "$LOG" || warn "One or more PipeWire services are not active."

log "Creating Phase 3 backup."
mkdir -p "$BACKUP_ROOT"

for path in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.themes" "$HOME/.local/share/themes" "$HOME/.config/gnome-shell"; do
    if [[ -e "$path" || -L "$path" ]]; then
        log "Backing up $path"
        mkdir -p "$BACKUP_ROOT$(dirname "$path")"
        cp -a "$path" "$BACKUP_ROOT$path"
    else
        log "Backup skip, missing: $path"
    fi
done

log "Saving current GNOME interface settings."
{
    echo "gtk-theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || true)"
    echo "icon-theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || true)"
    echo "cursor-theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || true)"
    echo "font-name=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || true)"
    echo "monospace-font-name=$(gsettings get org.gnome.desktop.interface monospace-font-name 2>/dev/null || true)"
    echo "color-scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)"
    echo "button-layout=$(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null || true)"
} | tee "$BACKUP_ROOT/gnome-interface-before-phase3.txt" | tee -a "$LOG"

log "Installing required build/support packages if missing."
sudo pacman -S --needed --noconfirm git sassc glib2 libxml2 imagemagick dialog gnome-shell-extensions gnome-tweaks dconf-editor

log "Preparing source directory."
mkdir -p "$SRC_ROOT"

if [[ -d "$THEME_REPO/.git" ]]; then
    log "MacTahoe repo already exists. Updating cleanly."
    git -C "$THEME_REPO" fetch --depth=1 origin
    git -C "$THEME_REPO" reset --hard origin/main
else
    log "Cloning MacTahoe GTK theme repository."
    rm -rf "$THEME_REPO"
    git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git "$THEME_REPO"
fi

log "Removing only old user-level MacTahoe theme copies before reinstall."
rm -rf "$HOME/.themes"/MacTahoe* "$HOME/.local/share/themes"/MacTahoe*

log "Installing MacTahoe Dark Blue transparent/blur-capable theme with Arch shell activity icon."
(
    cd "$THEME_REPO"
    ./install.sh -c dark -o normal -t blue -s standard -b -l --shell -i arch -p 45
)

log "Enabling User Themes extension if present."
USER_THEME_UUID="$(gnome-extensions list | grep -E '^user-theme@' | head -n 1 || true)"

if [[ -n "$USER_THEME_UUID" ]]; then
    log "Enabling extension: $USER_THEME_UUID"
    gnome-extensions enable "$USER_THEME_UUID" || warn "Could not enable User Themes immediately. A logout/login may be needed."
else
    warn "User Themes extension UUID not found in gnome-extensions list."
fi

log "Applying MacTahoe theme settings without changing icon theme or fonts."
gsettings set org.gnome.desktop.interface gtk-theme 'MacTahoe-Dark-blue'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'

if gsettings writable org.gnome.shell.extensions.user-theme name >/dev/null 2>&1; then
    gsettings set org.gnome.shell.extensions.user-theme name 'MacTahoe-Dark-blue' || warn "Could not set GNOME Shell user theme."
else
    warn "User-theme gsettings key not writable yet. Logout/login may be needed, then we can set it again."
fi

log "Verification."
echo "GTK theme: $(gsettings get org.gnome.desktop.interface gtk-theme)" | tee -a "$LOG"
echo "Shell theme: $(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Icon theme preserved as: $(gsettings get org.gnome.desktop.interface icon-theme)" | tee -a "$LOG"
echo "Font preserved as: $(gsettings get org.gnome.desktop.interface font-name)" | tee -a "$LOG"
echo "Monospace font preserved as: $(gsettings get org.gnome.desktop.interface monospace-font-name)" | tee -a "$LOG"
echo "Button layout: $(gsettings get org.gnome.desktop.wm.preferences button-layout)" | tee -a "$LOG"
echo "Installed MacTahoe theme dirs:" | tee -a "$LOG"
find "$HOME/.themes" "$HOME/.local/share/themes" -maxdepth 1 -type d -name 'MacTahoe*' 2>/dev/null | sort | tee -a "$LOG"

log "PHASE 3 complete."
log "Log saved at: $LOG"
log "If shell theme does not visually apply immediately, log out and log back in once."
