#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session
sudo cat installation/pacman.conf             | sudo tee -a /etc/pacman.conf
sudo pacman -S --needed gnome-keyring evolution-data-server at-spi2-core xdg-desktop-portal xdg-desktop-portal-gnome

sudo echo "#GDM configuration storage "          | sudo  tee     /etc/gdm/custom.conf
sudo echo "  "                                   |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "[daemon] "                            |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "WaylandEnable=false "                 |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "  "                                   |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "[security] "                          |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "  "                                   |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "[debug] "                             | sudo   tee -a  /etc/gdm/custom.conf
sudo echo "#Uncomment line to turn on debugging "| sudo   tee -a  /etc/gdm/custom.conf
sudo echo "#Enable=true "                        |  sudo  tee -a  /etc/gdm/custom.conf


log "Added the packages for no upgrade to /etc/pacman.conf"
