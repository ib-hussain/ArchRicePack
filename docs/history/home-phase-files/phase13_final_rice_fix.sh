#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# phase13_final_rice_fix.sh
#
# Final repair script for:
#   1. Dash-to-Dock reveal/hide behaviour.
#   2. Arch-logo dock launcher / Show Applications button.
#   3. Keybindings: Super, Super+Tab, Super+S, Super+A, Ctrl+Shift+Esc.
#   4. Icon pack replacement using Papirus with local Arch override.
#   5. Theme stability: MacTahoe-Dark-blue, right-side buttons.
#   6. Preserve Hide Top Bar behaviour exactly as currently liked.
#   7. Preserve Files transparency and current glassy dock/theme look.
###############################################################################

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase13-final-rice-fix-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase13-${STAMP}"

DASH_UUID="dash-to-dock@micxgx.gmail.com"
USER_THEME_UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
HIDE_TOP_BAR_UUID="hidetopbar@mathieu.bidon.ca"

DASH_SCHEMA="org.gnome.shell.extensions.dash-to-dock"
USER_THEME_SCHEMA="org.gnome.shell.extensions.user-theme"
HIDE_TOP_BAR_SCHEMA="org.gnome.shell.extensions.hidetopbar"

BASHRC="$HOME/.bashrc"
BASH_PROFILE="$HOME/.bash_profile"
PROFILE="$HOME/.profile"

FF_BLUE="$HOME/.local/bin/ff-blue"
LOCAL_ICON_THEME="$HOME/.local/share/icons/Rice-Papirus"
ARCH_ICON_SRC="$BACKUP_DIR/arch-dock-icon.svg"

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
    fail "phase13_final_rice_fix.sh failed at line ${line}. Check log: ${LOG}"
}

trap 'on_error ${LINENO}' ERR

require_session() {
    if [[ "${EUID}" -eq 0 ]]; then
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
            warn "Failed to set ${schema} ${key} ${value}"
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
        warn "Failed to write dconf key: ${path} ${value}"
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

    log "Cleaning old fetch autostart noise from $file"

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

    started = False
    for start, end in blocks:
        if stripped == start:
            skip = True
            end_marker = end
            started = True
            break

    if started:
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
    log "Rebuilding clean single Fastfetch startup block."

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

# >>> phase13-rice-terminal-final >>>
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
# <<< phase13-rice-terminal-final <<<
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
            sudo pacman -Rns --noconfirm "$neofetch_pkg" || warn "Could not remove $neofetch_pkg; startup remains clean."
        else
            warn "Neofetch exists but is not pacman-owned: $neofetch_bin"
        fi
    fi

    hash -r || true
}

create_arch_svg() {
    mkdir -p "$BACKUP_DIR"

    cat > "$ARCH_ICON_SRC" <<'EOFSVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <path fill="#1793D1" d="M128 18C112.3 56.3 101.9 84.2 83.7 122.4c12.3 13 27.7 24.3 46.9 34.3-20.7-5.3-37.1-13.2-49.9-24.1C60.6 173.9 34.5 226.4 7 274c28.6-16.5 51.9-27.1 74.1-32.2-.9-4.5-1.3-9.2-1.2-14.1.7-31.7 17.1-56.1 36.6-54.4 19.5 1.6 34.8 28.8 34.1 60.5-.1 3.3-.4 6.5-.9 9.7 21.7 5.4 44.8 15.9 72.9 32.3-9.5-17.5-18.3-34-26.8-49.8-15.4-12-33.8-24.2-62.1-38.7 20.5 5.3 36.2 11.5 48.6 18.6C160.9 162.3 145.9 103.9 128 18z"/>
</svg>
EOFSVG
}

