bootc --source-imgref containers-storage:localhost/soarix:latest --target-imgref licensing.tomtomenterprises.com/soarix/core:latest

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
if grep -q 'soarix.desktop=1' /proc/cmdline; then
  for v in /mnt/sysroot/ostree/deploy/*/var; do
    mkdir -p "$v/lib/soarix" && touch "$v/lib/soarix/want-desktop"
  done
fi
for d in /mnt/sysroot/ostree/deploy/*/deploy/*/etc; do
  echo soarix > "$d/hostname"
  if [ -f /run/soarix/license.json ]; then
    mkdir -p "$d/soarix" "$d/ostree"
    install -m 600 /run/soarix/license.json "$d/soarix/license.json"
    install -m 644 /run/soarix/server.id "$d/soarix/server.id"
    install -m 600 /etc/ostree/auth.json "$d/ostree/auth.json"
  fi
done
umount /var/tmp 2>/dev/null || true
rm -rf /mnt/sysroot/.soarix-staging
%end
