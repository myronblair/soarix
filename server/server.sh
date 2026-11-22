#!/bin/bash
# Soarix Server layer: installs the hosting stack. Services stay disabled until enabled by the owner.
set -ouex pipefail

cp -avf /ctx/usr/. /usr/
chmod 0755 /usr/bin/soarix-server

dnf5 -y install \
    nginx httpd mod_ssl php-fpm php-cli php-mysqlnd php-pgsql php-gd php-mbstring php-xml php-intl php-opcache composer \
    certbot python3-certbot-nginx python3-certbot-apache \
    mariadb-server postgresql-server valkey memcached \
    bind bind-utils unbound \
    vsftpd proftpd \
    postfix dovecot opendkim \
    haproxy varnish \
    samba nfs-utils \
    tomcat phpMyAdmin \
    firewalld fail2ban chrony logrotate rsyslog goaccess \
    cockpit cockpit-podman cockpit-storaged cockpit-networkmanager \
    openssh-server rsync git


# Everything the NovaCPX hosting panel (and any hosting setup) can use, installed but switched off.
# Anything Fedora does not ship is skipped, so one missing package cannot fail the build.
dnf5 -y install --skip-unavailable \
    moby-engine docker-compose containerd \
    clamav clamd clamav-freshclam clamav-milter \
    roundcubemail pgadmin4 \
    spamassassin spamass-milter amavis opendmarc dovecot-pigeonhole \
    mod_security mod_evasive nginx-mod-modsecurity \
    audit cronie \
    nsd pdns pdns-recursor pure-ftpd \
    prometheus node-exporter grafana \
    awstats logwatch \
    borgbackup restic rclone lsyncd \
    php-bcmath php-ldap php-soap php-sodium php-process php-pecl-apcu php-pecl-imagick php-pecl-memcached php-pecl-zip php-pecl-redis6 \
    python3-certbot-dns-cloudflare \
    tmux htop ncdu tcpdump nmap-ncat wireguard-tools openvpn s-nail

# ClamAV ships with an "Example" line that stops it from starting; remove it so it starts when you turn it on
for f in /etc/clamd.d/scan.conf /etc/freshclam.conf; do
    [ -f "$f" ] && sed -i 's/^Example/#Example/' "$f" || true
done
# Scheduled jobs are needed by most hosting panels
systemctl enable crond.service 2>/dev/null || true

# Record what was installed (shown by System Information and useful for support)
mkdir -p /usr/share/soarix
rpm -qa --qf '%{NAME}\n' | sort > /usr/share/soarix/server-packages.txt

# Nothing runs until the owner turns it on (secure by default), except the firewall and clock.
for u in nginx httpd php-fpm mariadb postgresql valkey memcached named unbound vsftpd proftpd \
         postfix dovecot opendkim haproxy varnish smb nfs-server tomcat fail2ban \
         docker docker.socket containerd clamd@scan clamav-freshclam clamav-milter spamassassin amavisd opendmarc \
         nsd pdns pdns-recursor pure-ftpd prometheus prometheus-node-exporter grafana-server lsyncd; do
    systemctl disable "$u.service" 2>/dev/null || true
done
systemctl enable firewalld.service chronyd.service sshd.service cockpit.socket

# The server starts at the command line (and the web console); the desktop that comes with the
# image is switched on with: sudo soarix-desktop on   (or from the System Information window)
systemctl set-default multi-user.target
systemctl disable greetd.service 2>/dev/null || true

# Name this edition (shown in System Information; the license and update tools read it)
sed -i 's/^VARIANT=.*/VARIANT="Server"/; s/^VARIANT_ID=.*/VARIANT_ID=server/' /usr/lib/os-release

dnf5 clean all
