#!/usr/bin/env bash
#----------------------------------------------------------------
#  deploy_release.sh
#
#  Changelog:
#      Paulinchen  2026-11-01: Stopped installing MGQ Online's Mod.ini, which the release no longer ships
#      Paulinchen  2026-10-31: Installed the Mod Framework the release ships inside MGQ Online, its entry file and MGQ Online's Mod.ini with it
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------
#
# Installs a release's game scripts, the Mod Framework they ship inside and the events database
# into the battle server's game folder, run as root on the server: deploy_release.sh <folder
# holding the release's Patch folder> <version>.
# It backs the game folder's Patch up first, restarts the service and compares what it installed.
# The core library is deployed on its own, see BattleServer/README.md.

set -euo pipefail

usage="usage: deploy_release.sh <folder holding the release's Patch folder> <version>"
release=${1:?$usage}
version=${2:?$usage}
game=${MGQ_BATTLE_GAME:-/opt/mgq-battle/game}
backups=${MGQ_BATTLE_BACKUPS:-/var/cache/mgq-battle}
service=${MGQ_BATTLE_SERVICE:-mgq-battle}
from=$release/Patch
patch=$game/Patch
installed=(Multiplayer.rb Multiplayer/Scripts Multiplayer/Data/events.db '!Mod_Framework.rb' Multiplayer/Mod_Framework)

for path in "${installed[@]}"; do
  [ -e "$from/$path" ] || { echo "$from/$path is missing" >&2; exit 1; }
done

backup=$backups/patch-before-$version
mkdir -p "$backup"
rsync -a "$patch"/ "$backup"/
echo "backed up $patch to $backup"

# Root-owned and not writable by others, so a battle child cannot change what every battle reads.
rsync -a --chown=root:root --chmod=go-w "$from/Multiplayer.rb" "$patch/Multiplayer.rb"
rsync -a --delete --chown=root:root --chmod=go-w "$from/Multiplayer/Scripts/" "$patch/Multiplayer/Scripts/"
# The Mod Framework MGQ Online's scripts read their keys and draw through, booted by its entry file.
rsync -a --chown=root:root --chmod=go-w "$from/!Mod_Framework.rb" "$patch/!Mod_Framework.rb"
rsync -a --delete --chown=root:root --chmod=go-w "$from/Multiplayer/Mod_Framework/" "$patch/Multiplayer/Mod_Framework/"
install -d -o root -g root -m 755 "$patch/Multiplayer/Data"
rsync -a --chown=root:root --chmod=go-w "$from/Multiplayer/Data/events.db" "$patch/Multiplayer/Data/events.db"

systemctl restart "$service"
sleep 20
systemctl is-active "$service"

differing=0
while IFS= read -r file; do
  if ! cmp -s "$from/$file" "$patch/$file"; then
    echo "differs: $file" >&2
    differing=1
  fi
done < <(cd "$from" && find "${installed[@]}" -type f | sort)

[ "$differing" -eq 0 ] && echo "installed $version: the scripts, the Mod Framework and the events database equal the release"
exit "$differing"
