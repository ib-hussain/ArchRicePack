#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# phase15_improved_final_three_fixes.sh
#
# Final focused repair for the remaining GNOME rice problems:
#
#   1. Force Arch icon for Dash-to-Dock Show Applications button.
#      - Local icon-theme override.
#      - Papirus/Rice-Papirus override.
#      - Dedicated GNOME Shell extension that patches the Show Apps icon actor.
#
#   2. Fix Super key.
#      - Super alone opens GNOME Overview through Mutter overlay-key.
#      - Removes any bad custom keybinding that hijacks Super to Settings.
#      - Keeps Super+A for app grid.
#      - Keeps Super+S and Super+Tab for overview/search behaviour.
#
#   3. Add Alt+Ctrl+T terminal shortcut.
#      - Correct GNOME custom-keybinding registration.
#      - Also keeps Super+Return as terminal shortcut.
#
# Preserved:
#   - MacTahoe-Dark-blue GTK/Shell theme.
#   - Files/Nautilus transparency.
#   - Dash-to-Dock reveal behaviour.
#   - Right-side buttons: minimize,maximize,close.
#   - Google Chrome pinning.
#   - Open with Code in Nautilus.
#   - Blue Arch Fastfetch startup.
#   - Power modes.
###############################################################################

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase15-improved-final-three-fixes-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase15-improved-${STAMP}"

USER_NAME="$(id -un)"

DASH_UUID="dash-to-dock@micxgx.gmail.com"
USER_THEME_UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
HIDE_TOP_BAR_UUID="hidetopbar@mathieu.bidon.ca"
ARCH_ICON_EXT_UUID="rice-arch-showapps@local"

DASH_SCHEMA="org.gnome.shell.extensions.dash-to-dock"
USER_THEME_SCHEMA="org.gnome.shell.extensions.user-theme"

LOCAL_ICON_THEME="$HOME/.local/share/icons/Rice-Papirus"
ARCH_ICON_SRC="$BACKUP_DIR/arch-show-apps.svg"
ARCH_ICON_EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$ARCH_ICON_EXT_UUID"

TASK_WRAPPER="$HOME/.local/bin/rice-task-manager"
FF_BLUE="$HOME/.local/bin/ff-blue"

BASHRC="$HOME/.bashrc"
BASH_PROFILE="$HOME/.bash_profile"
PROFILE="$HOME/.profile"

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
    fail "Phase 15 improved failed at line $1. Check log: $LOG"
}

trap 'on_error ${LINENO}' ERR

require_session() {
    if [[ "$EUID" -eq 0 ]]; then
        fail "Run this as ibrahim, not root."
    fi

    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
        fail "GNOME DBus/session variables are missing. Log into GNOME and run this from GNOME Terminal."
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
            log "gsettings set $schema $key $value"
        else
            warn "Could not set $schema $key"
        fi
    else
        warn "Missing gsettings key, skipped: $schema $key"
    fi
}

