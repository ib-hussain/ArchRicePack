#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# phase14_solve_remaining_problems.sh
#
# Final live-system repair before converting this into ArchRicePack.
#
# Fixes:
#   1. Install Google Chrome from AUR.
#   2. Add "Open with Code" to Nautilus right-click/background context menu.
#   3. Keep dock reveal/hide behaviour stable.
#   4. Force the dock Show Applications icon toward an Arch logo.
#   5. Keep the current nice icon pack, but improve it with Papirus/Rice-Papirus.
#   6. Set Super, Super+A, Super+S, Super+Tab, Alt+Tab, Ctrl+Shift+Esc.
#   7. Keep MacTahoe-Dark-blue, Files transparency, right-side buttons, power modes.
#   8. Keep terminal startup clean: one blue Arch Fastfetch only.
###############################################################################

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase14-solve-remaining-problems-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase14-${STAMP}"

USER_NAME="$(id -un)"
DASH_UUID="dash-to-dock@micxgx.gmail.com"
USER_THEME_UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
HIDE_TOP_BAR_UUID="hidetopbar@mathieu.bidon.ca"
START_OVERLAY_PK="5040"

DASH_SCHEMA="org.gnome.shell.extensions.dash-to-dock"
USER_THEME_SCHEMA="org.gnome.shell.extensions.user-theme"
HIDETOPBAR_SCHEMA="org.gnome.shell.extensions.hidetopbar"

LOCAL_ICON_THEME="$HOME/.local/share/icons/Rice-Papirus"
ARCH_ICON_SRC="$BACKUP_DIR/arch-dock-icon.svg"

BASHRC="$HOME/.bashrc"
BASH_PROFILE="$HOME/.bash_profile"
PROFILE="$HOME/.profile"
FF_BLUE="$HOME/.local/bin/ff-blue"

NAUTILUS_EXT_DIR="$HOME/.local/share/nautilus-python/extensions"
NAUTILUS_CODE_EXT="$NAUTILUS_EXT_DIR/open-with-code.py"

TASK_WRAPPER="$HOME/.local/bin/rice-task-manager"

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

on_error() {
    local line="$1"
    fail "Script failed at line ${line}. Check log: ${LOG}"
}

trap 'on_error ${LINENO}' ERR

require_session() {
    if [[ "$EUID" -eq 0 ]]; then
        fail "Run this as ibrahim, not root."
    fi

    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
        fail "GNOME session DBus variables are missing. Log into GNOME normally and rerun from GNOME Terminal."
    fi
}

schema_exists() {
    gsettings list-schemas | grep -qx "$1"
}

schema_key_exists() {
    local schema="$1"
    local key="$2"

    schema_exists "$schema" || return 1
    gsettings list-keys "$schema" 2>/dev/null | grep -qx "$key"
}

gs_set() {
    local schema="$1"
    local key="$2"
    local value="$3"

    if schema_key_exists "$schema" "$key"; then
        if gsettings set "$schema" "$key" "$value" 2>>"$LOG"; then
            log "gsettings set ${schema} ${key} ${value}"
        else
            warn "Could not set ${schema} ${key} ${value}"
        fi
    else
        warn "Missing gsettings key, skipped: ${schema} ${key}"
    fi
}

dconf_write() {
    local path="$1"
    local value="$2"

    if dconf write "$path" "$value" 2>>"$LOG"; then
        log "dconf write ${path} ${value}"
    else
        warn "Could not write dconf key: ${path} ${value}"
    fi
}

backup_path() {
    local src="$1"

    if [[ -e "$src" || -L "$src" ]]; then
        local rel="${src#$HOME/}"
        mkdir -p "$BACKUP_DIR/home/$(dirname "$rel")"
        cp -a "$src" "$BACKUP_DIR/home/$rel"
        log "Backed up: $src"
    else
        log "Backup skip, missing: $src"
    fi
}

detect_command() {
    local cmd
    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf '%s\n' "$cmd"
            return 0
        fi
    done
    return 1
}

