#!/bin/bash
# Soarix Desktop layer: installs the desktop session on top of the core image.
set -ouex pipefail

cp -avf /ctx/etc/. /etc/
cp -avf /ctx/usr/. /usr/

dnf5 -y install \
    niri xwayland-satellite \
    greetd greetd-tuigreet \
    waybar fuzzel mako foot swaybg \
    xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
    gnome-keyring polkit \
    pipewire pipewire-pulseaudio wireplumber \
    mesa-dri-drivers \
    nautilus firefox \
    google-noto-sans-fonts google-noto-emoji-fonts \
    blueman \
    gvfs-smb gvfs-mtp gvfs-nfs gvfs-afc \
    system-config-printer cups-pk-helper simple-scan \
    fprintd-pam

# Login screen: greetd + tuigreet launching niri. The desktop image starts at the login screen.
systemctl enable greetd.service
systemctl set-default graphical.target
systemctl disable gdm.service sddm.service 2>/dev/null || true

# Default desktop setup: wallpaper, terminal (foot) on Mod+T, launcher on Mod+D
mkdir -p /etc/niri
sed 's/alacritty/foot/g' /usr/share/doc/niri/default-config.kdl > /etc/niri/config.kdl
printf '
spawn-at-startup "swaybg" "-i" "/usr/share/backgrounds/soarix/default.png" "-m" "fill"
' >> /etc/niri/config.kdl

# Edition name shown in About / os-release
sed -i 's/^VARIANT=.*/VARIANT="Strip desktop"/; s/^VARIANT_ID=.*/VARIANT_ID=strip/' /usr/lib/os-release
printf 'Soarix 0.1  (\l)\n\n' > /etc/issue

dnf5 clean all
