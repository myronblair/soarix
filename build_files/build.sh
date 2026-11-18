#!/bin/bash
# Soarix image build. Runs inside the container build.
set -ouex pipefail

# Soarix files (branding, configs) overlay the image root
cp -avf /ctx/system_files/. /

### Rebrand: replace Fedora release/logo packages with the neutral "generic" ones
dnf5 -y install --allowerasing generic-release generic-logos

### Desktop: niri (scrolling Wayland compositor) + a minimal session
dnf5 -y install \
    niri xwayland-satellite \
    greetd greetd-tuigreet \
    waybar fuzzel mako foot \
    xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
    gnome-keyring polkit \
    pipewire pipewire-pulseaudio wireplumber \
    NetworkManager NetworkManager-wifi \
    mesa-dri-drivers \
    nautilus firefox \
    flatpak distrobox \
    virtualbox-guest-additions qemu-guest-agent spice-vdagent \
    python3 tar xz unzip libatomic libnotify

### Soarix tools: language runtimes (soarix-runtime) and OS/app updater (soarix-update)
chmod 0755 /usr/bin/soarix-runtime /usr/bin/soarix-update
systemctl enable soarix-update.timer
systemctl --global enable soarix-update-apps.timer

### Login screen: greetd + tuigreet launching niri
systemctl enable greetd.service
systemctl set-default graphical.target
# greetd needs its own user and runs instead of any other display manager
systemctl disable gdm.service sddm.service 2>/dev/null || true

### Identity: make every user-visible name say Soarix
VER="0.1"
cat > /usr/lib/os-release <<OSR
NAME="Soarix"
PRETTY_NAME="Soarix ${VER}"
ID=soarix
ID_LIKE="fedora"
VERSION="${VER}"
VERSION_ID="${VER}"
VARIANT="Strip"
VARIANT_ID=strip
HOME_URL="https://getsoarix.com"
SUPPORT_URL="https://getsoarix.com"
BUG_REPORT_URL="https://github.com/myronblair/soarix/issues"
LOGO=soarix-logo
OSR
ln -sf ../usr/lib/os-release /etc/os-release
echo "Soarix ${VER}" > /etc/issue
echo "Soarix ${VER}" > /etc/issue.net
echo "soarix" > /etc/hostname
# Boot menu label (GRUB reads this)
echo 'GRUB_DISTRIBUTOR="Soarix"' >> /etc/default/grub
# Credit required by Fedora's trademark guidelines / licenses
mkdir -p /usr/share/soarix
echo "Soarix is based on Fedora. Fedora is a trademark of Red Hat, Inc." > /usr/share/soarix/CREDITS

### Cleanup
dnf5 clean all
