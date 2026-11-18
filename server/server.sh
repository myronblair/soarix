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

# Nothing runs until the owner turns it on (secure by default), except the firewall and clock.
for u in nginx httpd php-fpm mariadb postgresql valkey memcached named unbound vsftpd proftpd \
         postfix dovecot opendkim haproxy varnish smb nfs-server tomcat fail2ban; do
    systemctl disable "$u.service" 2>/dev/null || true
done
systemctl enable firewalld.service chronyd.service sshd.service cockpit.socket

dnf5 clean all
