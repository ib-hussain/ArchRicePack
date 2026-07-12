#!/bin/bash
# ==========================================================
# CHROOT CONFIGURATION
# ==========================================================
# arch-chroot /mnt
set -euo pipefail
USER_NAME="ibrahim"
HOST_NAME="ibLaptop"
TIMEZONE="Asia/Karachi"
LOCALE="en_US.UTF-8"
PYTHON_VERSION="3.12.7"
# ==========================================================
# TIMEZONE AND CLOCK
# ==========================================================
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc
# ==========================================================
# LOCALE GENERATION
# ==========================================================
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
# ==========================================================
# HOSTNAME
# ==========================================================
echo "$HOST_NAME" > /etc/hostname
cat >> /etc/hosts <<EOF
127.0.1.1   ${HOST_NAME}.localdomain ${HOST_NAME}
EOF
# ==========================================================
# ROOT PASSWORD
# ==========================================================
echo "Set root password:"
passwd
# ==========================================================
# ESSENTIAL SYSTEM TOOLS
# ==========================================================
pacman -S --needed --noconfirm sudo nano git base-devel
# ==========================================================
# USER SETUP
# ==========================================================
useradd -m -G wheel,video,audio,storage,optical,input "$USER_NAME"
echo "Set password for ${USER_NAME}:"
passwd "$USER_NAME"
# Full admin access through passwordless sudo.
# This is safer than making ibrahim UID 0.
cat > "/etc/sudoers.d/${USER_NAME}" <<EOF
${USER_NAME} ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 440 "/etc/sudoers.d/${USER_NAME}"
chown "$USER_NAME:$USER_NAME" "/home/${USER_NAME}/.bashrc"
# ==========================================================
# PYENV + PYTHON 3.12.7
# ==========================================================
pacman -S --needed --noconfirm pyenv openssl zlib xz bzip2 libffi readline sqlite tk ncurses curl
cp configs/.bashrc /home/${USER_NAME}/.bashrc
cp configs/.bash_profile /home/${USER_NAME}/.bash_profile
chown "$USER_NAME:$USER_NAME" "/home/${USER_NAME}/.bashrc" "/home/${USER_NAME}/.bash_profile"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv install -s ${PYTHON_VERSION}"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv global ${PYTHON_VERSION}"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv rehash"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv exec python --version"