clean_fetch_noise() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    log "Cleaning old fetch startup noise from $file"

    python - "$file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text(errors="ignore").splitlines()

blocks = [
    ("# >>> phase8-rice-terminal-toolkit >>>", "# <<< phase8-rice-terminal-toolkit <<<"),
    ("# >>> phase9-rice-terminal-final >>>", "# <<< phase9-rice-terminal-final <<<"),
    ("# >>> phase10-rice-terminal-final >>>", "# <<< phase10-rice-terminal-final <<<"),
    ("# >>> phase12-rice-terminal-final >>>", "# <<< phase12-rice-terminal-final <<<"),
    ("# >>> phase13-rice-terminal-final >>>", "# <<< phase13-rice-terminal-final <<<"),
    ("# >>> phase14-rice-terminal-final >>>", "# <<< phase14-rice-terminal-final <<<"),
]

out = []
skip = False
end_marker = None
i = 0

while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    if skip:
        if stripped == end_marker:
            skip = False
            end_marker = None
        i += 1
        continue

    block_started = False
    for start, end in blocks:
        if stripped == start:
            skip = True
            end_marker = end
            block_started = True
            break

    if block_started:
        i += 1
        continue

    if ("neofetch" in stripped or "fastfetch" in stripped) and stripped.startswith("if "):
        depth = 0
        while i < len(lines):
            s = lines[i].strip()
            if s.startswith("if "):
                depth += 1
            if s == "fi":
                depth -= 1
                i += 1
                if depth <= 0:
                    break
                continue
            i += 1
        continue

    if stripped in {"neofetch", "command neofetch", "fastfetch", "command fastfetch"}:
        i += 1
        continue

    if "alias neofetch" in stripped:
        i += 1
        continue

    out.append(line)
    i += 1

path.write_text("\n".join(out).rstrip() + "\n")
PY
}

fix_terminal_fetch() {
    log "Keeping Terminal startup clean: one blue Arch Fastfetch only."

    mkdir -p "$HOME/.local/bin"

    cat > "$FF_BLUE" <<'EOFF'
#!/usr/bin/env bash
exec /usr/bin/fastfetch --logo arch --logo-color-1 blue --logo-color-2 blue --logo-color-3 blue "$@"
EOFF

    chmod +x "$FF_BLUE"

    touch "$BASHRC"

    for file in "$BASHRC" "$BASH_PROFILE" "$PROFILE"; do
        clean_fetch_noise "$file"
    done

    cat >> "$BASHRC" <<'EOFBASH'

# >>> phase14-rice-terminal-final >>>
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
# <<< phase14-rice-terminal-final <<<
EOFBASH

    bash -n "$BASHRC"
    [[ -f "$BASH_PROFILE" ]] && bash -n "$BASH_PROFILE" || true
    [[ -f "$PROFILE" ]] && bash -n "$PROFILE" || true

    if command -v neofetch >/dev/null 2>&1; then
        local neofetch_bin
        neofetch_bin="$(command -v neofetch)"

        if pacman -Qo "$neofetch_bin" >/dev/null 2>&1; then
            local neofetch_pkg
            neofetch_pkg="$(pacman -Qo "$neofetch_bin" | awk '{print $5}')"
            log "Removing leftover Neofetch package: $neofetch_pkg"
            sudo pacman -Rns --noconfirm "$neofetch_pkg" || warn "Could not remove $neofetch_pkg; shell startup remains clean."
        else
            warn "Neofetch exists but is not pacman-owned: $neofetch_bin"
        fi
    fi

    hash -r || true
}

install_base_packages() {
    log "Installing required pacman packages."

}

