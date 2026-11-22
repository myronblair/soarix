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

### Hardware support: firmware, kernel extras, firmware updates
dnf5 -y install \
    linux-firmware kernel-modules-extra fwupd \
    alsa-sof-firmware alsa-firmware alsa-utils \
    iw wireless-regdb usb_modeswitch bolt \
    usbutils pciutils lshw lm_sensors smartmontools nvme-cli \
    power-profiles-daemon upower thermald zram-generator rtkit \
    fprintd pcsc-lite pcsc-lite-ccid

### Bluetooth
dnf5 -y install bluez bluez-tools

### Storage and filesystems (read and write other systems' disks and USB sticks)
dnf5 -y install cryptsetup ntfs-3g exfatprogs dosfstools btrfs-progs xfsprogs

### Networking, discovery and sharing: Wi-Fi/VPN, local-network discovery, printing, scanning, file sharing
dnf5 -y install \
    NetworkManager-openvpn wireguard-tools \
    avahi nss-mdns \
    cups cups-filters sane-backends sane-backends-drivers-scanners \
    samba-client \
    firewalld chrony openssh-server \
    mtr traceroute nmap-ncat bind-utils

### Soarix tools: language runtimes, OS/app updater, desktop switch
chmod 0755 /usr/bin/soarix-runtime /usr/bin/soarix-update /usr/bin/soarix-desktop /usr/bin/soarix-license /usr/bin/soarix-hardware /usr/bin/soarix-info /usr/bin/soarix-edition /usr/bin/soarix-admin-mode /usr/bin/soarix-programs /usr/bin/soarix-addon /usr/libexec/soarix-firstboot-desktop
systemctl enable soarix-update.timer soarix-firstboot-desktop.service soarix-hostname.service cockpit.socket

# Hardware and everyday services on by default. Sharing and remote access stay OFF until the owner turns them on
# (printer sharing is off in CUPS by default; SSH and file-sharing servers are not enabled).
systemctl enable bluetooth.service power-profiles-daemon.service upower.service avahi-daemon.service \
    cups.socket chronyd.service firewalld.service fstrim.timer fwupd-refresh.timer 2>/dev/null || true
# The web console (Cockpit, port 9090) is announced on the login screen, so let it through the firewall
firewall-offline-cmd --zone=public --add-service=cockpit
# Compressed RAM swap so small-memory machines stay responsive
mkdir -p /usr/lib/systemd/zram-generator.conf.d
printf '[zram0]\nzram-size = min(ram / 2, 4096)\ncompression-algorithm = zstd\n' > /usr/lib/systemd/zram-generator.conf
systemctl --global enable soarix-update-apps.timer
# Soarix starts at the command line
systemctl set-default multi-user.target
# Network toolkit for every edition (anything Fedora does not ship is skipped)
dnf5 -y install --skip-unavailable bind-utils traceroute mtr nmap iperf3 ethtool whois net-tools nmap-ncat socat tcpdump iftop nload nethogs bmon speedtest-cli iw arp-scan NetworkManager-tui NetworkManager-wifi avahi-tools conntrack-tools ipcalc

### Identity: make every user-visible name say Soarix
VER="$(cat /ctx/VERSION)"
BUILD="$(date +%Y-%m-%d)"
cat > /usr/lib/os-release <<OSR
NAME="Soarix"
PRETTY_NAME="Soarix ${VER}"
ID=soarix
ID_LIKE="fedora"
VERSION="${VER}"
VERSION_ID="${VER}"
BUILD_ID="${BUILD}"
VARIANT="Command line"
VARIANT_ID=core
HOME_URL="https://getsoarix.com"
SUPPORT_URL="https://getsoarix.com"
BUG_REPORT_URL="https://github.com/myronblair/soarix/issues"
LOGO=soarix-logo
DEFAULT_HOSTNAME=soarix
OSR
ln -sf ../usr/lib/os-release /etc/os-release
cat > /etc/issue <<ISSUE
Soarix ${VER}  (\l)

To start the desktop interface after you log in, run:   sudo soarix-desktop on

ISSUE
echo "Soarix ${VER}" > /etc/issue.net
echo "soarix" > /etc/hostname
# Quiet the console: no kernel audit messages over the login screen
mkdir -p /usr/lib/bootc/kargs.d
printf 'kargs = ["audit=0", "loglevel=3"]\n' > /usr/lib/bootc/kargs.d/10-soarix.toml
# Boot menu label (GRUB reads this)
echo 'GRUB_DISTRIBUTOR="Soarix"' >> /etc/default/grub
# Credit required by Fedora's trademark guidelines / licenses
mkdir -p /usr/share/soarix
echo "Soarix is based on Fedora. Fedora is a trademark of Red Hat, Inc." > /usr/share/soarix/CREDITS

### Replace the artwork that the generic-logos package ships under Fedora's file names with the Soarix mark
for f in /usr/share/pixmaps/fedora-logo.png /usr/share/pixmaps/fedora-logo-small.png /usr/share/pixmaps/system-logo-white.png; do
    [ -e "$f" ] && cp -f /usr/share/pixmaps/soarix-logo.png "$f" || true
done
rm -f /usr/share/pixmaps/fedora-logo-sprite.svg /usr/share/pixmaps/bootloader/fedora.icns \
      /usr/share/pixmaps/bootloader/fedora.vol /usr/share/pixmaps/bootloader/fedora-media.vol 2>/dev/null || true

### Rebuild the initramfs so the early-boot screen says Soarix (it copies os-release at build time)
KVER="$(ls /usr/lib/modules | head -n1)"
export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "$KVER" --reproducible --add ostree \
    -f "/usr/lib/modules/$KVER/initramfs.img"
chmod 0600 "/usr/lib/modules/$KVER/initramfs.img"

### Cleanup
dnf5 clean all
