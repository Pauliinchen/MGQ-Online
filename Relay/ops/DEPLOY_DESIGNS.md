# Deploying the Raid designs

How the Raid design features (designer routes, socket, releases, builds, the game's design routes) go onto the live Node relay at `relay.mgqonline.org`, and how its database is backed up and restored. Every step on the server waits for the user's yes, and only a backwards compatible relay goes live.

The server, as set up on 2026-10-15:

| What | Where |
|---|---|
| Relay code | `/opt/mgq-online/Relay` (root-owned, `npm ci --omit=dev`) |
| Service | `mgq-relay`, as the system user `mgq-relay` |
| Settings | `/etc/mgq-online/relay.env` |
| Database | `/var/lib/mgq-relay/relay.sqlite` (with `-wal` and `-shm`) |
| Battle server game folder | `/opt/mgq-battle/game` |

Milestones (spec H): **M1** needs steps 1 to 5 (backup, then the relay with designers and releases); **M2** adds step 6 (the CLI and server builds). A publish to live play waits for a mod release that reads compiled format 3, so `DESIGN_WORLD_NOTICE` stays `0` until then.

## What changes for the live relay

Only additions:
- new routes `/v1/designs/*`, `/v1/raid-design` and `/v1/raid-design/<sha256>`, the designer socket `/v1/designs/socket`, and `/v1/migration/designs` for the relay's admins;
- the database steps (`node/schema.js`): step 1 is the tables the relay already has (`CREATE TABLE IF NOT EXISTS`, nothing changes), steps 2 and 3 add the design tables;
- the design epoch, a random id in `design_meta`, and `relay.design-seq` beside the database, which the relay writes after every design push (see [step 7](#7-restoring-a-backup)), so the database's folder must stay writable for `mgq-relay`, as it already is for the `-wal` file;
- `GET /v1/migration` answers `format` 2 instead of 1; nothing but `node/migrate.js`, which reads both, uses it (the website and the World Admin tool do not);
- the game's version gate is unchanged: the designer gate applies to the design routes only, and released games never call them;
- the Cloudflare relay answers the design routes with 404 `no_designs`; it is frozen and needs no deploy.

Older code runs on a database that took the new steps: it makes its tables with `CREATE TABLE IF NOT EXISTS` and never reads `user_version` or the design tables, so rolling back the code needs no restore of the database.

## 1. Start from the live files

The server runs whatever was deployed last, which may differ from any branch (on 2026-10-17 it was main plus the uncommitted freeze `story.js`, on 2026-10-22 main `6ecc712`). Find the commit the live files equal before building anything on top:

```sh
# On the server: the live runtime files' hashes.
cd /opt/mgq-online/Relay && sha256sum core/*.js node/*.js package.json package-lock.json | sort -k2 > /tmp/live.sha256

# Locally: the same list of a candidate commit, then compare (the server's copies may have CRLF line endings
# when they came from a Windows checkout; hash both sides with the same line endings).
git archive <commit> Relay | tar -x -C <scratch> && (cd <scratch>/Relay && sha256sum core/*.js node/*.js package.json package-lock.json | sort -k2)
```

A file that differs from every candidate is a hot fix that lives only on the server: copy it off and fold it into the deploy branch, or stop and ask. Then:

1. Cut `deploy/raid-designs` from the live commit and merge `feat/raid-design` into it. A dry run on 2026-10-22 against main `6ecc712` conflicts in `README.md`, `cloudflare/worker.js`, `core/gate.js`, `core/gate.test.js` and `node/server.js`; both sides only add, so keep both.
2. `npm test` must be green, with `SQLITE3` set so the backup tests run.
3. Check that it stays additive: `git diff <live commit> deploy/raid-designs -- Relay/core Relay/node ':!*.test.js'` may only add routes, branches and files outside the design files, and nothing a released game reads may change (`git show v<latest>:MGQParadox.Multiplayer/Network/World/DirectoryClient.cs` shows what the DLL reads).

## 2. Backups (M1 step 1, before any collaborator)

`ops/backup-relay.sh` copies the database with sqlite3's online backup (`.backup`, safe while the relay writes), checks the copy with `PRAGMA integrity_check`, writes one line with the row counts of the design tables, and keeps the newest `BACKUP_KEEP` copies named `relay-<date>.sqlite`. `ops/mgq-relay-backup.timer` runs it every night at 04:17 (up to 10 minutes later), and catches up a run the server was off for. The design blobs live in the database; `DESIGN_DATA_DIR` holds only the release cache, which the relay downloads again, and build folders, which it clears as it starts.

```sh
sudo apt install sqlite3
sudo install -d -o mgq-relay -g mgq-relay -m 700 /var/backups/mgq-relay
sudo install -m 755 ops/backup-relay.sh /usr/local/sbin/mgq-relay-backup
sudo install -m 644 ops/mgq-relay-backup.service ops/mgq-relay-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mgq-relay-backup.timer
sudo systemctl start mgq-relay-backup.service          # one run now
journalctl -u mgq-relay-backup.service -n 5            # backup-relay: ... -> /var/backups/mgq-relay/relay-<date>.sqlite (...)
systemctl list-timers mgq-relay-backup.timer
```

The script runs as `mgq-relay`, never as root: sqlite3 may create the database's `-wal` and `-shm` files, and root-owned ones would lock the relay out of its own database. Without systemd timers, `/etc/cron.d/mgq-relay-backup` with `17 4 * * * mgq-relay /usr/local/sbin/mgq-relay-backup` does the same (the script's defaults are the paths above).

The copies stay on the same disk as the database. Fetch one off the server now and then (`scp mgqadmin@relay.mgqonline.org:/var/backups/mgq-relay/relay-<date>.sqlite .` after `sudo cp` into the admin's home), above all before a risky step.

## 3. Settings

Back up `relay.env` first (`sudo cp /etc/mgq-online/relay.env /etc/mgq-online/relay.env.bak-<stamp>`), then add:

| Variable | Value |
|---|---|
| `DESIGNER_ADMINS` | the designer ids of the admin designers, separated by commas; each designer reads their id in the designer (or `GET /v1/designs/me`, which answers an unlisted key with its id). The relay adds only the ids it does not list yet, so a demotion lasts; an admin removed through the designer list comes back at the next start until its id is taken out of this setting too |
| `DESIGNER_MIN_VERSION` | the first designer release, such as `1.0.0`; raised with every release that must be taken |
| `DESIGNER_REPO` | `Pauliinchen/MGQ-Online-Raid-Designer` (the default) |
| `DESIGNER_GITHUB_TOKEN` | a fine-grained token with Contents: read on that repository only; it never leaves the server |
| `DESIGNER_GITHUB_TOKEN_EXPIRES` | the token's expiry date, such as `2027-10-01`; the relay warns from 30 days before |
| `DESIGNER_RELEASE_PUBKEY` | the PEM of the release key, its line breaks written `\n` |
| `DESIGN_DATA_DIR` | `/var/lib/mgq-relay/designs` (`sudo install -d -o mgq-relay -g mgq-relay -m 700 /var/lib/mgq-relay/designs`) |
| `DESIGN_COMPILER` | M2 only: `/opt/mgq-designer/current/raid-designer` |
| `DESIGN_GAME_DATA` | M2 only: `/opt/mgq-battle/game` |
| `DESIGN_WORLD_NOTICE` | `0` until a released game reads compiled format 3 |

`DESIGNER_ALLOW_DEV` is for a local test relay only and never goes into `relay.env`. Without the token, the key or `DESIGN_DATA_DIR` the relay serves no designer releases; without the compiler, the game data or `DESIGN_DATA_DIR`, builds answer 503 `compiler`. Both leave the rest of the designs working.

If `systemctl cat mgq-relay` shows a sandbox (`ProtectSystem=strict` or `ReadWritePaths=`), add `DESIGN_DATA_DIR` to its writable paths.

## 4. Copy and restart

```sh
# Locally
git archive deploy/raid-designs Relay | gzip > relay.tar.gz && scp relay.tar.gz mgqadmin@relay.mgqonline.org:/tmp/

# On the server
STAMP=$(date +%Y%m%d-%H%M%S)
sudo cp -a /opt/mgq-online/Relay /opt/mgq-online/Relay.bak-$STAMP
sudo -u mgq-relay sqlite3 /var/lib/mgq-relay/relay.sqlite ".backup /var/backups/mgq-relay/before-designs-$STAMP.sqlite"
mkdir /tmp/relay-$STAMP && tar -xzf /tmp/relay.tar.gz -C /tmp/relay-$STAMP
sudo rsync -a --chown=root:root /tmp/relay-$STAMP/Relay/core /tmp/relay-$STAMP/Relay/node /tmp/relay-$STAMP/Relay/ops \
  /tmp/relay-$STAMP/Relay/package.json /tmp/relay-$STAMP/Relay/package-lock.json /opt/mgq-online/Relay/
(cd /opt/mgq-online/Relay && sudo npm ci --omit=dev)
sudo systemctl restart mgq-relay
journalctl -u mgq-relay -n 20                          # relay listening on 127.0.0.1:8080, database ...
sudo -u mgq-relay sqlite3 /var/lib/mgq-relay/relay.sqlite "PRAGMA user_version;"   # 3
```

Then hash-check the live files against the branch as in step 1.

**Rollback:** `sudo systemctl stop mgq-relay`, move `/opt/mgq-online/Relay` aside, rename `Relay.bak-<stamp>` back, `sudo systemctl start mgq-relay`. The database stays.

## 5. Checks after the deploy

- Games: a released game lists the worlds and joins one as before.
- Designers: an admin designer starts the designer against the live relay, sees itself listed, then `raid-designer import --format1 <copy of RaidDesign.json> --push --server https://relay.mgqonline.org --key-file <key>` (M1 step 4; it refuses with exit 6 when the import dropped parts, unless `--accept-dropped`).
- Migration export: `MGQ_ADMIN_KEY=<an admin's player key> node /opt/mgq-online/Relay/node/migrate.js http://127.0.0.1:8080 /tmp/migration-check.sqlite` copies everything, the design tables too, and checks the copy; delete `/tmp/migration-check.sqlite` afterwards.
- The next nightly backup line counts the design rows.

## 6. Server builds (M2)

1. Install the self-contained linux-x64 CLI: `sudo install -d /opt/mgq-designer/<version>`, copy `raid-designer` into it (root-owned, `755`), `sudo ln -sfn /opt/mgq-designer/<version> /opt/mgq-designer/current`. A later version goes into its own folder and moves the link; the relay probes a binary again when it changed.
2. `sudo -u mgq-relay /opt/mgq-designer/current/raid-designer --version --json` names the design format, and `sudo -u mgq-relay /opt/mgq-designer/current/raid-designer preflight --game /opt/mgq-battle/game --json` exits 0 (exit 4 names missing or wrongly cased game files). Run both as `mgq-relay`, the user the relay compiles as.
3. Rehearse on the server before the relay builds: copy the Relay folder of the deploy branch with its tests to `/tmp/relay-harness`, `npm ci --omit=dev`, a copy of the user's format 1 design to `/tmp/relay-harness/design.json`, then `RAID_DESIGNER_CLI=/opt/mgq-designer/current/raid-designer RAID_DESIGNER_GAME=/opt/mgq-battle/game RAID_DESIGNER_FIXTURE=/tmp/relay-harness/design.json node --test node/design_cli.test.js`. The harness starts a relay of its own on a free local port with a database in the temp folder, so the live relay is untouched; delete `/tmp/relay-harness` afterwards.
4. Set `DESIGN_COMPILER` and `DESIGN_GAME_DATA`, restart, and let an admin designer build. Review the build's issues and `catalogDiff`; publish only once a released game reads format 3.

## 7. Restoring a backup

Rehearsed on copies on 2026-10-22 (the Windows test `node/backup.test.js` with the relay holding the database open, and on Ubuntu 26.04 with sqlite.org's sqlite3 3.50.4): the restored database had every table, the design tables row for row, and a relay on it served the live build's blobs.

```sh
sudo systemctl stop mgq-relay
STAMP=$(date +%Y%m%d-%H%M%S)
sudo -u mgq-relay mkdir /var/lib/mgq-relay/before-restore-$STAMP
sudo -u mgq-relay sh -c 'mv /var/lib/mgq-relay/relay.sqlite* /var/lib/mgq-relay/before-restore-'$STAMP'/'
sudo -u mgq-relay cp /var/backups/mgq-relay/relay-<date>.sqlite /var/lib/mgq-relay/relay.sqlite
sudo -u mgq-relay sqlite3 /var/lib/mgq-relay/relay.sqlite "PRAGMA integrity_check;"   # ok
sudo -u mgq-relay sqlite3 /var/lib/mgq-relay/relay.sqlite "DELETE FROM design_meta WHERE key = 'epoch';"
sudo systemctl start mgq-relay
journalctl -u mgq-relay -n 20                          # designs: the database holds pushes up to seq ... (when the relay noticed the restore itself)
```

Move the `-wal` and `-shm` files away with the database: a `-wal` left beside a restored copy would be replayed into it. Leave `relay.design-seq` where it is; the move above does not take it. Everything the relay took after the copy is lost: tell the designers and check the worlds.

**Why the epoch goes.** A restored database hands out the seqs it already handed out before, for other pushes, so a designer that pulled up to a later seq would skip them. The design epoch tells the designers apart from that: every pull, `GET /v1/designs/me` and socket greeting names it, a designer that meets another epoch than its cache holds pulls everything again and keeps its unpushed edits dirty on the restored revisions (an entity the backup lacks goes out again as a new one), and a push naming an older epoch is refused with `409 {code: "epoch"}`. The relay makes a new epoch when the design tables are made, when the epoch is missing (the `DELETE` above) and when the database holds fewer pushes than `relay.design-seq` says it handed out, so a restore without the `DELETE` is noticed too. The `DELETE` stays the rule for a restore onto another server or folder, where `relay.design-seq` is missing. A move with `node/migrate.js` keeps the epoch and the seqs, so the designers go on without pulling again.
