#!/bin/bash
# Soarix core image build (command line). Runs inside the container build.
# The desktop is a separate layer: see desktop/desktop.sh.
set -ouex pipefail

# Soarix files (branding, tools, configs) overlay the image root
cp -avf /ctx/system_files/. /

### Rebrand: replace Fedora release/logo packages with the neutral "generic" ones
dnf5 -y install --allowerasing generic-release generic-logos

### Core system: networking, guest tools for virtual machines, everyday command-line tools
dnf5 -y install \
    NetworkManager NetworkManager-wifi NetworkManager-tui \
    virtualbox-guest-additions qemu-guest-agent spice-vdagent \
    python3 tar xz unzip libatomic libnotify \
    podman distrobox flatpak git curl wget rsync tmux vim-minimal nano htop bash-completion \
    cockpit cockpit-podman

### Soarix tools: language runtimes, OS/app updater, desktop switch
chmod 0755 /usr/bin/soarix-runtime /usr/bin/soarix-update /usr/bin/soarix-desktop /usr/libexec/soarix-firstboot-desktop
systemctl enable soarix-update.timer soarix-firstboot-desktop.service cockpit.socket
systemctl --global enable soarix-update-apps.timer
# Soarix starts at the command line
systemctl set-default multi-user.target

### Identity: make every user-visible name say Soarix
VER="0.1"
cat > /usr/lib/os-release <<OSR
NAME="Soarix"
PRETTY_NAME="Soarix ${VER}"
ID=soarix
ID_LIKE="fedora"
VERSION="${VER}"
VERSION_ID="${VER}"
VARIANT="Command line"
VARIANT_ID=core
HOME_URL="https://getsoarix.com"
SUPPORT_URL="https://getsoarix.com"
BUG_REPORT_URL="https://github.com/myronblair/soarix/issues"
LOGO=soarix-logo
OSR
ln -sf ../usr/lib/os-release /etc/os-release
cat > /etc/issue <<ISSUE
Soarix ${VER}  (\l)

To start the desktop interface after you log in, run:   sudo soarix-desktop on

ISSUE
echo "Soarix ${VER}" > /etc/issue.net
echo "soarix" > /etc/hostname
# Boot menu label (GRUB reads this)
echo 'GRUB_DISTRIBUTOR="Soarix"' >> /etc/default/grub
# Credit required by Fedora's trademark guidelines / licenses
mkdir -p /usr/share/soarix
echo "Soarix is based on Fedora. Fedora is a trademark of Red Hat, Inc." > /usr/share/soarix/CREDITS

### Replace the artwork that the generic-logos package ships under Fedora's file names with the Soarix mark
for f in /usr/share/pixmaps/fedora-logo.png /usr/share/pixmaps/fedora-logo-small.png /usr/share/pixmaps/system-logo-white.png; do
    [ -e "$f" ] && cp -f /usr/share/pixmaps/soarix-logo.png "$f" || true
done
rm -f /usr/share/pixmaps/fedora-logo-sprite.svg /usr/share/pixmaps/bootloader/fedora.icns 2>/dev/null || true

### Cleanup
dnf5 clean all
