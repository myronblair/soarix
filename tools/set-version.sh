#!/bin/bash
# set-version.sh NEW_VERSION - change the Soarix version everywhere it is written down.
# Usage:  tools/set-version.sh 0.2.1
# The version lives in the VERSION file; this script copies it into the places that
# cannot read it themselves (image labels, installer boot menu).
set -euo pipefail
cd "$(dirname "$0")/.."
v="${1:?usage: tools/set-version.sh MAJOR.MINOR.PATCH}"
[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 0.2.1" >&2; exit 1; }
printf '%s\n' "$v" > VERSION
sed -i "s/^ARG SOARIX_VERSION=.*/ARG SOARIX_VERSION=$v/" Containerfile desktop/Containerfile server/Containerfile installer/Containerfile
sed -i -E "s/Install Soarix [0-9]+\.[0-9]+(\.[0-9]+)? /Install Soarix $v /" installer/iso.yaml
echo "Soarix version is now $v. Build, publish, then update the channel files in soarix-updates."
