#!/bin/bash
# Soarix Desktop layer: installs the desktop session on top of the core image.
set -ouex pipefail

cp -avf /ctx/etc/. /etc/
cp -avf /ctx/usr/. /usr/

dnf5 -y install \
    niri xwayland-satellite \
    greetd greetd-tuigreet \
    waybar fuzzel mako foot \
    xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
    gnome-keyring polkit \
    pipewire pipewire-pulseaudio wireplumber \
    mesa-dri-drivers \
    nautilus firefox \
    google-noto-sans-fonts google-noto-emoji-fonts

# Login screen: greetd + tuigreet launching niri. The desktop image starts at the login screen.
systemctl enable greetd.service
systemctl set-default graphical.target
systemctl disable gdm.service sddm.service 2>/dev/null || true

# Edition name shown in About / os-release
sed -i 's/^VARIANT=.*/VARIANT="Strip desktop"/; s/^VARIANT_ID=.*/VARIANT_ID=strip/' /usr/lib/os-release
printf 'Soarix 0.1  (\l)\n\n' > /etc/issue

dnf5 clean all
