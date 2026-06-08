#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase9-fetch-cleanup-blue-arch-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase9-${STAMP}"

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

trap 'fail "Phase 9 failed at line ${LINENO}. Check log: ${LOG}"' ERR

backup_file() {
    local file="$1"

    if [[ -e "$file" || -L "$file" ]]; then
        local rel="${file#$HOME/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp "$file" "$BACKUP_DIR/$rel"
        log "Backed up: $file"
    else
        log "Backup skip, missing: $file"
    fi
}

remove_marked_block() {
    local file="$1"
    local start="$2"
    local end="$3"

    if [[ -n "${NEOFETCH_PKG:-}" ]]; then
        log "Neofetch binary is owned by package: $NEOFETCH_PKG"
        sudo pacman -Rns --noconfirm "$NEOFETCH_PKG" || warn "Could not remove $NEOFETCH_PKG. I will still prevent Neofetch from auto-starting."
    else
        warn "Neofetch binary exists but is not package-owned: $NEOFETCH_BIN"
    fi
}
hash -r || true

log "Creating blue Arch Fastfetch wrapper."
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/ff-blue" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/fastfetch --logo arch --logo-color-1 blue --logo-color-2 blue --logo-color-3 blue "$@"
EOF

chmod +x "$HOME/.local/bin/ff-blue"

log "Adding final clean interactive Bash block."
cat >> "$BASHRC" <<'EOF'

# >>> phase9-rice-terminal-final >>>
# Final interactive terminal polish for the Arch/macOS-style GNOME rice.
case $- in
    *i*) ;;
    *) return ;;
esac

export PATH="$HOME/.local/bin:$PATH"

# Fastfetch only. Neofetch has been removed/disabled.
alias fastfetch='ff-blue'
alias ff='ff-blue'

if [[ -z "${RICE_FASTFETCH_SHOWN:-}" && ! -f "$HOME/.no_fastfetch" ]]; then
    export RICE_FASTFETCH_SHOWN=1
    ff-blue
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

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

alias cls='clear'
alias please='sudo'
alias ports='ss -tulpen'
alias myip='ip -brief addr'
# <<< phase9-rice-terminal-final <<<
EOF

log "Checking Bash syntax."
bash -n "$BASHRC"
[[ -f "$BASH_PROFILE" ]] && bash -n "$BASH_PROFILE" || true
[[ -f "$PROFILE" ]] && bash -n "$PROFILE" || true

log "Testing blue Fastfetch wrapper."
"$HOME/.local/bin/ff-blue" --version | tee -a "$LOG"
"$HOME/.local/bin/ff-blue" --show-errors > "$BACKUP_DIR/ff-blue-test-output.txt" || warn "ff-blue produced warnings. Check $BACKUP_DIR/ff-blue-test-output.txt"

log "Verification."
echo "Neofetch command after cleanup:" | tee -a "$LOG"
if command -v neofetch >/dev/null 2>&1; then
    echo "still-present: $(command -v neofetch)" | tee -a "$LOG"
else
    echo "removed" | tee -a "$LOG"
fi

echo "Fastfetch command:" | tee -a "$LOG"
command -v fastfetch | tee -a "$LOG"

echo "Blue wrapper:" | tee -a "$LOG"
command -v ff-blue | tee -a "$LOG"

echo "Remaining fetch startup references:" | tee -a "$LOG"
grep -nE '^[[:space:]]*(neofetch|fastfetch|command[[:space:]]+neofetch|command[[:space:]]+fastfetch)\b|neofetch' "$BASHRC" "$BASH_PROFILE" "$PROFILE" 2>/dev/null | tee -a "$LOG" || true

echo "Toolkit commands:" | tee -a "$LOG"
for cmd in fastfetch ff-blue btop eza bat fd rg fzf zoxide jq tree ncdu tldr chafa; do
    printf "%-12s %s\n" "$cmd" "$(command -v "$cmd" || echo missing)" | tee -a "$LOG"
done

echo "GNOME/rice state preserved:" | tee -a "$LOG"
echo "GTK: $(gsettings get org.gnome.desktop.interface gtk-theme)" | tee -a "$LOG"
echo "Shell: $(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Icons: $(gsettings get org.gnome.desktop.interface icon-theme)" | tee -a "$LOG"
echo "Buttons: $(gsettings get org.gnome.desktop.wm.preferences button-layout)" | tee -a "$LOG"
echo "Super+Tab: $(gsettings get org.gnome.shell.keybindings toggle-overview)" | tee -a "$LOG"
echo "Power profile: $(powerprofilesctl get 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Enabled extensions:" | tee -a "$LOG"
gnome-extensions list --enabled | grep -Ei 'user-theme|dash.*dock' | tee -a "$LOG" || true

log "PHASE 9 complete."
log "Close every Terminal window, open a fresh Terminal, and only the blue Arch Fastfetch should appear."
log "Log saved at: $LOG"