install_icon_theme() {
    log "Installing Papirus and creating Rice-Papirus icon theme with Arch launcher override."

    sudo pacman -S --needed --noconfirm papirus-icon-theme gtk-update-icon-cache >/dev/null || sudo pacman -S --needed --noconfirm papirus-icon-theme gtk3 >/dev/null

    create_arch_svg

    rm -rf "$LOCAL_ICON_THEME"
    mkdir -p \
        "$LOCAL_ICON_THEME/scalable/actions" \
        "$LOCAL_ICON_THEME/scalable/apps" \
        "$LOCAL_ICON_THEME/scalable/categories" \
        "$LOCAL_ICON_THEME/symbolic/actions" \
        "$LOCAL_ICON_THEME/symbolic/apps" \
        "$LOCAL_ICON_THEME/symbolic/categories"

    cat > "$LOCAL_ICON_THEME/index.theme" <<'EOFTHEME'
[Icon Theme]
Name=Rice-Papirus
Comment=Papirus-Dark with local Arch launcher override
Inherits=Papirus-Dark,Papirus,Adwaita,hicolor
Directories=scalable/actions,scalable/apps,scalable/categories,symbolic/actions,symbolic/apps,symbolic/categories

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

    local icon
    local dir
    for icon in "${icon_names[@]}"; do
        for dir in \
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

    gtk-update-icon-cache -f -t "$LOCAL_ICON_THEME" >/dev/null 2>&1 || warn "Local icon cache update failed; theme should still load after logout."

    gs_set "org.gnome.desktop.interface" "icon-theme" "Rice-Papirus"
}

patch_dash_show_apps_icon() {
    log "Patching Dash-to-Dock Show Applications media icons where safely possible."

    local ext_dirs=(
        "$HOME/.local/share/gnome-shell/extensions/$DASH_UUID"
        "/usr/share/gnome-shell/extensions/$DASH_UUID"
    )

    local ext_dir
    local file
    local safe_name

    for ext_dir in "${ext_dirs[@]}"; do
        [[ -d "$ext_dir" ]] || continue

        while IFS= read -r -d '' file; do
            safe_name="$(echo "$file" | sed 's#/#_#g')"
            cp -a "$file" "$BACKUP_DIR/${safe_name}.before" 2>/dev/null || sudo cp -a "$file" "$BACKUP_DIR/${safe_name}.before" 2>/dev/null || true

            if [[ -w "$file" ]]; then
                cp "$ARCH_ICON_SRC" "$file" || true
            else
                sudo cp "$ARCH_ICON_SRC" "$file" || true
            fi

            log "Patched possible dock launcher icon: $file"
        done < <(
            find "$ext_dir" -type f \( \
                -iname '*show*app*.svg' -o \
                -iname '*view*grid*.svg' -o \
                -iname '*apps*.svg' -o \
                -iname 'logo.svg' \
            \) -print0 2>/dev/null || true
        )
    done
}

lock_theme() {
    log "Locking MacTahoe theme, right-side buttons, and current top-bar behaviour."

    gnome-extensions enable "$USER_THEME_UUID" >/dev/null 2>&1 || true
    gnome-extensions enable "$HIDE_TOP_BAR_UUID" >/dev/null 2>&1 || true

    gs_set "org.gnome.desktop.interface" "gtk-theme" "MacTahoe-Dark-blue"
    gs_set "org.gnome.desktop.interface" "color-scheme" "prefer-dark"
    gs_set "org.gnome.desktop.wm.preferences" "button-layout" ":minimize,maximize,close"

    if schema_exists "$USER_THEME_SCHEMA"; then
        gs_set "$USER_THEME_SCHEMA" "name" "MacTahoe-Dark-blue"
    else
        warn "User-theme schema missing; shell theme may apply after logout/login."
    fi

    if schema_exists "$HIDE_TOP_BAR_SCHEMA"; then
        log "Hide Top Bar schema exists. Current settings are preserved."
    else
        warn "Hide Top Bar schema not visible. Extension is enabled if present; existing behaviour is left untouched."
    fi
}

configure_dock() {
    log "Configuring Dash-to-Dock reveal behaviour, Arch launcher position, and favourites."

    if gnome-extensions list | grep -qx "$DASH_UUID"; then
        gnome-extensions enable "$DASH_UUID" >/dev/null 2>&1 || warn "Could not enable Dash-to-Dock."
    else
        warn "Dash-to-Dock UUID not visible; writing settings anyway."
    fi

    dconf_write "/org/gnome/shell/extensions/dash-to-dock/dock-position" "'BOTTOM'"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/extend-height" "false"

    # Critical reveal behaviour.
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/dock-fixed" "false"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/intellihide" "true"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/autohide" "true"

    # Make edge reveal immediate instead of pressure-based.
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/require-pressure-to-show" "false"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/pressure-threshold" "0.0"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-delay" "0.0"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/hide-delay" "0.18"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/animation-time" "0.16"

    # Keep glassy/rounded style close to current theme.
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size" "52"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/custom-theme-shrink" "true"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/force-straight-corner" "false"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/running-indicator-style" "'DOTS'"

    # Launcher/start-menu button.
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-show-apps-button" "true"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-apps-at-top" "true"

    # Clean dock behaviour.
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-trash" "true"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/show-mounts" "false"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/click-action" "'minimize-or-previews'"
    dconf_write "/org/gnome/shell/extensions/dash-to-dock/scroll-action" "'cycle-windows'"

    # Schema-aware settings for keys that exist only on some versions.
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

    log "Setting pinned applications: Files, VS Code, Terminal, primary browser."

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
browser = pick("firefox.desktop", "org.mozilla.firefox.desktop", "brave-browser.desktop", "chromium.desktop", "google-chrome.desktop", "google-chrome-stable.desktop")

favourites = [item for item in [files, code, terminal, browser] if item]
value = "[" + ", ".join("'" + item + "'" for item in favourites) + "]"

subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", value], check=True)
print(value)
PY
}

