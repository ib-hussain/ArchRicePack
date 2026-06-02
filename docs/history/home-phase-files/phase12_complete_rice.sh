#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# phase12_complete_rice.sh
# Final single-pass GNOME/MacTahoe rice stabiliser.
#
# Goals:
#   - Preserve current Hide Top Bar behaviour.
#   - Enable Dash-to-Dock intelligent hide:
#       visible on empty desktop, hidden when overlapped/fullscreen.
#   - Keep MacTahoe-Dark-blue GTK/Shell theme.
#   - Keep Files/Nautilus transparency and glassy dock styling.
#   - Keep window buttons on right: minimize,maximize,close.
#   - Set dock favourites: Files, Terminal, Browser, VS Code.
#   - Try to force Arch logo as dock launcher/show-apps icon.
#   - Re-apply keybindings.
#   - Keep terminal fetch clean.
#   - Add a safe optional Conky desktop clock only if it can run without breaking.
###############################################################################

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase12-complete-rice-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase12-${STAMP}"

DASH_UUID="dash-to-dock@micxgx.gmail.com"
USER_THEME_UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
HIDE_TOP_BAR_UUID="hidetopbar@mathieu.bidon.ca"

DASH_SCHEMA="org.gnome.shell.extensions.dash-to-dock"
HIDETOPBAR_SCHEMA="org.gnome.shell.extensions.hidetopbar"
USER_THEME_SCHEMA="org.gnome.shell.extensions.user-theme"

BASHRC="$HOME/.bashrc"
BASH_PROFILE="$HOME/.bash_profile"
PROFILE="$HOME/.profile"
FF_BLUE="$HOME/.local/bin/ff-blue"

CLOCK_CONF="$HOME/.config/conky/rice-clock.conf"
CLOCK_DESKTOP="$HOME/.config/autostart/rice-desktop-clock.desktop"

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
    fail "phase12_complete_rice.sh failed at line ${line}. Check log: ${LOG}"
}

trap 'on_error ${LINENO}' ERR

