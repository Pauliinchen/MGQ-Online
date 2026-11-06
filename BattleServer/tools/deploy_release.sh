#!/usr/bin/env bash
#----------------------------------------------------------------
#  deploy_release.sh
#
#  Changelog:
#      Paulinchen  2026-11-06: Installed the Mod Framework from its own release only when one is named, removing the copy earlier deploys put inside MGQ Online's folder and Mod Config Remake
#      Paulinchen  2026-11-01: Stopped installing MGQ Online's Mod.ini, which the release no longer ships
#      Paulinchen  2026-10-31: Installed the Mod Framework the release ships inside MGQ Online, its entry file and MGQ Online's Mod.ini with it
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------
#
# Installs a release's game scripts and events database into the battle server's game folder, and
# the Mod Framework from a framework release when one is named, run as root on the server:
# deploy_release.sh <folder holding the release's Patch folder> <version> [<folder holding the
# Mod Framework release's Patch folder>].
# Without a framework release the one already installed stays; the deploy stops before changing
# anything when there is none. It backs the game folder's Patch up first, removes what earlier
# deploys left that the framework replaces, restarts the service and compares what it installed.
# The core library is deployed on its own, see BattleServer/README.md.

set -euo pipefail

usage="usage: deploy_release.sh <folder holding the release's Patch folder> <version> [<folder holding the Mod Framework release's Patch folder>]"
release=${1:?$usage}
version=${2:?$usage}
framework=${3:-}
game=${MGQ_BATTLE_GAME:-/opt/mgq-battle/game}
backups=${MGQ_BATTLE_BACKUPS:-/var/cache/mgq-battle}
service=${MGQ_BATTLE_SERVICE:-mgq-battle}
from=$release/Patch
patch=$game/Patch
installed=(Multiplayer.rb Multiplayer/Scripts Multiplayer/Data/events.db)
framework_parts=('!Mod_Framework.rb' Mod_Framework)
# The framework copy earlier deploys put inside MGQ Online's folder, which would compete with the
# framework's own folder, and Mod Config Remake, whose calls the framework answers.
retired=(Multiplayer/Mod_Framework 0_ModConfigRemake.rb)

for path in "${installed[@]}"; do
  [ -e "$from/$path" ] || { echo "$from/$path is missing" >&2; exit 1; }
done

if [ -n "$framework" ]; then
  framework_from=$framework/Patch
  for path in "${framework_parts[@]}"; do
    [ -e "$framework_from/$path" ] || { echo "$framework_from/$path is missing" >&2; exit 1; }
  done
else
  for path in "${framework_parts[@]}"; do
    [ -e "$patch/$path" ] || { echo "$patch/$path is missing: name the folder holding a Mod Framework release's Patch folder as the third argument" >&2; exit 1; }
  done
fi

backup=$backups/patch-before-$version
mkdir -p "$backup"
rsync -a "$patch"/ "$backup"/
echo "backed up $patch to $backup"

# Root-owned and not writable by others, so a battle child cannot change what every battle reads.
rsync -a --chown=root:root --chmod=go-w "$from/Multiplayer.rb" "$patch/Multiplayer.rb"
rsync -a --delete --chown=root:root --chmod=go-w "$from/Multiplayer/Scripts/" "$patch/Multiplayer/Scripts/"
install -d -o root -g root -m 755 "$patch/Multiplayer/Data"
rsync -a --chown=root:root --chmod=go-w "$from/Multiplayer/Data/events.db" "$patch/Multiplayer/Data/events.db"
if [ -n "$framework" ]; then
  # The Mod Framework MGQ Online's scripts read their keys and draw through, booted by its entry
  # file. Its settings (*.ini) in its folder stay.
  rsync -a --chown=root:root --chmod=go-w "$framework_from/!Mod_Framework.rb" "$patch/!Mod_Framework.rb"
  rsync -a --delete --exclude '*.ini' --chown=root:root --chmod=go-w "$framework_from/Mod_Framework/" "$patch/Mod_Framework/"
fi
for path in "${retired[@]}"; do
  if [ -e "$patch/$path" ]; then
    rm -rf "${patch:?}/$path"
    echo "removed $patch/$path"
  fi
done

systemctl restart "$service"
sleep 20
systemctl is-active "$service"

differing=0
# Compares every file a folder holds below the given paths with the game folder's.
compare() {
  local source=$1
  shift
  while IFS= read -r file; do
    if ! cmp -s "$source/$file" "$patch/$file"; then
      echo "differs: $file" >&2
      differing=1
    fi
  done < <(cd "$source" && find "$@" -type f ! -name '*.ini' | sort)
}
compare "$from" "${installed[@]}"
[ -n "$framework" ] && compare "$framework_from" "${framework_parts[@]}"

if [ "$differing" -eq 0 ]; then
  echo "installed $version: the scripts${framework:+, the Mod Framework} and the events database equal the releases"
fi
exit "$differing"