install_google_chrome() {
    log "Installing Google Chrome from AUR."

    if pacman -Qq google-chrome >/dev/null 2>&1; then
        log "google-chrome already installed."
        return 0
    fi

    if command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm google-chrome || warn "yay failed to install google-chrome. Trying manual AUR build."
    fi

    if pacman -Qq google-chrome >/dev/null 2>&1; then
        log "google-chrome installed successfully through yay."
        return 0
    fi

    local build_root="$HOME/.cache/rice-aur-builds"
    mkdir -p "$build_root"
    rm -rf "$build_root/google-chrome"
    git clone https://aur.archlinux.org/google-chrome.git "$build_root/google-chrome"
    (
        cd "$build_root/google-chrome"
        makepkg -si --noconfirm
    )

    if pacman -Qq google-chrome >/dev/null 2>&1; then
        log "google-chrome installed successfully through manual makepkg."
    else
        warn "google-chrome still not installed. Check AUR/network output above."
    fi
}

create_arch_svg() {
    mkdir -p "$BACKUP_DIR"

    cat > "$ARCH_ICON_SRC" <<'EOFSVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <path fill="#1793D1" d="M128 18C112.3 56.3 101.9 84.2 83.7 122.4c12.3 13 27.7 24.3 46.9 34.3-20.7-5.3-37.1-13.2-49.9-24.1C60.6 173.9 34.5 226.4 7 274c28.6-16.5 51.9-27.1 74.1-32.2-.9-4.5-1.3-9.2-1.2-14.1.7-31.7 17.1-56.1 36.6-54.4 19.5 1.6 34.8 28.8 34.1 60.5-.1 3.3-.4 6.5-.9 9.7 21.7 5.4 44.8 15.9 72.9 32.3-9.5-17.5-18.3-34-26.8-49.8-15.4-12-33.8-24.2-62.1-38.7 20.5 5.3 36.2 11.5 48.6 18.6C160.9 162.3 145.9 103.9 128 18z"/>
</svg>
EOFSVG
}

install_icon_theme_and_arch_launcher_icon() {
    log "Installing Rice-Papirus icon theme and forcing Arch launcher icon names."

    create_arch_svg

    rm -rf "$LOCAL_ICON_THEME"

    mkdir -p \
        "$LOCAL_ICON_THEME/actions/scalable" \
        "$LOCAL_ICON_THEME/apps/scalable" \
        "$LOCAL_ICON_THEME/categories/scalable" \
        "$LOCAL_ICON_THEME/scalable/actions" \
        "$LOCAL_ICON_THEME/scalable/apps" \
        "$LOCAL_ICON_THEME/scalable/categories" \
        "$LOCAL_ICON_THEME/symbolic/actions" \
        "$LOCAL_ICON_THEME/symbolic/apps" \
        "$LOCAL_ICON_THEME/symbolic/categories"

    cat > "$LOCAL_ICON_THEME/index.theme" <<'EOFTHEME'
[Icon Theme]
Name=Rice-Papirus
Comment=Papirus-Dark with Arch launcher overrides
Inherits=Papirus-Dark,Papirus,Adwaita,hicolor
Directories=actions/scalable,apps/scalable,categories/scalable,scalable/actions,scalable/apps,scalable/categories,symbolic/actions,symbolic/apps,symbolic/categories

[actions/scalable]
Size=48
Type=Scalable
Context=Actions

[apps/scalable]
Size=48
Type=Scalable
Context=Applications

[categories/scalable]
Size=48
Type=Scalable
Context=Categories

[scalable/actions]
Size=48
Type=Scalable
Context=Actions

[scalable/apps]
Size=48
Type=Scalable
Context=Applications

[scalable/categories]
Size=48
Type=Scalable
Context=Categories

[symbolic/actions]
Size=48
Type=Scalable
Context=Actions

[symbolic/apps]
Size=48
Type=Scalable
Context=Applications

[symbolic/categories]
Size=48
Type=Scalable
Context=Categories
EOFTHEME

    local icon_names=(
        "view-app-grid-symbolic.svg"
        "view-app-grid.svg"
        "applications-system-symbolic.svg"
        "applications-system.svg"
        "applications-all-symbolic.svg"
        "applications-all.svg"
        "start-here-symbolic.svg"
        "start-here.svg"
        "archlinux-symbolic.svg"
        "archlinux.svg"
        "distributor-logo-archlinux.svg"
        "distributor-logo.svg"
    )

    local icon dir
    for icon in "${icon_names[@]}"; do
        for dir in \
            "$LOCAL_ICON_THEME/actions/scalable" \
            "$LOCAL_ICON_THEME/apps/scalable" \
            "$LOCAL_ICON_THEME/categories/scalable" \
            "$LOCAL_ICON_THEME/scalable/actions" \
            "$LOCAL_ICON_THEME/scalable/apps" \
            "$LOCAL_ICON_THEME/scalable/categories" \
            "$LOCAL_ICON_THEME/symbolic/actions" \
            "$LOCAL_ICON_THEME/symbolic/apps" \
            "$LOCAL_ICON_THEME/symbolic/categories"
        do
            cp "$ARCH_ICON_SRC" "$dir/$icon"
        done
    done

    gtk-update-icon-cache -f -t "$LOCAL_ICON_THEME" >/dev/null 2>&1 || warn "Local Rice-Papirus icon cache update failed."

    log "Patching active Papirus icon files as a hard override for Dash-to-Dock Show Applications."

    local system_theme
    local target
    for system_theme in /usr/share/icons/Papirus-Dark /usr/share/icons/Papirus; do
        [[ -d "$system_theme" ]] || continue

        while IFS= read -r -d '' target; do
            mkdir -p "$BACKUP_DIR/system-icons"
            cp -a "$target" "$BACKUP_DIR/system-icons/$(echo "$target" | sed 's#/#_#g').before" 2>/dev/null || true
            sudo cp "$ARCH_ICON_SRC" "$target" || true
            log "Patched icon file: $target"
        done < <(
            find "$system_theme" -type f \( \
                -name 'view-app-grid-symbolic.svg' -o \
                -name 'view-app-grid.svg' -o \
                -name 'applications-system-symbolic.svg' -o \
                -name 'applications-system.svg' -o \
                -name 'applications-all-symbolic.svg' -o \
                -name 'applications-all.svg' -o \
                -name 'start-here-symbolic.svg' -o \
                -name 'start-here.svg' \
            \) -print0 2>/dev/null || true
        )

        sudo gtk-update-icon-cache -f -t "$system_theme" >/dev/null 2>&1 || true
    done

    gs_set "org.gnome.desktop.interface" "icon-theme" "Rice-Papirus"
}

