bootc --source-imgref containers-storage:localhost/soarix:latest --target-imgref ghcr.io/myronblair/soarix:latest

# The installer's own working space lives in RAM and is far too small for the OS image.
# Once the disk is partitioned and mounted, point the installer's temporary area at the new disk.
%pre-install --erroronfail --log=/tmp/soarix-pre-install.log
mkdir -p /mnt/sysroot/.soarix-staging
mount --bind /mnt/sysroot/.soarix-staging /var/tmp
%end

# "Install Soarix with desktop" was chosen in the boot menu: mark the new system so that it
# fetches the desktop on first boot (the command line is always installed first).
# Also release the staging area.
%post --nochroot --log=/tmp/soarix-post.log
if grep -q 'soarix.desktop=1' /proc/cmdline; then
  for v in /mnt/sysroot/ostree/deploy/*/var; do
    mkdir -p "$v/lib/soarix" && touch "$v/lib/soarix/want-desktop"
  done
fi
umount /var/tmp 2>/dev/null || true
rm -rf /mnt/sysroot/.soarix-staging
%end
