alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
#admin shortcuts
alias root='sudo -i'
alias cls='clear'
alias systemctl='sudo systemctl'
alias turnoff='sudo poweroff'
alias update='sudo pacman -Syu'
alias pacman='sudo pacman'
alias remove='sudo pacman -Rns'
alias install='sudo pacman -S'
alias install-y='sudo pacman -S --needed --noconfirm'
alias please='sudo'
alias ports='ss -tulpen'
alias myip='ip -brief addr'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init - bash)"
fi

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

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi
