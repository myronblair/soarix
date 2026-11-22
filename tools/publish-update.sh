#!/bin/bash
# publish-update.sh - build and publish one update for every Soarix edition from editions/manifest.json.
#
#   N=21 PREV=20 tools/publish-update.sh            build update 21 on top of update 20, for core, desktop and server
#   N=21 PREV=20 ONLY=desktop tools/publish-update.sh   only some editions
#
# What it does for each edition: lay out the files that edition receives (tools/stage-editions.py), build a small
# layer on the build box (VM124) on top of the previous image, copy the finished image out, upload only the layers
# the license server does not have yet, check their checksums, and switch the edition's index to the new image.
# Before it runs, set the version with tools/set-version.sh and commit; afterwards update the channel files
# in the soarix-updates repo.
set -e
cd "$(dirname "$0")/.."
ROOT=$PWD
B=${BUILD_BOX:-fedora@10.48.200.151}; S=/home/fedora/soarix-build; L=${LICENSE_BOX:-root@162.35.17.63}
N=${N:?set N (this update number)}; PREV=${PREV:?set PREV (the update it builds on)}
ONLY=${ONLY:-core,desktop,server}
VER=$(cat VERSION)
TMP=${TMPDIR:-/tmp}; STG=$TMP/soarix-stage-$N
WIN() { command -v cygpath >/dev/null && cygpath -m "$1" || echo "$1"; }

python tools/stage-editions.py --check
python tools/stage-editions.py "$(WIN "$STG")"
echo "publishing Soarix $VER (update $N on update $PREV): $ONLY"

STAMP="RUN sed -i 's/^VERSION=.*/VERSION=\"$VER\"/; s/^VERSION_ID=.*/VERSION_ID=\"$VER\"/; s/^PRETTY_NAME=.*/PRETTY_NAME=\"Soarix $VER\"/' /usr/lib/os-release && (grep -q '^BUILD_ID=' /usr/lib/os-release || echo 'BUILD_ID=\"$(date +%Y-%m-%d)\"' >> /usr/lib/os-release) && sed -i 's/^Soarix [0-9.]*  /Soarix $VER  /' /etc/issue
LABEL org.opencontainers.image.version=\"$VER\""

publish() {   # edition  local-image  registry-folder
  local ed=$1 img=$2 dir=$3 d=$STG/$1
  echo "== $ed: building"
  local execs pkgs after cf=$STG/Containerfile.$ed
  execs=$(tr '\n' ' ' < $d/exec.txt); pkgs=$(cat $d/packages.txt | tr -d '\n'); after=$(paste -sd'&' $d/after.txt | sed 's/&/ \&\& /g')
  {
    echo "FROM $img:fix$PREV"
    echo "COPY stage-$ed-$N/ /"
    [ -n "$execs" ] && echo "RUN chmod 0755 $execs"
    [ -n "$pkgs" ] && echo "RUN dnf5 -y install --skip-unavailable $pkgs && dnf5 clean all"
    [ -n "$(echo $after)" ] && echo "RUN $after"
    echo "$STAMP"
    echo "RUN bootc container lint"
  } > $cf
  ssh $B "rm -rf $S/stage-$ed-$N"
  scp -q -r $d/tree $B:$S/stage-$ed-$N
  scp -q $cf $B:$S/Containerfile.$ed-$N
  ssh $B "cd $S && sudo podman build -q -f Containerfile.$ed-$N -t $img:fix$N . >/dev/null && sudo rm -rf oci-$ed-$N && sudo skopeo copy containers-storage:$img:fix$N oci:oci-$ed-$N:latest >/dev/null 2>&1 && sudo chown -R fedora oci-$ed-$N && ls oci-$ed-$N/blobs/sha256 > blobs-$ed-$N.txt"
  ssh $L 'ls /home/licensing/registry/soarix/_pool/blobs/sha256' | sort > $TMP/pool-$ed.txt
  ssh $B "cat $S/blobs-$ed-$N.txt" | sort > $TMP/have-$ed.txt
  comm -23 $TMP/have-$ed.txt $TMP/pool-$ed.txt > $TMP/new-$ed.txt
  echo "$ed: $(wc -l < $TMP/new-$ed.txt) new layers"
  local U=$TMP/up-$ed-$N; rm -rf $U; mkdir -p $U/idx
  for b in $(cat $TMP/new-$ed.txt); do scp -q $B:$S/oci-$ed-$N/blobs/sha256/$b $U/$b; done
  scp -q $B:$S/oci-$ed-$N/index.json $U/idx/index.json
  for b in $(cat $TMP/new-$ed.txt); do [ "$(sha256sum $U/$b | cut -d' ' -f1)" = "$b" ] || { echo "BAD checksum $b"; exit 1; }; done
  echo "$ed: checksums ok ($(du -sh $U | cut -f1))"
  local T; T=$(ssh $L 'mktemp -d /root/up.XXXXXX'); scp -qr $U/* $L:$T/
  ssh $L "set -e; cd $T; P=/home/licensing/registry/soarix
for b in \$(ls | grep -v '^idx\$'); do [ \"\$(sha256sum \$b | cut -d' ' -f1)\" = \"\$b\" ] || { echo BAD \$b; exit 1; }; install -o licensing -g www-data -m 640 \$b \$P/_pool/blobs/sha256/\$b; done
cp \$P/$dir/index.json /home/licensing/index.$dir.previous$N.json
install -o licensing -g www-data -m 640 idx/index.json \$P/$dir/index.json
cd /; rm -rf $T; echo PUBLISHED $dir"
}

case ",$ONLY," in *,core,*)    publish core    localhost/soarix         core ;; esac
case ",$ONLY," in *,desktop,*) publish desktop localhost/soarix-desktop desktop ;; esac
case ",$ONLY," in *,server,*)  publish server  localhost/soarix-server  server ;; esac
echo "ALL PUBLISHED: Soarix $VER"