dconf_write() {
    local path="$1"
    local value="$2"

    if dconf write "$path" "$value" 2>>"$LOG"; then
        log "dconf write $path $value"
    else
        warn "Could not write dconf key: $path"
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

install_required_packages() {
    log "Installing required support packages."

    sudo pacman -S --needed --noconfirm \
        papirus-icon-theme gtk3 gtk-update-icon-cache \
        gnome-shell-extensions gnome-system-monitor \
        python python-gobject fastfetch btop eza bat fd ripgrep fzf zoxide jq tree ncdu tldr chafa >/dev/null
}

create_arch_svg() {
    log "Creating clean Arch SVG asset."

    mkdir -p "$BACKUP_DIR"

    cat > "$ARCH_ICON_SRC" <<'EOFSVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="56" fill="#1793D1"/>
  <path fill="#ffffff" d="M128 34c-9.5 23.2-18.2 44.5-27.6 66.4 10.1 10.8 22.7 20.1 38.2 27.8-16.8-4.3-30.3-10.6-41.2-19.3-18.1 39-39.9 83.2-63.4 123.1 23.4-13.3 42.5-21.8 60.8-25.8-.6-3.4-.9-7-.8-10.6.6-25.4 13.7-44.8 29.3-43.5 15.7 1.3 27.9 23 27.3 48.4-.1 2.4-.3 4.8-.6 7.1 17.8 4.2 36.6 12.7 59.9 25.9-7.7-14.2-14.8-27.4-21.7-40.4-12.7-9.8-27.8-19.8-51-31.8 16.8 4.3 29.7 9.4 39.9 15.2C159.9 141.3 142.6 75.9 128 34z"/>
</svg>
EOFSVG
}

install_rice_icon_theme() {
    log "Installing Rice-Papirus icon theme with Arch overrides."

    create_arch_svg

    rm -rf "$LOCAL_ICON_THEME"

    mkdir -p \
        "$LOCAL_ICON_THEME/scalable/actions" \
        "$LOCAL_ICON_THEME/scalable/apps" \
        "$LOCAL_ICON_THEME/scalable/categories" \
        "$LOCAL_ICON_THEME/symbolic/actions" \
        "$LOCAL_ICON_THEME/symbolic/apps" \
        "$LOCAL_ICON_THEME/symbolic/categories" \
        "$LOCAL_ICON_THEME/16x16/actions" \
        "$LOCAL_ICON_THEME/16x16/apps" \
        "$LOCAL_ICON_THEME/22x22/actions" \
        "$LOCAL_ICON_THEME/22x22/apps" \
        "$LOCAL_ICON_THEME/24x24/actions" \
        "$LOCAL_ICON_THEME/24x24/apps" \
        "$LOCAL_ICON_THEME/32x32/actions" \
        "$LOCAL_ICON_THEME/32x32/apps" \
        "$LOCAL_ICON_THEME/48x48/actions" \
        "$LOCAL_ICON_THEME/48x48/apps" \
        "$LOCAL_ICON_THEME/64x64/actions" \
        "$LOCAL_ICON_THEME/64x64/apps"

    cat > "$LOCAL_ICON_THEME/index.theme" <<'EOFTHEME'
[Icon Theme]
Name=Rice-Papirus
Comment=Papirus-Dark with local Arch launcher overrides
Inherits=Papirus-Dark,Papirus,Adwaita,hicolor
Directories=scalable/actions,scalable/apps,scalable/categories,symbolic/actions,symbolic/apps,symbolic/categories,16x16/actions,16x16/apps,22x22/actions,22x22/apps,24x24/actions,24x24/apps,32x32/actions,32x32/apps,48x48/actions,48x48/apps,64x64/actions,64x64/apps

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

[16x16/actions]
Size=16
Type=Fixed
Context=Actions

[16x16/apps]
Size=16
Type=Fixed
Context=Applications

[22x22/actions]
Size=22
Type=Fixed
Context=Actions

[22x22/apps]
Size=22
Type=Fixed
Context=Applications

[24x24/actions]
Size=24
Type=Fixed
Context=Actions

[24x24/apps]
Size=24
Type=Fixed
Context=Applications

[32x32/actions]
Size=32
Type=Fixed
Context=Actions

[32x32/apps]
Size=32
Type=Fixed
Context=Applications

[48x48/actions]
Size=48
Type=Fixed
Context=Actions

[48x48/apps]
Size=48
Type=Fixed
Context=Applications

[64x64/actions]
Size=64
Type=Fixed
Context=Actions

[64x64/apps]
Size=64
Type=Fixed
Context=Applications
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

    local dirs=(
        "$LOCAL_ICON_THEME/scalable/actions"
        "$LOCAL_ICON_THEME/scalable/apps"
        "$LOCAL_ICON_THEME/scalable/categories"
        "$LOCAL_ICON_THEME/symbolic/actions"
        "$LOCAL_ICON_THEME/symbolic/apps"
        "$LOCAL_ICON_THEME/symbolic/categories"
        "$LOCAL_ICON_THEME/16x16/actions"
        "$LOCAL_ICON_THEME/16x16/apps"
        "$LOCAL_ICON_THEME/22x22/actions"
        "$LOCAL_ICON_THEME/22x22/apps"
        "$LOCAL_ICON_THEME/24x24/actions"
        "$LOCAL_ICON_THEME/24x24/apps"
        "$LOCAL_ICON_THEME/32x32/actions"
        "$LOCAL_ICON_THEME/32x32/apps"
        "$LOCAL_ICON_THEME/48x48/actions"
        "$LOCAL_ICON_THEME/48x48/apps"
        "$LOCAL_ICON_THEME/64x64/actions"
        "$LOCAL_ICON_THEME/64x64/apps"
    )

    local icon dir
    for icon in "${icon_names[@]}"; do
        for dir in "${dirs[@]}"; do
            cp "$ARCH_ICON_SRC" "$dir/$icon"
        done
    done

    gtk-update-icon-cache -f -t "$LOCAL_ICON_THEME" >/dev/null 2>&1 || warn "Local icon cache update failed; logout/login may still load it."

    gsettings set org.gnome.desktop.interface icon-theme 'Rice-Papirus'
    log "Icon theme set to Rice-Papirus."
}

install_arch_showapps_extension() {
    log "Installing GNOME Shell extension to force Arch Show Apps icon."

    rm -rf "$ARCH_ICON_EXT_DIR"
    mkdir -p "$ARCH_ICON_EXT_DIR/icons"

    cp "$ARCH_ICON_SRC" "$ARCH_ICON_EXT_DIR/icons/arch-show-apps.svg"

    cat > "$ARCH_ICON_EXT_DIR/metadata.json" <<EOFJSON
{
  "uuid": "$ARCH_ICON_EXT_UUID",
  "name": "Rice Arch Show Apps Icon",
  "description": "Forces Dash-to-Dock and GNOME Shell Show Applications icon to use an Arch Linux icon.",
  "shell-version": ["50"],
  "version": 1
}
EOFJSON

    cat > "$ARCH_ICON_EXT_DIR/stylesheet.css" <<'EOFCSS'
#dashtodockContainer .show-apps .overview-icon,
#dashtodockContainer .show-apps .show-apps-icon,
#dash .show-apps .overview-icon,
#dash .show-apps .show-apps-icon,
.show-apps .overview-icon,
.show-apps .show-apps-icon {
    background-image: url("icons/arch-show-apps.svg");
    background-size: contain;
    background-position: center;
    background-repeat: no-repeat;
}
EOFCSS

    cat > "$ARCH_ICON_EXT_DIR/extension.js" <<'EOFJS'
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class RiceArchShowAppsIconExtension extends Extension {
    enable() {
        this._timeoutId = 0;
        this._iconFile = this.dir.get_child('icons').get_child('arch-show-apps.svg');
        this._gicon = new Gio.FileIcon({file: this._iconFile});

        this._patchAll();

        this._timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 750, () => {
            this._patchAll();
            return GLib.SOURCE_CONTINUE;
        });
    }

    disable() {
        if (this._timeoutId) {
            GLib.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
    }

    _patchAll() {
        try {
            this._walk(Main.uiGroup);
        } catch (e) {
        }

        try {
            this._walk(Main.layoutManager.uiGroup);
        } catch (e) {
        }
    }

    _walk(actor) {
        if (!actor)
            return;

        this._maybePatch(actor);

        let children = [];
        try {
            if (typeof actor.get_children === 'function')
                children = actor.get_children();
        } catch (e) {
            children = [];
        }

        for (const child of children)
            this._walk(child);
    }

    _styleClass(actor) {
        try {
            if (typeof actor.get_style_class_name === 'function')
                return actor.get_style_class_name() || '';
        } catch (e) {
        }

        return '';
    }

    _hasShowAppsParent(actor) {
        let current = actor;

        for (let i = 0; i < 7 && current; i++) {
            const klass = this._styleClass(current).toLowerCase();

            if (klass.includes('show-apps') || klass.includes('showapps'))
                return true;

            try {
                current = current.get_parent();
            } catch (e) {
                current = null;
            }
        }

        return false;
    }

    _iconName(actor) {
        try {
            if (typeof actor.get_icon_name === 'function')
                return actor.get_icon_name() || '';
        } catch (e) {
        }

        try {
            return actor.icon_name || '';
        } catch (e) {
            return '';
        }
    }

    _maybePatch(actor) {
        if (!(actor instanceof St.Icon))
            return;

        const name = this._iconName(actor).toLowerCase();
        const parentMatch = this._hasShowAppsParent(actor);

        const nameMatch =
            name.includes('view-app-grid') ||
            name.includes('applications-all') ||
            name.includes('applications-system') ||
            name.includes('start-here');

        if (!parentMatch && !nameMatch)
            return;

        try {
            actor.set_gicon(this._gicon);
        } catch (e) {
            try {
                actor.gicon = this._gicon;
            } catch (e2) {
            }
        }

        try {
            actor.set_icon_size(48);
        } catch (e) {
        }
    }
}
EOFJS

    log "Enabling Rice Arch Show Apps extension."

    if gnome-extensions list | grep -qx "$ARCH_ICON_EXT_UUID"; then
        gnome-extensions enable "$ARCH_ICON_EXT_UUID" || warn "Extension installed but needs logout/login before enabling."
    else
        warn "Extension files installed, but GNOME Shell has not indexed it yet. It should appear after logout/login."
    fi
}

fix_super_key_and_keybindings() {
    log "Fixing Super key and keybindings."

    python - <<'PY'
import ast
import subprocess

MEDIA_SCHEMA = "org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_BASE = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
CUSTOM_SCHEMA_PREFIX = "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"

def run(cmd, check=False):
    return subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check)

def get(cmd, default=""):
    result = run(cmd)
    return result.stdout.strip() if result.returncode == 0 else default

def gv_string(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"

raw = get(["gsettings", "get", MEDIA_SCHEMA, "custom-keybindings"], "[]")
raw = raw.replace("@as ", "")

try:
    paths = ast.literal_eval(raw)
    if not isinstance(paths, list):
        paths = []
except Exception:
    paths = []

kept = []

for path in paths:
    schema = CUSTOM_SCHEMA_PREFIX + path
    binding = get(["gsettings", "get", schema, "binding"], "''").strip("'").strip('"')
    command = get(["gsettings", "get", schema, "command"], "''").strip("'").strip('"').lower()
    name = get(["gsettings", "get", schema, "name"], "''").strip("'").strip('"').lower()

    bad_single_super = binding in {"<Super>", "Super", "Super_L", "<Super_L>"}
    bad_settings = ("settings" in command or "gnome-control-center" in command or "control-center" in command) and "super" in binding.lower()

    if bad_single_super or bad_settings:
        continue

    kept.append(path)

required = {
    CUSTOM_BASE + "rice-terminal-open/": {
        "name": "Open Terminal",
        "command": "gnome-terminal",
        "binding": "<Control><Alt>t",
    },
    CUSTOM_BASE + "rice-terminal-super-return/": {
        "name": "Open Terminal Super Return",
        "command": "gnome-terminal",
        "binding": "<Super>Return",
    },
}

for path in required:
    if path not in kept:
        kept.append(path)

value = "[" + ", ".join("'" + p + "'" for p in kept) + "]"
run(["gsettings", "set", MEDIA_SCHEMA, "custom-keybindings", value], check=True)

for path, data in required.items():
    schema = CUSTOM_SCHEMA_PREFIX + path
    run(["gsettings", "set", schema, "name", gv_string(data["name"])], check=True)
    run(["gsettings", "set", schema, "command", gv_string(data["command"])], check=True)
    run(["gsettings", "set", schema, "binding", gv_string(data["binding"])], check=True)

print(value)
PY

    # Correct way to make the single Super key open Overview in GNOME:
    # Mutter owns the single overlay key. Do not put ['<Super>'] in toggle-overview.
    gs_set "org.gnome.mutter" "overlay-key" "Super_L"

    # Keep working shortcuts.
    gs_set "org.gnome.shell.keybindings" "toggle-overview" "['<Super>s', '<Super>Tab']"
    gs_set "org.gnome.shell.keybindings" "toggle-application-view" "['<Super>a']"

    gs_set "org.gnome.desktop.wm.keybindings" "switch-applications" "['<Alt>Tab']"
    gs_set "org.gnome.desktop.wm.keybindings" "switch-applications-backward" "['<Shift><Alt>Tab']"
    gs_set "org.gnome.desktop.wm.keybindings" "show-desktop" "['<Super>d']"
    gs_set "org.gnome.desktop.wm.keybindings" "close" "['<Super>q', '<Alt>F4']"
    gs_set "org.gnome.desktop.wm.keybindings" "toggle-fullscreen" "['<Super>f']"
    gs_set "org.gnome.desktop.wm.keybindings" "maximize" "['<Super>Up']"
    gs_set "org.gnome.desktop.wm.keybindings" "unmaximize" "['<Super>Down']"
}

lock_theme_and_dock() {
    log "Re-locking stable theme and dock settings."

    gnome-extensions enable "$USER_THEME_UUID" >/dev/null 2>&1 || true
    gnome-extensions enable "$HIDE_TOP_BAR_UUID" >/dev/null 2>&1 || true
    gnome-extensions enable "$DASH_UUID" >/dev/null 2>&1 || true

    gs_set "org.gnome.desktop.interface" "gtk-theme" "MacTahoe-Dark-blue"
    gs_set "org.gnome.desktop.interface" "color-scheme" "prefer-dark"
    gs_set "org.gnome.desktop.wm.preferences" "button-layout" ":minimize,maximize,close"

    if schema_exists "$USER_THEME_SCHEMA"; then
        gs_set "$USER_THEME_SCHEMA" "name" "MacTahoe-Dark-blue"
    fi

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

    python - <<'PY'
from pathlib import Path
import subprocess

dirs = [Path.home() / ".local/share/applications", Path("/usr/share/applications")]

def exists(name):
    return any((d / name).exists() for d in dirs)

def pick(*names):
    for name in names:
        if exists(name):
            return name
    return None

files = pick("org.gnome.Nautilus.desktop", "nautilus.desktop")
code = pick("code.desktop", "visual-studio-code.desktop", "com.visualstudio.code.desktop")
terminal = pick("org.gnome.Terminal.desktop", "gnome-terminal.desktop")
browser = pick("google-chrome.desktop", "google-chrome-stable.desktop", "firefox.desktop", "org.mozilla.firefox.desktop")

apps = [x for x in [files, code, terminal, browser] if x]
value = "[" + ", ".join("'" + x + "'" for x in apps) + "]"

subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", value], check=True)
print(value)
PY
}

restart_relevant_components() {
    log "Reloading user-visible components where possible."

    if gnome-extensions list | grep -qx "$DASH_UUID"; then
        gnome-extensions disable "$DASH_UUID" >/dev/null 2>&1 || true
        sleep 1
        gnome-extensions enable "$DASH_UUID" >/dev/null 2>&1 || true
    fi

    if gnome-extensions list | grep -qx "$ARCH_ICON_EXT_UUID"; then
        gnome-extensions disable "$ARCH_ICON_EXT_UUID" >/dev/null 2>&1 || true
        sleep 1
        gnome-extensions enable "$ARCH_ICON_EXT_UUID" >/dev/null 2>&1 || true
    fi

    nautilus -q >/dev/null 2>&1 || true
}

verify() {
    log "Final verification."

    {
        echo "=== Session ==="
        echo "USER=$USER_NAME"
        echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}"
        gnome-shell --version || true

        echo
        echo "=== Theme ==="
        echo "GTK=$(gsettings get org.gnome.desktop.interface gtk-theme)"
        echo "Shell=$(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)"
        echo "Icons=$(gsettings get org.gnome.desktop.interface icon-theme)"
        echo "Buttons=$(gsettings get org.gnome.desktop.wm.preferences button-layout)"

        echo
        echo "=== Super and Keybindings ==="
        echo "Overlay=$(gsettings get org.gnome.mutter overlay-key 2>/dev/null || echo unavailable)"
        echo "Overview=$(gsettings get org.gnome.shell.keybindings toggle-overview 2>/dev/null || echo unavailable)"
        echo "Apps=$(gsettings get org.gnome.shell.keybindings toggle-application-view 2>/dev/null || echo unavailable)"
        echo "Custom=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo unavailable)"

        echo
        echo "=== Dock ==="
        gsettings get org.gnome.shell favorite-apps
        dconf dump /org/gnome/shell/extensions/dash-to-dock/ || true

        echo
        echo "=== Extensions ==="
        gnome-extensions list --enabled | grep -Ei 'dash.*dock|user-theme|hidetopbar|rice-arch' || true
        gnome-extensions list | grep -Ei 'rice-arch' || true

        echo
        echo "=== Icon files ==="
        find "$LOCAL_ICON_THEME" -type f \( -name 'view-app-grid*' -o -name 'applications-all*' -o -name 'start-here*' \) | sort | head -80

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

    log "Phase 15 improved complete."
    log "Log saved at: $LOG"
    log "IMPORTANT: log out and back in once. A full reboot is better for the Show Applications icon because GNOME Shell caches symbolic icons aggressively."
}

main() {
    require_session

    mkdir -p "$BACKUP_DIR"
    touch "$LOG"

    log "Starting improved Phase 15 final three fixes."
    log "Backup directory: $BACKUP_DIR"

    backup_path "$HOME/.local/share/icons"
    backup_path "$HOME/.local/share/gnome-shell/extensions/$ARCH_ICON_EXT_UUID"
    backup_path "$HOME/.config/dconf"
    backup_path "$BASHRC"
    backup_path "$BASH_PROFILE"
    backup_path "$PROFILE"

    dconf dump /org/gnome/shell/ > "$BACKUP_DIR/gnome-shell-before-phase15-improved.ini" 2>/dev/null || true
    dconf dump /org/gnome/shell/extensions/dash-to-dock/ > "$BACKUP_DIR/dash-to-dock-before-phase15-improved.ini" 2>/dev/null || true
    dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > "$BACKUP_DIR/media-keys-before-phase15-improved.ini" 2>/dev/null || true

    install_required_packages
    install_rice_icon_theme
    install_arch_showapps_extension
    fix_super_key_and_keybindings
    lock_theme_and_dock
    restart_relevant_components
    verify
}

main "$@"