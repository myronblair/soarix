bootc --source-imgref containers-storage:localhost/soarix:latest --target-imgref licensing.tomtomenterprises.com/soarix/core:latest

# The login created at the license prompt (username and password; root stays locked)
%include /run/soarix/user.ks

# The installer's own working space lives in RAM and is far too small for the OS image.
# Once the disk is partitioned and mounted, the bootc wrapper stages on the new disk and
# downloads the licensed image there (the license key was activated before the installer started).
%pre-install --log=/tmp/soarix-pre-install.log
true
%end

# "Install Soarix with desktop" was chosen in the boot menu: mark the new system so that it
# fetches the desktop on first boot (the command line is always installed first).
# The new system also gets its license, server id and registry key, and its hostname.
%post --nochroot --log=/tmp/soarix-post.log
# Where the new system is depends on how it was mounted: either the physical disk root
# (ostree/deploy/...), or the finished system itself mounted at /mnt/sysroot.
set -- /mnt/sysroot/ostree/deploy/*/deploy/*/etc
if [ -d "$1" ]; then
  etcs="$*"; vars=$(ls -d /mnt/sysroot/ostree/deploy/*/var)
else
  etcs=/mnt/sysroot/etc; vars=/mnt/sysroot/var
fi
if grep -q 'soarix.desktop=1' /proc/cmdline; then
  for v in $vars; do
    mkdir -p "$v/lib/soarix" && touch "$v/lib/soarix/want-desktop"
  done
fi
# "Install Soarix as a server" was chosen: the server edition is fetched on first boot (needs a license that includes it)
if grep -q 'soarix.server=1' /proc/cmdline; then
  for v in $vars; do
    mkdir -p "$v/lib/soarix" && touch "$v/lib/soarix/want-server"
  done
fi
for d in $etcs; do
  # the computer name typed at the license prompt (default: soarix)
  if [ -s /run/soarix/hostname ]; then cp /run/soarix/hostname "$d/hostname"; else echo soarix > "$d/hostname"; fi
  if [ -f /run/soarix/license.json ]; then
    mkdir -p "$d/soarix" "$d/ostree"
    install -m 600 /run/soarix/license.json "$d/soarix/license.json"
    install -m 644 /run/soarix/server.id "$d/soarix/server.id"
    install -m 600 /etc/ostree/auth.json "$d/ostree/auth.json"
  fi
done
umount /var/tmp >/dev/null 2>&1 || true
rm -rf /mnt/sysimage/.soarix-staging /mnt/sysroot/.soarix-staging >/dev/null 2>&1 || true
%end

# List what was installed (shown in the installer's program log)
%post --nochroot --log=/tmp/soarix-packages.log
d=$(ls -d /mnt/sysroot/ostree/deploy/*/deploy/* 2>/dev/null | head -1)
[ -n "$d" ] || d=/mnt/sysroot
if [ -d "$d/usr" ] && command -v rpm >/dev/null; then
  db="$d/usr/lib/sysimage/rpm"; [ -d "$db" ] || db="$d/usr/share/rpm"
  echo "soarix: installed $(rpm --dbpath "$db" -qa 2>/dev/null | wc -l) packages:" | tee /dev/stderr
  rpm --dbpath "$db" -qa --qf '  %{NAME} %{VERSION}\n' 2>/dev/null | sort | tee /dev/stderr
fi
%end

# Write the hardware clock so the new system does not start with a slow clock.
%post --nochroot --log=/tmp/soarix-clock.log
hwclock --systohc 2>&1 || true
echo "soarix: hardware clock set to $(date)"
%end