require_user_session() {
    if [[ "${EUID}" -eq 0 ]]; then
        fail "Do not run this script as root. Run it as your normal user: ibrahim."
    fi

    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
        fail "GNOME DBus/session variables are missing. Log into GNOME normally, open Terminal, then rerun this script."
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

gs_set_if_possible() {
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

dconf_write_safe() {
    local path="$1"
    local value="$2"

    if dconf write "$path" "$value" 2>>"$LOG"; then
        log "dconf write ${path} ${value}"
    else
        warn "Could not dconf write ${path} ${value}"
    fi
}

backup_path() {
    local src="$1"

    if [[ -e "$src" || -L "$src" ]]; then
        local rel="${src#$HOME/}"
        mkdir -p "$BACKUP_DIR/home/$(dirname "$rel")"
        cp "$src" "$BACKUP_DIR/home/$rel"
        log "Backed up: $src"
    else
        log "Backup skip, missing: $src"
    fi
}

detect_desktop_file() {
    local found=""
    local desktop=""

    for desktop in "$@"; do
        if [[ -f "$HOME/.local/share/applications/$desktop" || -f "/usr/share/applications/$desktop" ]]; then
            found="$desktop"
            break
        fi
    done

    [[ -n "$found" ]] && printf '%s\n' "$found"
}

detect_command() {
    local cmd=""
    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf '%s\n' "$cmd"
            return 0
        fi
    done
    return 1
}

clean_fetch_noise_from_shell_file() {
    local file="$1"

    [[ -f "$file" ]] || return 0

    log "Cleaning direct fetch startup references from: $file"

    python - "$file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(errors="ignore").splitlines()

marked_blocks = [
    ("# >>> phase8-rice-terminal-toolkit >>>", "# <<< phase8-rice-terminal-toolkit <<<"),
    ("# >>> phase9-rice-terminal-final >>>", "# <<< phase9-rice-terminal-final <<<"),
    ("# >>> phase10-rice-terminal-final >>>", "# <<< phase10-rice-terminal-final <<<"),
    ("# >>> phase12-rice-terminal-final >>>", "# <<< phase12-rice-terminal-final <<<"),
]

out = []
skip = False
end_marker = ""

i = 0
while i < len(text):
    line = text[i]
    stripped = line.strip()

    if skip:
        if stripped == end_marker:
            skip = False
            end_marker = ""
        i += 1
        continue

    started = False
    for start, end in marked_blocks:
        if stripped == start:
            skip = True
            end_marker = end
            started = True
            break

    if started:
        i += 1
        continue

    # Remove common old fetch autostart blocks safely:
    # if ... neofetch ...
    #     neofetch
    # fi
    # if ... fastfetch ...
    #     fastfetch
    # fi
    if ("neofetch" in stripped or "fastfetch" in stripped) and stripped.startswith("if "):
        # Skip until matching simple fi for this old tiny shell block.
        depth = 0
        while i < len(text):
            s = text[i].strip()
            if s.startswith("if "):
                depth += 1
            if s == "fi":
                depth -= 1
                if depth <= 0:
                    i += 1
                    break
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

ensure_clean_terminal_fetch() {
    log "Ensuring terminal startup shows only one blue Arch Fastfetch."

    mkdir -p "$HOME/.local/bin"
    cat > "$FF_BLUE" <<'EOS'
#!/usr/bin/env bash
exec /usr/bin/fastfetch --logo arch --logo-color-1 blue --logo-color-2 blue --logo-color-3 blue "$@"
EOS
    chmod +x "$FF_BLUE"

    touch "$BASHRC"

    for file in "$BASHRC" "$BASH_PROFILE" "$PROFILE"; do
        clean_fetch_noise_from_shell_file "$file"
    done

    cat >> "$BASHRC" <<'EOS'

# >>> phase12-rice-terminal-final >>>
# Final interactive terminal banner/tooling for the Arch GNOME rice.
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
# <<< phase12-rice-terminal-final <<<
EOS

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
            sudo pacman -Rns --noconfirm "$neofetch_pkg" || warn "Could not remove $neofetch_pkg; shell startup is still clean."
        else
            warn "Neofetch exists but is not owned by pacman: $neofetch_bin"
        fi
    fi

    hash -r || true
}

apply_theme_lock() {
    log "Locking MacTahoe-Dark-blue theme and current button layout."

    gnome-extensions enable "$USER_THEME_UUID" >/dev/null 2>&1 || warn "Could not enable User Themes extension; it may already be enabled."

    gs_set_if_possible "org.gnome.desktop.interface" "gtk-theme" "MacTahoe-Dark-blue"
    gs_set_if_possible "org.gnome.desktop.interface" "color-scheme" "prefer-dark"
    gs_set_if_possible "org.gnome.desktop.wm.preferences" "button-layout" ":minimize,maximize,close"

    if schema_exists "$USER_THEME_SCHEMA"; then
        gs_set_if_possible "$USER_THEME_SCHEMA" "name" "MacTahoe-Dark-blue"
    else
        warn "User Theme schema not visible; Shell theme may apply after logout/login."
    fi
}

apply_keybindings() {
    log "Applying keybindings."

    gs_set_if_possible "org.gnome.shell.keybindings" "toggle-overview" "['<Super>Tab']"
    gs_set_if_possible "org.gnome.desktop.wm.keybindings" "switch-applications" "['<Alt>Tab']"
    gs_set_if_possible "org.gnome.desktop.wm.keybindings" "switch-applications-backward" "['<Shift><Alt>Tab']"

    gs_set_if_possible "org.gnome.desktop.wm.keybindings" "show-desktop" "['<Super>d']"
    gs_set_if_possible "org.gnome.desktop.wm.keybindings" "close" "['<Super>q', '<Alt>F4']"
    gs_set_if_possible "org.gnome.desktop.wm.keybindings" "toggle-fullscreen" "['<Super>f']"
    gs_set_if_possible "org.gnome.desktop.wm.keybindings" "maximize" "['<Super>Up']"
    gs_set_if_possible "org.gnome.desktop.wm.keybindings" "unmaximize" "['<Super>Down']"

    log "Adding custom app launch keybindings."

    local terminal_cmd files_cmd browser_cmd code_cmd
    terminal_cmd="$(detect_command gnome-terminal kgx ptyxis xterm || true)"
    files_cmd="$(detect_command nautilus || true)"
    browser_cmd="$(detect_command firefox brave chromium google-chrome-stable google-chrome || true)"
    code_cmd="$(detect_command code || true)"

    python - "$terminal_cmd" "$files_cmd" "$browser_cmd" "$code_cmd" <<'PY'
import ast
import subprocess
import sys

terminal_cmd, files_cmd, browser_cmd, code_cmd = sys.argv[1:5]

base = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
entries = []

def add(slug, name, command, binding):
    if command:
        entries.append((base + slug + "/", name, command, binding))

add("rice-terminal", "Open Terminal", terminal_cmd, "<Super>Return")
add("rice-files", "Open Files", files_cmd, "<Super>e")
add("rice-browser", "Open Browser", browser_cmd, "<Super>b")
add("rice-code", "Open VS Code", code_cmd, "<Super>c")

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

subprocess.run(
    ["gsettings", "set", "org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings", value],
    check=False
)

for path, name, command, binding in entries:
    schema = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{path}"
    subprocess.run(["gsettings", "set", schema, "name", name], check=False)
    subprocess.run(["gsettings", "set", schema, "command", command], check=False)
    subprocess.run(["gsettings", "set", schema, "binding", binding], check=False)

print(value)
PY
}

create_arch_launcher_icon() {
    log "Creating Arch logo icon override for dock launcher/show-apps icon."

    local icon_base="$HOME/.local/share/icons/hicolor"
    local action_dir="$icon_base/scalable/actions"
    local app_dir="$icon_base/scalable/apps"
    mkdir -p "$action_dir" "$app_dir"

    cat > "$icon_base/index.theme" <<'EOFIDX'
[Icon Theme]
Name=Rice Local Hicolor
Comment=Local icon overrides for the Arch GNOME rice
Directories=scalable/actions,scalable/apps

[scalable/actions]
Size=48
Type=Scalable
Context=Actions

[scalable/apps]
Size=48
Type=Scalable
Context=Applications
EOFIDX

    cat > "$BACKUP_DIR/arch-dock-icon.svg" <<'EOFSVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <path fill="#1793D1" d="M128 20C113.7 54.9 104.8 77.7 88.8 111.9c9.8 10.4 21.9 22.5 41.5 36.2-21.1-8.7-35.5-17.5-46.3-26.7-20.6 43-52.8 106.7-80 153.6 31.1-18 55.2-29.1 77.7-33.3-1-4.3-1.6-8.9-1.5-13.7l.1-3.3c.8-31.3 17.1-55.4 36.4-53.8 19.3 1.6 34.4 28.3 33.6 59.6-.1 4.1-.5 8.1-1.2 12 22.2 4.4 46 15.5 76.9 33.4-10.5-19.3-19.9-36.8-28.9-53.5-14.2-11-29-25.3-59.4-40.9 20.9 5.4 35.9 11.6 47.6 18.5C159.7 151.4 143.8 108.3 128 20z"/>
</svg>
EOFSVG

    local icon_names=(
        "view-app-grid-symbolic.svg"
        "view-app-grid.svg"
        "applications-system-symbolic.svg"
        "applications-system.svg"
        "start-here-symbolic.svg"
        "start-here.svg"
        "archlinux.svg"
        "archlinux-symbolic.svg"
    )

    local name
    for name in "${icon_names[@]}"; do
        cp "$BACKUP_DIR/arch-dock-icon.svg" "$action_dir/$name"
        cp "$BACKUP_DIR/arch-dock-icon.svg" "$app_dir/$name"
    done

    gtk-update-icon-cache -f -t "$icon_base" >/dev/null 2>&1 || warn "gtk-update-icon-cache for local hicolor icon theme failed; icon may still apply after logout."

    log "Patching Dash-to-Dock media logo files where safely possible."
    local ext_dir media_file backup_target
    for ext_dir in "$HOME/.local/share/gnome-shell/extensions/$DASH_UUID" "/usr/share/gnome-shell/extensions/$DASH_UUID"; do
        [[ -d "$ext_dir/media" ]] || continue

        for media_file in "$ext_dir/media/logo.svg" "$ext_dir/media/glossy.svg"; do
            [[ -e "$media_file" ]] || continue

            backup_target="$BACKUP_DIR/$(echo "$media_file" | sed 's#/#_#g').before"
            cp "$media_file" "$backup_target" 2>/dev/null || sudo cp "$media_file" "$backup_target" 2>/dev/null || true

            if [[ -w "$media_file" ]]; then
                cp "$BACKUP_DIR/arch-dock-icon.svg" "$media_file" || true
            else
                sudo cp "$BACKUP_DIR/arch-dock-icon.svg" "$media_file" || true
            fi
        done
    done
}

apply_dock_intellihide_and_favourites() {
    log "Applying Dash-to-Dock intelligent hide and favourite apps."

    if gnome-extensions list | grep -qx "$DASH_UUID"; then
        gnome-extensions enable "$DASH_UUID" >/dev/null 2>&1 || warn "Could not enable Dash-to-Dock; it may already be enabled or need logout/login."
    else
        warn "Dash-to-Dock UUID not visible to GNOME Shell. Existing dconf values will still be written."
    fi

    # Critical behaviour:
    #   dock-fixed=false + intellihide=true
    # means dock is normally available on desktop but hides when windows overlap it.
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/dock-position" "'BOTTOM'"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/extend-height" "false"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/dock-fixed" "false"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/intellihide" "true"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/autohide" "false"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size" "52"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/show-show-apps-button" "true"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/show-trash" "true"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/show-mounts" "false"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/click-action" "'minimize-or-previews'"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/scroll-action" "'cycle-windows'"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/running-indicator-style" "'DOTS'"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/custom-theme-shrink" "true"
    dconf_write_safe "/org/gnome/shell/extensions/dash-to-dock/force-straight-corner" "false"

    # These keys are version-dependent. Set only if visible through the schema.
    gs_set_if_possible "$DASH_SCHEMA" "animation-time" "0.20"
    gs_set_if_possible "$DASH_SCHEMA" "hide-delay" "0.12"
    gs_set_if_possible "$DASH_SCHEMA" "show-delay" "0.04"
    gs_set_if_possible "$DASH_SCHEMA" "intellihide-mode" "ALL_WINDOWS"
    gs_set_if_possible "$DASH_SCHEMA" "require-pressure-to-show" "false"
    gs_set_if_possible "$DASH_SCHEMA" "pressure-threshold" "80"

    log "Setting dock favourites."

    python - <<'PY'
from pathlib import Path
import subprocess

app_dirs = [Path.home() / ".local/share/applications", Path("/usr/share/applications")]

def exists(desktop_file):
    return any((directory / desktop_file).exists() for directory in app_dirs)

def pick(*items):
    for item in items:
        if exists(item):
            return item
    return None

files = pick("org.gnome.Nautilus.desktop", "nautilus.desktop")
terminal = pick("org.gnome.Terminal.desktop", "gnome-terminal.desktop", "org.gnome.Console.desktop", "org.gnome.Ptyxis.desktop")
browser = pick(
    "firefox.desktop",
    "org.mozilla.firefox.desktop",
    "brave-browser.desktop",
    "chromium.desktop",
    "google-chrome.desktop",
    "google-chrome-stable.desktop"
)
code = pick("code.desktop", "visual-studio-code.desktop", "com.visualstudio.code.desktop")

ordered = [item for item in [files, terminal, browser, code] if item]

value = "[" + ", ".join("'" + item + "'" for item in ordered) + "]"
subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", value], check=True)
print(value)
PY
}

preserve_hide_top_bar_logic() {
    log "Preserving current Hide Top Bar logic."

    if gnome-extensions list | grep -qx "$HIDE_TOP_BAR_UUID"; then
        gnome-extensions enable "$HIDE_TOP_BAR_UUID" >/dev/null 2>&1 || warn "Could not enable Hide Top Bar; it may already be enabled."
    else
        warn "Hide Top Bar extension not visible. Current behaviour may still persist from existing loaded session."
    fi

    # Do not force a different panel mode. User likes current logic:
    #   hidden for fullscreen/maximised occupation, visible when windowed.
    # Only reinforce intellihide if the schema is actually available.
    if schema_exists "$HIDETOPBAR_SCHEMA"; then
        if schema_key_exists "$HIDETOPBAR_SCHEMA" "enable-intellihide"; then
            local current
            current="$(gsettings get "$HIDETOPBAR_SCHEMA" enable-intellihide 2>/dev/null || echo "unknown")"
            log "Current Hide Top Bar enable-intellihide=${current}"
            gsettings set "$HIDETOPBAR_SCHEMA" enable-intellihide true || warn "Could not set Hide Top Bar enable-intellihide=true."
        fi

        if schema_key_exists "$HIDETOPBAR_SCHEMA" "mouse-sensitive"; then
            log "Leaving Hide Top Bar mouse-sensitive behaviour unchanged."
        fi
    else
        warn "Hide Top Bar schema is not visible in this session; leaving existing panel behaviour untouched."
    fi
}

safe_desktop_clock_attempt() {
    log "Handling desktop clock safely."

    # Previous attempts showed Conky can run under this GNOME Wayland session,
    # but it may not draw reliably as a true desktop widget. Do not force a
    # fragile always-on-top clock over the user's layout.
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
        warn "Skipping forced desktop Conky clock because GNOME Wayland desktop-layer placement is unreliable. Top bar clock remains the safe clock."
        mkdir -p "$HOME/.config/autostart"
        if [[ -f "$CLOCK_DESKTOP" ]]; then
            cp "$CLOCK_DESKTOP" "$BACKUP_DIR/rice-desktop-clock.desktop.before" || true
            sed -i 's/^X-GNOME-Autostart-enabled=.*/X-GNOME-Autostart-enabled=false/' "$CLOCK_DESKTOP" || true
            sed -i 's/^Hidden=.*/Hidden=true/' "$CLOCK_DESKTOP" || true
            log "Disabled previous Conky clock autostart to avoid invisible/background widget clutter."
        fi
        pkill -u "$USER" -f "conky.*rice-clock.conf" >/dev/null 2>&1 || true
        return 0
    fi

    log "Non-Wayland session detected; creating Conky desktop clock."
    sudo pacman -S --needed --noconfirm conky

    mkdir -p "$HOME/.config/conky" "$HOME/.config/autostart"

    cat > "$CLOCK_CONF" <<'EOFCLOCK'
conky.config = {
    update_interval = 1,
    own_window = true,
    own_window_type = 'desktop',
    own_window_transparent = true,
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    double_buffer = true,
    alignment = 'top_middle',
    gap_x = 0,
    gap_y = 30,
    minimum_width = 380,
    maximum_width = 380,
    minimum_height = 90,
    use_xft = true,
    font = 'Noto Sans:size=13',
    xftalpha = 1,
    default_color = 'E8EEF7',
    color1 = '9AD8E6',
    color2 = 'F3C6D3',
    background = true,
    no_buffers = true,
};

conky.text = [[
${alignc}${font Noto Sans:bold:size=28}${color1}${time %I:%M}${font Noto Sans:bold:size=14}${color2} ${time %p}${font}
${alignc}${font Noto Sans:size=12}${color}${time %A, %d %B %Y}${font}
]];
EOFCLOCK

    cat > "$CLOCK_DESKTOP" <<EOFCLK
[Desktop Entry]
Type=Application
Name=Rice Desktop Clock
Comment=Transparent desktop clock widget for the Arch GNOME rice
Exec=/usr/bin/conky --daemonize --config $CLOCK_CONF
X-GNOME-Autostart-enabled=true
Terminal=false
Hidden=false
EOFCLK

    pkill -u "$USER" -f "conky.*rice-clock.conf" >/dev/null 2>&1 || true
    conky --daemonize --config "$CLOCK_CONF" || warn "Conky clock failed to start; leaving clock skipped."
}

final_cleanup_and_verify() {
    log "Running final verification."

    echo "=== Session ===" | tee -a "$LOG"
    echo "USER=$USER" | tee -a "$LOG"
    echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}" | tee -a "$LOG"
    gnome-shell --version | tee -a "$LOG" || true

    echo "=== Fetch ===" | tee -a "$LOG"
    if command -v neofetch >/dev/null 2>&1; then
        echo "neofetch still present: $(command -v neofetch)" | tee -a "$LOG"
    else
        echo "neofetch removed" | tee -a "$LOG"
    fi
    echo "ff-blue=$(command -v ff-blue || echo missing)" | tee -a "$LOG"
    grep -nE 'neofetch|^[[:space:]]*fastfetch\b|alias[[:space:]]+neofetch' "$BASHRC" "$BASH_PROFILE" "$PROFILE" 2>/dev/null | tee -a "$LOG" || true

    echo "=== Theme ===" | tee -a "$LOG"
    echo "GTK=$(gsettings get org.gnome.desktop.interface gtk-theme)" | tee -a "$LOG"
    echo "Shell=$(gsettings get "$USER_THEME_SCHEMA" name 2>/dev/null || echo unavailable)" | tee -a "$LOG"
    echo "Icons=$(gsettings get org.gnome.desktop.interface icon-theme)" | tee -a "$LOG"
    echo "Buttons=$(gsettings get org.gnome.desktop.wm.preferences button-layout)" | tee -a "$LOG"

    echo "=== Keybindings ===" | tee -a "$LOG"
    echo "Super+Tab overview=$(gsettings get org.gnome.shell.keybindings toggle-overview)" | tee -a "$LOG"
    echo "Alt+Tab apps=$(gsettings get org.gnome.desktop.wm.keybindings switch-applications)" | tee -a "$LOG"
    echo "Show desktop=$(gsettings get org.gnome.desktop.wm.keybindings show-desktop)" | tee -a "$LOG"
    echo "Close=$(gsettings get org.gnome.desktop.wm.keybindings close)" | tee -a "$LOG"
    echo "Fullscreen=$(gsettings get org.gnome.desktop.wm.keybindings toggle-fullscreen)" | tee -a "$LOG"

    echo "=== Extensions ===" | tee -a "$LOG"
    gnome-extensions list --enabled | grep -Ei 'user-theme|dash.*dock|hide.*top|hidetopbar|just-perfection' | tee -a "$LOG" || true

    echo "=== Dock favourites ===" | tee -a "$LOG"
    gsettings get org.gnome.shell favorite-apps | tee -a "$LOG"

    echo "=== Dash to Dock ===" | tee -a "$LOG"
    dconf dump /org/gnome/shell/extensions/dash-to-dock/ | tee -a "$LOG" || true

    echo "=== Power ===" | tee -a "$LOG"
    powerprofilesctl get 2>/dev/null | tee -a "$LOG" || true

    echo "=== Clock ===" | tee -a "$LOG"
    pgrep -a -u "$USER" conky | tee -a "$LOG" || echo "no conky clock process active" | tee -a "$LOG"

    log "phase12_complete_rice.sh complete."
    log "Log saved at: $LOG"
    log "Log out and back in once so Dash-to-Dock/Hide-Top-Bar/icon changes reload cleanly."
}

main() {
    require_user_session

    mkdir -p "$BACKUP_DIR"
    touch "$LOG"

    log "Starting final complete rice script."
    log "Backup directory: $BACKUP_DIR"

    backup_path "$BASHRC"
    backup_path "$BASH_PROFILE"
    backup_path "$PROFILE"
    backup_path "$HOME/.config/fastfetch"
    backup_path "$HOME/.config/conky"
    backup_path "$HOME/.config/autostart"
    backup_path "$HOME/.local/share/icons/hicolor"

    dconf dump /org/gnome/shell/ > "$BACKUP_DIR/gnome-shell-before-phase12.ini" 2>/dev/null || true
    dconf dump /org/gnome/shell/extensions/dash-to-dock/ > "$BACKUP_DIR/dash-to-dock-before-phase12.ini" 2>/dev/null || true

    log "Installing only required support packages."
    sudo pacman -S --needed --noconfirm fastfetch curl unzip python gtk3 gnome-shell-extensions >/dev/null

    ensure_clean_terminal_fetch
    apply_theme_lock
    preserve_hide_top_bar_logic
    apply_keybindings
    create_arch_launcher_icon
    apply_dock_intellihide_and_favourites
    safe_desktop_clock_attempt
    final_cleanup_and_verify
}

main "$@"