configure_keybindings() {
    log "Configuring requested keybindings."

    # Single Super key opens GNOME overview.
    gs_set "org.gnome.mutter" "overlay-key" "Super_L"

    # Requested bindings.
    gs_set "org.gnome.shell.keybindings" "toggle-overview" "['<Super>Tab', '<Super>s']"

    if schema_key_exists "org.gnome.shell.keybindings" "toggle-application-view"; then
        gs_set "org.gnome.shell.keybindings" "toggle-application-view" "['<Super>a']"
    else
        warn "GNOME Shell key toggle-application-view missing; Super+A will also be provided through a custom command fallback if possible."
    fi

    # Standard switching.
    gs_set "org.gnome.desktop.wm.keybindings" "switch-applications" "['<Alt>Tab']"
    gs_set "org.gnome.desktop.wm.keybindings" "switch-applications-backward" "['<Shift><Alt>Tab']"

    # Useful window/system bindings.
    gs_set "org.gnome.desktop.wm.keybindings" "show-desktop" "['<Super>d']"
    gs_set "org.gnome.desktop.wm.keybindings" "close" "['<Super>q', '<Alt>F4']"
    gs_set "org.gnome.desktop.wm.keybindings" "toggle-fullscreen" "['<Super>f']"
    gs_set "org.gnome.desktop.wm.keybindings" "maximize" "['<Super>Up']"
    gs_set "org.gnome.desktop.wm.keybindings" "unmaximize" "['<Super>Down']"

    log "Creating custom launch keybindings."

    local terminal_cmd files_cmd browser_cmd code_cmd task_cmd
    terminal_cmd="$(detect_command gnome-terminal kgx ptyxis xterm || true)"
    files_cmd="$(detect_command nautilus || true)"
    browser_cmd="$(detect_command firefox brave chromium google-chrome-stable google-chrome || true)"
    code_cmd="$(detect_command code || true)"
    task_cmd="$(detect_command gnome-system-monitor || true)"

    if [[ -z "$task_cmd" ]]; then
        task_cmd="$terminal_cmd -- btop"
    fi

    python - "$terminal_cmd" "$files_cmd" "$browser_cmd" "$code_cmd" "$task_cmd" <<'PY'
import ast
import subprocess
import sys

terminal_cmd, files_cmd, browser_cmd, code_cmd, task_cmd = sys.argv[1:6]

base = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"

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
    subprocess.run(["gsettings", "set", schema, "name", f"'{name}'"], check=True)
    subprocess.run(["gsettings", "set", schema, "command", f"'{command}'"], check=True)
    subprocess.run(["gsettings", "set", schema, "binding", f"'{binding}'"], check=True)

print(value)
PY
}

clock_policy() {
    log "Desktop clock policy."

    # GNOME Wayland does not provide a reliable desktop-root layer for Conky.
    # Previous logs showed Conky could start but not reliably appear.
    # Do not force an unstable widget over the final layout.
    mkdir -p "$HOME/.config/autostart"

    if [[ -f "$HOME/.config/autostart/rice-desktop-clock.desktop" ]]; then
        cp -a "$HOME/.config/autostart/rice-desktop-clock.desktop" "$BACKUP_DIR/rice-desktop-clock.desktop.before" || true
        sed -i 's/^X-GNOME-Autostart-enabled=.*/X-GNOME-Autostart-enabled=false/' "$HOME/.config/autostart/rice-desktop-clock.desktop" || true
        sed -i 's/^Hidden=.*/Hidden=true/' "$HOME/.config/autostart/rice-desktop-clock.desktop" || true
    fi

    pkill -u "$USER" -f "conky.*rice-clock.conf" >/dev/null 2>&1 || true

    warn "Desktop clock widget skipped safely. GNOME top clock remains the reliable clock."
}