# 00-common.sh
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
log() {
    echo "[INFO] $*" | tee -a "$LOG_FILE"
}
warn() {
    echo "[WARN] $*" | tee -a "$LOG_FILE"
}
fail() {
    echo "[ERROR] $*" | tee -a "$LOG_FILE"
    exit 1
}
copy_dir_contents() {
    local src="$1"
    local dest="$2"
    if [[ -d "$src" ]]; then
        mkdir -p "$dest"
        cp -r "$src"/. "$dest"/
        log "Copied $src -> $dest"
    else
        warn "Directory missing, skipped: $src"
    fi
}
copy_file() {
    local src="$1"
    local dest="$2"
    if [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        log "Copied $src -> $dest"
    else
        warn "File missing, skipped: $src"
    fi
}
install_pacman_package() {
    local pkg="$1"
    [[ -n "$pkg" ]] || return 0
    sudo pacman -S --needed --noconfirm "$pkg" || warn "pacman failed for package: $pkg"
}
# 01-install-packages.sh
log "Installing pacman packages."
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
    install_pacman_package "$pkg"
done < "$REPO_ROOT/packages/WSL-pacman.txt"
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
    install_aur_package "$pkg"
done < "$REPO_ROOT/packages/rice-aur-core.txt"
# 02-restore-themes-and-configs.sh
mkdir -p "$HOME/.themes" "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/icons"
copy_dir_contents "$REPO_ROOT/configs/local-bin" "$HOME/.local/bin"
chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
if [[ -f "$REPO_ROOT/configs/.bashrc" ]]; then
    cp -a "$REPO_ROOT/configs/.bashrc" "$HOME/.bashrc"
    log "Restored .bashrc"
    cp -a "$REPO_ROOT/configs/.bash_profile" "$HOME/.bash_profile"
    log "Restored .bash_profile"
fi
cat > "$HOME/.local/bin/ff-blue" <<'EOFF'
#!/usr/bin/env bash
exec /usr/bin/fastfetch --logo arch --logo-color-1 blue --logo-color-2 blue --logo-color-3 blue "$@"
EOFF
chmod +x "$HOME/.local/bin/ff-blue"
# 03-setup-terminal.sh
log "Restoring Fastfetch and terminal toolkit."
mkdir -p "$HOME/.config/fastfetch" "$HOME/.local/bin"
copy_dir_contents "$REPO_ROOT/configs/fastfetch" "$HOME/.config/fastfetch"
cat "$REPO_ROOT/configs/local-bin/ff-blue" > "$HOME/.local/bin/ff-blue" 
chmod +x "$HOME/.local/bin/ff-blue"
bash -n "$HOME/.bashrc"
# 10-setup-local-ai-ollama-openwebui.sh
log "Setting up Ollama + Open WebUI."
install_pacman_package ollama
# install_pacman_package xdg-utils
# install_pacman_package imagemagick
log "Configuring Ollama to listen on 0.0.0.0 so Openwebui can reach it."
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf <<'EOF' >/dev/null
[Service]
Environment=OLLAMA_HOST=0.0.0.0:11434
EOF
sudo systemctl daemon-reload
sudo systemctl try-restart ollama.service 2>/dev/null || true
log "Enabling services."
sudo systemctl enable --now ollama.service || warn "Could not enable/start ollama.service."
log "Waiting for Ollama API."
for i in {1..30}; do
    if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        log "Ollama API is reachable."
        break
    fi
    sleep 1
done
if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    log "Pulling gemma3:1b"
    ollama pull gemma3:1b || warn "Could not pull gemma3:1b. It can be pulled later with: ollama pull gemma3:1b"
    log "Pulling qwen2.5-coder:3b"
    ollama pull qwen2.5-coder:3b || warn "Could not pull qwen2.5-coder:3b. It can be pulled later with: ollama pull qwen2.5-coder:3b"
else
    warn "Ollama API did not become reachable. Skipping model pull."
fi
log "Installing Open WebUI."
# the setup should be such that it can work like this as well so that model can run on WSL and frontend on windows 10:
# PS D:\Downloads\Repositories\archRicePack> ls  C:\Scripts\
#     Directory: C:\Scripts
# Mode                 LastWriteTime         Length Name                                                                                                                      
# ----                 -------------         ------ ----                                                                                                                      
# -a----        10/04/2026     01:45             16 .webui_secret_key                                                                                                         
# -a----        01/04/2026     01:44            609 Check-Temps.ps1                                                                                                           
# -a----        10/04/2026     01:20          24661 open-webui.ico                                                                                                            
# -a----        10/04/2026     01:22          31943 open-webui2.ico                                                                                                           
# -a----        10/04/2026     01:37            360 OpenLocalModel.bat                                                                                                        
# -a----        02/04/2026     05:02           1601 Set-HighPriority.ps1                                                                                                      
# -a----        10/04/2026     01:55            236 start_ollama_webui_hidden.vbs                                                                                             
# -a----        01/04/2026     01:41           1306 Switch-PowerMode.ps1                                                                                                            
# PS D:\Downloads\Repositories\archRicePack> cat  C:\Scripts\.webui_secret_key
# C8S58Iqd7VU3GyHV
# PS D:\Downloads\Repositories\archRicePack> cat  C:\Scripts\start_ollama_webui_hidden.vbs
# CreateObject("Wscript.Shell").Run "wsl bash -c 'ollama serve > /tmp/ollama.log 2>&1 &'", 0, False
# WScript.Sleep 3000
# CreateObject("Wscript.Shell").Run "wsl bash -c '~/.local/bin/open-webui serve > /tmp/openwebui.log 2>&1 &'", 0, False
# PS D:\Downloads\Repositories\archRicePack> cat  C:\Scripts\OpenLocalModel.bat           
# @echo off
# :: Check if ollama is running
# wsl pgrep ollama > nul
# if errorlevel 1 (
#     echo Starting ollama...
#     start /B wsl ollama serve > nul 2>&1
#     timeout /t 3 /nobreak > nul
# )
# :: Start open-webui
# echo Starting Open WebUI...
# start /B wsl ~/.local/bin/open-webui serve

# echo Services started!
# echo Access Open WebUI at: http://localhost:8080
# PS D:\Downloads\Repositories\archRicePack> 

# 12-chroot
install_pacman_direct() {
    local pkg="$1"
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && return 0
    pacman -S --needed --noconfirm "$pkg" || warn "pacman failed for package: $pkg"
}
install_package_file_direct() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
        install_pacman_direct "$pkg"
    done < "$file"
}
install_package_file_direct "$REPO_ROOT/packages/WSL-pacman.txt"
copy_dir_root_to_user "$REPO_ROOT/configs/fastfetch"                        "$TARGET_HOME/.config/fastfetch"
copy_dir_root_to_user "$REPO_ROOT/configs/local-bin"                        "$TARGET_HOME/.local/bin"
chmod +x "$TARGET_HOME/.local/bin/"* 2>/dev/null || true
systemctl enable ollama.service || true

# 14-system-stability.sh
git config --global user.name "Ibrahim Hussain"
git config --global user.email "ibrahimbeaconarion@gmail.com"
git config --global init.defaultBranch main
git config core.editor "nano"
git config --global push.default simple
