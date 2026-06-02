#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase8-fastfetch-terminal-toolkit-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase8-${STAMP}"
FASTFETCH_REPO="https://github.com/Vapor55/My-Fastfetch-Dotfiles.git"
FASTFETCH_DIR="$HOME/.config/fastfetch"
BASHRC="$HOME/.bashrc"

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

trap 'fail "Phase 8 failed at line ${LINENO}. Check log: ${LOG}"' ERR

if [[ "$(id -un)" != "ibrahim" ]]; then
    fail "Run this as ibrahim, not root."
fi

log "Starting PHASE 8 - Fastfetch, terminal toolkit, and Neofetch handling."
log "This phase does not change Files/Nautilus transparency, GTK opacity, Shell opacity, wallpaper rotation, fonts, icon theme, dock layout, power mode, or top bar."

mkdir -p "$BACKUP_DIR"

log "Backing up current terminal and fetch-related files."
for path in "$BASHRC" "$HOME/.bash_profile" "$HOME/.config/fastfetch" "$HOME/.config/neofetch"; do
    if [[ -e "$path" || -L "$path" ]]; then
        mkdir -p "$BACKUP_DIR$(dirname "$path")"
        cp -a "$path" "$BACKUP_DIR$path"
        log "Backed up: $path"
    else
        log "Backup skip, missing: $path"
    fi
done

log "Saving current command/package state."
{
    echo "date=$(date)"
    echo "user=$USER"
    echo "session=${XDG_SESSION_TYPE:-unknown}"
    echo "fastfetch=$(command -v fastfetch || true)"
    echo "neofetch=$(command -v neofetch || true)"
    echo "btop=$(command -v btop || true)"
    echo "eza=$(command -v eza || true)"
    echo "bat=$(command -v bat || true)"
    echo "fd=$(command -v fd || true)"
    echo "rg=$(command -v rg || true)"
    echo "fzf=$(command -v fzf || true)"
    echo "zoxide=$(command -v zoxide || true)"
} > "$BACKUP_DIR/command-state-before-phase8.txt"

log "Installing Fastfetch and terminal toolkit packages."
sudo pacman -S --needed --noconfirm fastfetch git btop eza bat fd ripgrep fzf zoxide jq tree ncdu tldr chafa

log "Handling old Neofetch safely."
if command -v neofetch >/dev/null 2>&1; then
    log "Neofetch exists at: $(command -v neofetch)"
    log "I am not uninstalling it. I will route interactive neofetch usage to fastfetch through .bashrc."
else
    log "Neofetch command is not installed. No removal needed."
fi

log "Installing Vapor55 Fastfetch config."
if [[ -d "$FASTFETCH_DIR" || -L "$FASTFETCH_DIR" ]]; then
    mv "$FASTFETCH_DIR" "$BACKUP_DIR/fastfetch-before-replace"
    log "Moved existing Fastfetch config to backup."
fi

if git clone --depth=1 "$FASTFETCH_REPO" "$FASTFETCH_DIR"; then
    log "Cloned Vapor55 Fastfetch config into $FASTFETCH_DIR"
    rm -rf "$FASTFETCH_DIR/.git"
else
    warn "Could not clone Vapor55 config. Creating fallback MacTahoe-style Fastfetch config."
    mkdir -p "$FASTFETCH_DIR"
    cat > "$FASTFETCH_DIR/config.jsonc" <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "builtin",
    "source": "arch",
    "color": {
      "1": "blue",
      "2": "cyan"
    },
    "padding": {
      "top": 1,
      "right": 2
    }
  },
  "display": {
    "separator": "    ",
    "key": {
      "width": 12
    }
  },
  "modules": [
    "title",
    "separator",
    "os",
    "host",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "de",
    "wm",
    "wmtheme",
    "theme",
    "icons",
    "font",
    "terminal",
    "cpu",
    "gpu",
    "memory",
    "disk",
    "battery",
    "poweradapter",
    "locale",
    "break",
    "colors"
  ]
}
EOF
fi

log "Testing Fastfetch config."
fastfetch --show-errors | tee "$BACKUP_DIR/fastfetch-test-output.txt" >/dev/null || warn "Fastfetch ran with warnings. We will inspect the log/output."

log "Updating .bashrc with safe interactive-only terminal polish block."
touch "$BASHRC"

START_MARK="# >>> phase8-rice-terminal-toolkit >>>"
END_MARK="# <<< phase8-rice-terminal-toolkit <<<"

if grep -qF "$START_MARK" "$BASHRC"; then
    log "Existing Phase 8 block found. Replacing it."
        $0 == end {skip=0; next}
        skip != 1 {print}
    ' "$BASHRC" > "$BASHRC.tmp" '
    mv "$BASHRC.tmp" "$BASHRC"
fi

cat >> "$BASHRC" << 'EOFF'
# >>> phase8-rice-terminal-toolkit >>>
# Interactive terminal polish for the Arch/macOS-style rice.
# Safe guard: this block runs only in interactive shells.
case $- in
    *i*) ;;
    *) return ;;
esac

# Fastfetch startup banner. Disable temporarily with: touch ~/.no_fastfetch
if command -v fastfetch >/dev/null 2>&1 && [[ ! -f "$HOME/.no_fastfetch" ]]; then
    fastfetch
fi

# Neofetch compatibility: keep old muscle memory, but use the maintained Fastfetch backend.
if command -v fastfetch >/dev/null 2>&1; then
    alias neofetch='fastfetch'
    alias ff='fastfetch'
fi

# Modern terminal tools.
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

if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

# Useful short commands.
alias cls='clear'
alias please='sudo'
alias ports='ss -tulpen'
alias myip='ip -brief addr'
alias weather='curl -s wttr.in'
# <<< phase8-rice-terminal-toolkit <<<
EOFF

log "Verification."
echo "Fastfetch version:" | tee -a "$LOG"
fastfetch --version | tee -a "$LOG" || true

echo "Command paths:" | tee -a "$LOG"
for cmd in fastfetch neofetch btop eza bat fd rg fzf zoxide jq tree ncdu tldr chafa; do
    printf "%-12s %s\n" "$cmd" "$(command -v "$cmd" || echo missing)" | tee -a "$LOG"
done

echo "Package check:" | tee -a "$LOG"
pacman -Q fastfetch btop eza bat fd ripgrep fzf zoxide jq tree ncdu tldr chafa | tee -a "$LOG"

echo "Fastfetch config files:" | tee -a "$LOG"
find "$FASTFETCH_DIR" -maxdepth 2 -type f | sort | tee -a "$LOG"

echo "GNOME/rice state preserved:" | tee -a "$LOG"
echo "GTK: $(gsettings get org.gnome.desktop.interface gtk-theme)" | tee -a "$LOG"
echo "Shell: $(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Icons: $(gsettings get org.gnome.desktop.interface icon-theme)" | tee -a "$LOG"
echo "Buttons: $(gsettings get org.gnome.desktop.wm.preferences button-layout)" | tee -a "$LOG"
echo "Super+Tab: $(gsettings get org.gnome.shell.keybindings toggle-overview)" | tee -a "$LOG"
echo "Power profile: $(powerprofilesctl get 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Enabled extensions:" | tee -a "$LOG"
gnome-extensions list --enabled | grep -Ei 'user-theme|dash.*dock' | tee -a "$LOG" || true

log "PHASE 8 complete."
log "Close Terminal and open a new Terminal. Fastfetch should appear automatically."
log "If you want to temporarily stop Fastfetch on terminal startup, run: touch ~/.no_fastfetch"
log "If you want it back, run: rm ~/.no_fastfetch"
log "Log saved at: $LOG"
