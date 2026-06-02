#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

if [[ "${SKIP_LOCAL_AI:-0}" == "1" ]]; then
    warn "SKIP_LOCAL_AI=1 set. Skipping Ollama/Open WebUI setup."
    exit 0
fi

log "Setting up Ollama + Gemma 3 1B + Open WebUI."

install_pacman_package ollama
install_pacman_package docker
install_pacman_package docker-compose
install_pacman_package xdg-utils
install_pacman_package imagemagick

if command -v nvidia-smi >/dev/null 2>&1; then
    log "NVIDIA detected. Installing ollama-cuda."
    install_pacman_package ollama-cuda
else
    log "No NVIDIA runtime detected. Using base ollama package."
fi

log "Enabling services."
sudo systemctl enable --now ollama.service || warn "Could not enable/start ollama.service."
sudo systemctl enable --now docker.service || warn "Could not enable/start docker.service."

if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER" || true
    warn "User added to docker group. Docker without sudo works after logout/login."
fi

log "Waiting for Ollama API."
for i in {1..30}; do
    if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        log "Ollama API is reachable."
        break
    fi
    sleep 1
done

if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    log "Pulling gemma3:1b."
    ollama pull gemma3:1b || warn "Could not pull gemma3:1b. It can be pulled later with: ollama pull gemma3:1b"
else
    warn "Ollama API did not become reachable. Skipping model pull."
fi

log "Installing Open WebUI Docker container."

if sudo docker ps -a --format '{{.Names}}' | grep -qx 'open-webui'; then
    log "Removing existing open-webui container."
    sudo docker rm -f open-webui || true
fi

sudo docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -e OLLAMA_BASE_URL=http://host.docker.internal:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main || warn "Open WebUI Docker container failed to start."

log "Creating Open WebUI launcher."

mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/scalable/apps" "$HOME/.local/bin"

cat > "$HOME/.local/bin/openwebui-launcher" <<'LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail

URL="http://localhost:3000"

if command -v google-chrome-stable >/dev/null 2>&1; then
    exec google-chrome-stable --app="$URL" --class=OpenWebUI
elif command -v google-chrome >/dev/null 2>&1; then
    exec google-chrome --app="$URL" --class=OpenWebUI
elif command -v chromium >/dev/null 2>&1; then
    exec chromium --app="$URL" --class=OpenWebUI
elif command -v firefox >/dev/null 2>&1; then
    exec firefox "$URL"
else
    exec xdg-open "$URL"
fi
LAUNCHER

chmod +x "$HOME/.local/bin/openwebui-launcher"

cat > "$HOME/.local/share/icons/hicolor/scalable/apps/openwebui.svg" <<'ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="56" fill="#111827"/>
  <circle cx="88" cy="94" r="36" fill="#22d3ee"/>
  <circle cx="166" cy="94" r="36" fill="#a78bfa"/>
  <path d="M60 154c28 35 108 35 136 0" fill="none" stroke="#f8fafc" stroke-width="18" stroke-linecap="round"/>
  <path d="M76 63l52 130 52-130" fill="none" stroke="#ffffff" stroke-width="14" stroke-linecap="round" stroke-linejoin="round" opacity=".85"/>
</svg>
ICON

gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true

cat > "$HOME/.local/share/applications/openwebui.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Open WebUI
Comment=Local AI chat interface for Ollama
Exec=openwebui-launcher
Icon=openwebui
Terminal=false
Categories=Network;Utility;Development;AI;
StartupNotify=true
DESKTOP

update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

log "Pinning Open WebUI to GNOME dock favourites."

python - <<'PY'
import ast
import subprocess

target = "openwebui.desktop"

raw = subprocess.check_output(["gsettings", "get", "org.gnome.shell", "favorite-apps"], text=True).strip()
raw = raw.replace("@as ", "")

try:
    favs = ast.literal_eval(raw)
    if not isinstance(favs, list):
        favs = []
except Exception:
    favs = []

if target not in favs:
    favs.append(target)

value = "[" + ", ".join("'" + x + "'" for x in favs) + "]"
subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", value], check=False)
print(value)
PY

log "Open WebUI setup complete."
log "Access URL: http://localhost:3000"
log "If Docker group access does not work immediately, log out and back in."