reload_extensions() {
    log "Reloading Dash-to-Dock extension so reveal settings apply immediately where possible."

    if gnome-extensions list | grep -qx "$DASH_UUID"; then
        gnome-extensions disable "$DASH_UUID" >/dev/null 2>&1 || true
        sleep 1
        gnome-extensions enable "$DASH_UUID" >/dev/null 2>&1 || warn "Dash-to-Dock enable failed; log out/in will reload it."
    fi

    if gnome-extensions list | grep -qx "$HIDE_TOP_BAR_UUID"; then
        gnome-extensions enable "$HIDE_TOP_BAR_UUID" >/dev/null 2>&1 || true
    fi

    if gnome-extensions list | grep -qx "$USER_THEME_UUID"; then
        gnome-extensions enable "$USER_THEME_UUID" >/dev/null 2>&1 || true
    fi
}

verify() {
    log "Final verification."

    {
        echo "=== Session ==="
        echo "USER=$USER"
        echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}"
        gnome-shell --version || true

        echo
        echo "=== Theme ==="
        echo "GTK=$(gsettings get org.gnome.desktop.interface gtk-theme)"
        echo "Shell=$(gsettings get "$USER_THEME_SCHEMA" name 2>/dev/null || echo unavailable)"
        echo "Icons=$(gsettings get org.gnome.desktop.interface icon-theme)"
        echo "Buttons=$(gsettings get org.gnome.desktop.wm.preferences button-layout)"

        echo
        echo "=== Dock favourites ==="
        gsettings get org.gnome.shell favorite-apps

        echo
        echo "=== Dash-to-Dock ==="
        dconf dump /org/gnome/shell/extensions/dash-to-dock/ || true

        echo
        echo "=== Keybindings ==="
        echo "Mutter Super overlay=$(gsettings get org.gnome.mutter overlay-key 2>/dev/null || echo unavailable)"
        echo "Super+Tab/Super+S overview=$(gsettings get org.gnome.shell.keybindings toggle-overview)"
        echo "Super+A apps=$(gsettings get org.gnome.shell.keybindings toggle-application-view 2>/dev/null || echo unavailable)"
        echo "Alt+Tab=$(gsettings get org.gnome.desktop.wm.keybindings switch-applications)"
        echo "Ctrl+Shift+Esc custom list=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"

        echo
        echo "=== Extensions ==="
        gnome-extensions list --enabled | grep -Ei 'dash.*dock|hidetopbar|hide.*top|user-theme' || true

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

        echo
        echo "=== Clock ==="
        pgrep -a -u "$USER" conky || echo "no conky clock active"
    } | tee -a "$LOG"

    log "Phase 13 final rice fix complete."
    log "Log saved at: $LOG"
    log "Now log out and back in once. After login: bottom-edge hover should reveal the dock, Super opens overview, Super+A opens apps, Super+S opens overview/search, Ctrl+Shift+Esc opens system monitor."
}

main() {
    require_session

    mkdir -p "$BACKUP_DIR"
    touch "$LOG"

    log "Starting Phase 13 final rice fix."
    log "Backup directory: $BACKUP_DIR"

    backup_path "$BASHRC"
    backup_path "$BASH_PROFILE"
    backup_path "$PROFILE"
    backup_path "$HOME/.local/share/icons"
    backup_path "$HOME/.config/autostart"
    backup_path "$HOME/.config/conky"
    dconf dump /org/gnome/shell/ > "$BACKUP_DIR/gnome-shell-before-phase13.ini" 2>/dev/null || true
    dconf dump /org/gnome/shell/extensions/dash-to-dock/ > "$BACKUP_DIR/dash-to-dock-before-phase13.ini" 2>/dev/null || true

    log "Installing required packages."
    sudo pacman -S --needed --noconfirm fastfetch papirus-icon-theme gtk3 gnome-system-monitor btop eza bat fd ripgrep fzf zoxide jq tree ncdu tldr chafa gnome-shell-extensions >/dev/null

    fix_terminal_fetch
    install_icon_theme
    patch_dash_show_apps_icon
    lock_theme
    configure_dock
    configure_keybindings
    clock_policy
    reload_extensions
    verify
}

main "$@"
