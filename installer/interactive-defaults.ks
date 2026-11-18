bootc --source-imgref containers-storage:localhost/soarix:latest --target-imgref ghcr.io/myronblair/soarix:latest

# "Install Soarix with desktop" was chosen in the boot menu: mark the new system so that it
# fetches the desktop on first boot (the command line is always installed first).
%post --nochroot --log=/tmp/soarix-post.log
if grep -q 'soarix.desktop=1' /proc/cmdline; then
  for v in /mnt/sysroot/ostree/deploy/*/var; do
    mkdir -p "$v/lib/soarix" && touch "$v/lib/soarix/want-desktop"
  done
fi
%end
