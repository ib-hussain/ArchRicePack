#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Restoring Fastfetch and terminal toolkit."

mkdir -p "$HOME/.config/fastfetch" "$HOME/.local/bin"
copy_dir_contents "$REPO_ROOT/configs/fastfetch" "$HOME/.config/fastfetch"

cat > "$HOME/.local/bin/ff-blue" <<'EOFF'
#!/usr/bin/env bash
exec /usr/bin/fastfetch --logo arch --logo-color-1 blue --logo-color-2 blue --logo-color-3 blue "$@"
EOFF
chmod +x "$HOME/.local/bin/ff-blue"

touch "$HOME/.bashrc"

python - "$HOME/.bashrc" <<'PY'
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
    ("# >>> arch-rice-terminal-final >>>", "# <<< arch-rice-terminal-final <<<"),
]

out = []
skip = False
end = None

for line in lines:
    s = line.strip()

    if skip:
        if s == end:
            skip = False
            end = None
        continue

    started = False
    for a, b in blocks:
        if s == a:
            skip = True
            end = b
            started = True
            break

    if started:
        continue

    if "neofetch" in s:
        continue

    out.append(line)

path.write_text("\n".join(out).rstrip() + "\n")
PY

cat >> "$HOME/.bashrc" <<'EOFBASH'

# >>> arch-rice-terminal-final >>>
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
# <<< arch-rice-terminal-final <<<
EOFBASH

bash -n "$HOME/.bashrc"