setup_nautilus_open_with_code() {
    log "Adding Nautilus context menu: Open with Code."

    mkdir -p "$NAUTILUS_EXT_DIR"

    cat > "$NAUTILUS_CODE_EXT" <<'EOFPY'
import os
import subprocess
import urllib.parse
from gi.repository import GObject, Nautilus


def uri_to_path(uri):
    if not uri:
        return None
    if uri.startswith("file://"):
        return urllib.parse.unquote(uri[7:])
    return None


class OpenWithCodeExtension(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        pass

    def _open_paths(self, menu, paths):
        clean_paths = [p for p in paths if p and os.path.exists(p)]
        if not clean_paths:
            return

        try:
            subprocess.Popen(
                ["code", "--reuse-window"] + clean_paths,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except Exception:
            pass

    def _selected_paths(self, files):
        paths = []
        for file_info in files:
            try:
                path = uri_to_path(file_info.get_uri())
                if path:
                    paths.append(path)
            except Exception:
                pass
        return paths

    def get_file_items(self, files):
        paths = self._selected_paths(files)
        if not paths:
            return []

        item = Nautilus.MenuItem(
            name="OpenWithCode::selected",
            label="Open with Code",
            tip="Open selected file or folder in Visual Studio Code",
            icon="code",
        )
        item.connect("activate", self._open_paths, paths)
        return [item]

    def get_background_items(self, current_folder):
        path = None
        try:
            path = uri_to_path(current_folder.get_uri())
        except Exception:
            pass

        if not path:
            return []

        item = Nautilus.MenuItem(
            name="OpenWithCode::background",
            label="Open Folder with Code",
            tip="Open this folder in Visual Studio Code",
            icon="code",
        )
        item.connect("activate", self._open_paths, [path])
        return [item]
EOFPY

    chmod 644 "$NAUTILUS_CODE_EXT"

    nautilus -q >/dev/null 2>&1 || true
    pkill -u "$USER_NAME" -x nautilus >/dev/null 2>&1 || true

    log "Nautilus extension installed at: $NAUTILUS_CODE_EXT"
}

setup_task_manager_wrapper() {
    log "Creating faster Ctrl+Shift+Esc task manager wrapper."

    mkdir -p "$HOME/.local/bin"

    cat > "$TASK_WRAPPER" <<'EOFWRAP'
#!/usr/bin/env bash
set -Eeuo pipefail

if command -v gnome-system-monitor >/dev/null 2>&1; then
    setsid gnome-system-monitor >/dev/null 2>&1 &
    pid="$!"
    sleep 0.15
    sudo -n renice -n -18 -p "$pid" >/dev/null 2>&1 || true
    disown "$pid" >/dev/null 2>&1 || true
    exit 0
fi

if command -v gnome-terminal >/dev/null 2>&1 && command -v btop >/dev/null 2>&1; then
    setsid gnome-terminal -- btop >/dev/null 2>&1 &
    exit 0
fi

if command -v btop >/dev/null 2>&1; then
    setsid btop >/dev/null 2>&1 &
    exit 0
fi

exit 1
EOFWRAP

    chmod +x "$TASK_WRAPPER"
}

install_start_overlay_extension_if_compatible() {
    log "Trying to install Start Overlay in Application View extension for Super key app-grid behaviour."

    local shell_major
    shell_major="$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)"
    local tmp_dir zip_path info_file uuid version url
    tmp_dir="$(mktemp -d)"
    info_file="$tmp_dir/start-overlay-info.json"
    zip_path="$tmp_dir/start-overlay.zip"

    if ! curl -fsSL "https://extensions.gnome.org/extension-info/?pk=${START_OVERLAY_PK}" -o "$info_file"; then
        warn "Could not fetch Start Overlay metadata. Skipping extension."
        rm -rf "$tmp_dir"
        return 0
    fi

    mapfile -t resolved < <(python - "$info_file" "$shell_major" <<'PY'
import json
import sys

info_path, shell_major = sys.argv[1:3]
data = json.load(open(info_path, "r", encoding="utf-8"))
uuid = data.get("uuid", "")
version_map = data.get("shell_version_map", {})

if shell_major not in version_map:
    raise SystemExit(0)

version = version_map[shell_major]["version"]
filename = f"{uuid.replace('@', '')}.v{version}.shell-extension.zip"
url = f"https://extensions.gnome.org/extension-data/{filename}"

print(uuid)
print(version)
print(url)
PY
)

    if [[ "${#resolved[@]}" -lt 3 ]]; then
        warn "Start Overlay extension does not advertise GNOME Shell ${shell_major} support. Skipping safely."
        rm -rf "$tmp_dir"
        return 0
    fi

    uuid="${resolved[0]}"
    version="${resolved[1]}"
    url="${resolved[2]}"

    log "Start Overlay UUID: $uuid"
    log "Start Overlay version: $version"

    if curl -fL "$url" -o "$zip_path"; then
        gnome-extensions install --force "$zip_path" || true
        mkdir -p "$HOME/.local/share/gnome-shell/extensions/$uuid"
        rm -rf "$HOME/.local/share/gnome-shell/extensions/$uuid"
        mkdir -p "$HOME/.local/share/gnome-shell/extensions/$uuid"
        unzip -q "$zip_path" -d "$HOME/.local/share/gnome-shell/extensions/$uuid"
        if [[ -d "$HOME/.local/share/gnome-shell/extensions/$uuid/schemas" ]]; then
            glib-compile-schemas "$HOME/.local/share/gnome-shell/extensions/$uuid/schemas" || true
        fi
        gnome-extensions enable "$uuid" || warn "Start Overlay installed but may need logout/login before enabling."
    else
        warn "Could not download Start Overlay extension zip."
    fi

    rm -rf "$tmp_dir"
}

configure_dock() {
    log "Re-applying stable Dash-to-Dock reveal behaviour and favourites."

    gnome-extensions enable "$DASH_UUID" >/dev/null 2>&1 || warn "Could not enable Dash-to-Dock immediately."

    dconf_write "/org/gnome/shell/extensions/dash-to-dock/dock-position" "'BOTTOM'"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/extend-height" "false"

    dconf_write "/org/gnome/shell/extensions/dash-to-dock/dock-fixed" "false"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/intellihide" "true"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/autohide" "true"

    dconf_write "/org/gnome/shell/extensions/dash-to-dock/require-pressure-to-show" "false"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/pressure-threshold" "0.0"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-delay" "0.0"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/hide-delay" "0.18"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/animation-time" "0.16"

    dconf_write "/org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size" "52"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/custom-theme-shrink" "true"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/force-straight-corner" "false"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/running-indicator-style" "'DOTS'"

    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-show-apps-button" "true"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-apps-at-top" "true"

    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-trash" "true"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-mounts" "false"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/click-action" "'minimize-or-previews'"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/scroll-action" "'cycle-windows'"

    gs_set "$DASH_SCHEMA" "dock-fixed" "false"
    gs_set "$DASH_SCHEMA" "intellihide" "true"
    gs_set "$DASH_SCHEMA" "autohide" "true"
    gs_set "$DASH_SCHEMA" "require-pressure-to-show" "false"
    gs_set "$DASH_SCHEMA" "pressure-threshold" "0.0"
    gs_set "$DASH_SCHEMA" "show-delay" "0.0"
    gs_set "$DASH_SCHEMA" "hide-delay" "0.18"
    gs_set "$DASH_SCHEMA" "animation-time" "0.16"
    gs_set "$DASH_SCHEMA" "intellihide-mode" "ALL_WINDOWS"
    gs_set "$DASH_SCHEMA" "show-show-apps-button" "true"
    gs_set "$DASH_SCHEMA" "show-apps-at-top" "true"

    log "Setting favourites: Files, VS Code, Terminal, Google Chrome/browser."

    python - <<'PY'
from pathlib import Path
import subprocess

app_dirs = [Path.home() / ".local/share/applications", Path("/usr/share/applications")]

def exists(desktop):
    return any((directory / desktop).exists() for directory in app_dirs)

def pick(*items):
    for item in items:
        if exists(item):
            return item
    return None

files = pick("org.gnome.Nautilus.desktop", "nautilus.desktop")
code = pick("code.desktop", "visual-studio-code.desktop", "com.visualstudio.code.desktop")
terminal = pick("org.gnome.Terminal.desktop", "gnome-terminal.desktop", "org.gnome.Console.desktop", "org.gnome.Ptyxis.desktop")
browser = pick("google-chrome.desktop", "google-chrome-stable.desktop", "firefox.desktop", "org.mozilla.firefox.desktop", "brave-browser.desktop", "chromium.desktop")

favourites = [item for item in [files, code, terminal, browser] if item]
value = "[" + ", ".join("'" + item + "'" for item in favourites) + "]"

subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", value], check=True)
print(value)
PY
}

configure_keybindings() {
    log "Configuring requested keybindings."

    gs_set "org.gnome.mutter" "overlay-key" "Super_L"

    gs_set "org.gnome.shell.keybindings" "toggle-overview" "['<Super>s', '<Super>Tab']"
    gs_set "org.gnome.shell.keybindings" "toggle-application-view" "['<Super>a']"

    gs_set "org.gnome.desktop.wm.keybindings" "switch-applications" "['<Alt>Tab']"
    gs_set "org.gnome.desktop.wm.keybindings" "switch-applications-backward" "['<Shift><Alt>Tab']"

    gs_set "org.gnome.desktop.wm.keybindings" "show-desktop" "['<Super>d']"
    gs_set "org.gnome.desktop.wm.keybindings" "close" "['<Super>q', '<Alt>F4']"
    gs_set "org.gnome.desktop.wm.keybindings" "toggle-fullscreen" "['<Super>f']"
    gs_set "org.gnome.desktop.wm.keybindings" "maximize" "['<Super>Up']"
    gs_set "org.gnome.desktop.wm.keybindings" "unmaximize" "['<Super>Down']"

    local terminal_cmd files_cmd browser_cmd code_cmd
    terminal_cmd="$(detect_command gnome-terminal kgx ptyxis xterm || true)"
    files_cmd="$(detect_command nautilus || true)"
    browser_cmd="$(detect_command google-chrome-stable google-chrome firefox brave chromium || true)"
    code_cmd="$(detect_command code || true)"

    python - "$terminal_cmd" "$files_cmd" "$browser_cmd" "$code_cmd" "$TASK_WRAPPER" <<'PY'
import ast
import subprocess
import sys

terminal_cmd, files_cmd, browser_cmd, code_cmd, task_cmd = sys.argv[1:6]
base = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"

def gv_string(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"

entries = []

def add(slug, name, command, binding):
    if command and command.strip():
        entries.append((base + slug + "/", name, command, binding))

add("rice-terminal", "Open Terminal", terminal_cmd, "<Super>Return")
add("rice-files", "Open Files", files_cmd, "<Super>e")
add("rice-browser", "Open Browser", browser_cmd, "<Super>b")
add("rice-code", "Open VS Code", code_cmd, "<Super>c")
add("rice-task-manager", "Open System Monitor", task_cmd, "<Control><Shift>Escape")

try:
    raw = subprocess.check_output(
        ["gsettings", "get", "org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings"],
        text=True
    ).strip()
except Exception:
    raw = "[]"

raw = raw.replace("@as ", "")

try:
    existing = ast.literal_eval(raw)
    if not isinstance(existing, list):
        existing = []
except Exception:
    existing = []

for path, _, _, _ in entries:
    if path not in existing:
        existing.append(path)

value = "[" + ", ".join("'" + item + "'" for item in existing) + "]"
subprocess.run(["gsettings", "set", "org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings", value], check=True)

for path, name, command, binding in entries:
    schema = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{path}"
    subprocess.run(["gsettings", "set", schema, "name", gv_string(name)], check=True)
    subprocess.run(["gsettings", "set", schema, "command", gv_string(command)], check=True)
    subprocess.run(["gsettings", "set", schema, "binding", gv_string(binding)], check=True)

print(value)
PY
}

lock_theme_and_topbar() {
    log "Locking current theme/topbar stability."

    gnome-extensions enable "$USER_THEME_UUID" >/dev/null 2>&1 || true
    gnome-extensions enable "$HIDE_TOP_BAR_UUID" >/dev/null 2>&1 || true

    gs_set "org.gnome.desktop.interface" "gtk-theme" "MacTahoe-Dark-blue"
    gs_set "org.gnome.desktop.interface" "color-scheme" "prefer-dark"
    gs_set "org.gnome.desktop.wm.preferences" "button-layout" ":minimize,maximize,close"

    if schema_exists "$USER_THEME_SCHEMA"; then
        gs_set "$USER_THEME_SCHEMA" "name" "MacTahoe-Dark-blue"
    fi

    if schema_exists "$HIDETOPBAR_SCHEMA"; then
        log "Hide Top Bar schema exists. Leaving current behaviour untouched."
    else
        warn "Hide Top Bar schema not visible. Leaving current working behaviour untouched."
    fi
}

restart_shell_components() {
    log "Restarting user-visible GNOME components safely."

    nautilus -q >/dev/null 2>&1 || true
    pkill -u "$USER_NAME" -x nautilus >/dev/null 2>&1 || true

    if gnome-extensions list | grep -qx "$DASH_UUID"; then
        gnome-extensions disable "$DASH_UUID" >/dev/null 2>&1 || true
        sleep 1
        gnome-extensions enable "$DASH_UUID" >/dev/null 2>&1 || true
    fi

    if gnome-extensions list | grep -qx "$USER_THEME_UUID"; then
        gnome-extensions enable "$USER_THEME_UUID" >/dev/null 2>&1 || true
    fi

    if gnome-extensions list | grep -qx "$HIDE_TOP_BAR_UUID"; then
        gnome-extensions enable "$HIDE_TOP_BAR_UUID" >/dev/null 2>&1 || true
    fi
}

verify() {
    log "Final verification."

    {
        echo "=== Session ==="
        echo "USER=$USER_NAME"
        echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}"
        gnome-shell --version || true

        echo
        echo "=== Google Chrome ==="
        if pacman -Qq google-chrome >/dev/null 2>&1; then
            pacman -Q google-chrome
        else
            echo "google-chrome not installed"
        fi
        command -v google-chrome-stable || command -v google-chrome || true

        echo
        echo "=== Nautilus Open with Code ==="
        pacman -Q nautilus-python python-gobject 2>/dev/null || true
        echo "$NAUTILUS_CODE_EXT"
        test -f "$NAUTILUS_CODE_EXT" && echo "Nautilus VS Code extension exists"

        echo
        echo "=== Theme ==="
        echo "GTK=$(gsettings get org.gnome.desktop.interface gtk-theme)"
        echo "Shell=$(gsettings get "$USER_THEME_SCHEMA" name 2>/dev/null || echo unavailable)"
        echo "Icons=$(gsettings get org.gnome.desktop.interface icon-theme)"
        echo "Buttons=$(gsettings get org.gnome.desktop.wm.preferences button-layout)"

        echo
        echo "=== Dock ==="
        gsettings get org.gnome.shell favorite-apps
        dconf dump /org/gnome/shell/extensions/dash-to-dock/ || true

        echo
        echo "=== Keybindings ==="
        echo "Super overlay=$(gsettings get org.gnome.mutter overlay-key 2>/dev/null || echo unavailable)"
        echo "Overview=$(gsettings get org.gnome.shell.keybindings toggle-overview)"
        echo "Apps=$(gsettings get org.gnome.shell.keybindings toggle-application-view 2>/dev/null || echo unavailable)"
        echo "Alt+Tab=$(gsettings get org.gnome.desktop.wm.keybindings switch-applications)"
        echo "Custom=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"

        echo
        echo "=== Extensions ==="
        gnome-extensions list --enabled | grep -Ei 'dash.*dock|hidetopbar|user-theme|start.*overlay|application.*view' || true

        echo
        echo "=== Fetch ==="
        if command -v neofetch >/dev/null 2>&1; then
            echo "neofetch still present: $(command -v neofetch)"
        else
            echo "neofetch removed"
        fi
        echo "ff-blue=$(command -v ff-blue || echo missing)"

        echo
        echo "=== Power ==="
        powerprofilesctl get 2>/dev/null || true
    } | tee -a "$LOG"

    log "Phase 14 complete."
    log "Log saved at: $LOG"
    log "Now log out and back in once."
}

main() {
    require_session

    mkdir -p "$BACKUP_DIR"
    touch "$LOG"

    log "Starting Phase 14 remaining-problems solver."
    log "Backup directory: $BACKUP_DIR"

    backup_path "$BASHRC"
    backup_path "$BASH_PROFILE"
    backup_path "$PROFILE"
    backup_path "$HOME/.local/share/icons"
    backup_path "$HOME/.local/share/nautilus-python"
    backup_path "$HOME/.config/autostart"

    dconf dump /org/gnome/shell/ > "$BACKUP_DIR/gnome-shell-before-phase14.ini" 2>/dev/null || true
    dconf dump /org/gnome/shell/extensions/dash-to-dock/ > "$BACKUP_DIR/dash-to-dock-before-phase14.ini" 2>/dev/null || true

    install_base_packages
    install_google_chrome
    fix_terminal_fetch
    install_icon_theme_and_arch_launcher_icon
    setup_nautilus_open_with_code
    setup_task_manager_wrapper
    install_start_overlay_extension_if_compatible
    lock_theme_and_topbar
    configure_dock
    configure_keybindings
    restart_shell_components
    verify
}

main "$@"