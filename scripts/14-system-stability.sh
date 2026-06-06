#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session
cat ../installation/pacman.conf             | tee -a /etc/pacman.conf
sudo pacman -S --needed gnome-keyring evolution-data-server at-spi2-core xdg-desktop-portal xdg-desktop-portal-gnome

echo "#GDM configuration storage "          | tee     /etc/gdm/custom.conf
echo "  "                                   | tee -a  /etc/gdm/custom.conf
echo "[daemon] "                            | tee -a  /etc/gdm/custom.conf
echo "WaylandEnable=false "                 | tee -a  /etc/gdm/custom.conf
echo "  "                                   | tee -a  /etc/gdm/custom.conf
echo "[security] "                          | tee -a  /etc/gdm/custom.conf
echo "  "                                   | tee -a  /etc/gdm/custom.conf
echo "[debug] "                             | tee -a  /etc/gdm/custom.conf
echo "#Uncomment line to turn on debugging "| tee -a  /etc/gdm/custom.conf
echo "#Enable=true "                        | tee -a  /etc/gdm/custom.conf





log "Added the packages for no upgrade to /etc/pacman.conf"