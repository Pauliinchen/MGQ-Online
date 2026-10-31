#!/bin/sh
#----------------------------------------------------------------
#  backup-relay.sh
#
#  Changelog:
#      Paulinchen  2026-10-22: Named a missing worlds table in the backup line
#                            - Created
#
#----------------------------------------------------------------

# Copies the relay's SQLite database with sqlite3's online backup into BACKUP_DIR as
# relay-<date>.sqlite, checks the copy, and keeps the newest BACKUP_KEEP copies. The copy holds
# every table, the Raid design tables and their blobs too; the line it writes counts their rows.
#
#   MGQ_RELAY_DB=/var/lib/mgq-relay/relay.sqlite BACKUP_DIR=/var/backups/mgq-relay BACKUP_KEEP=14 backup-relay.sh
#
# Run it as the relay's own user (mgq-relay-backup.service does): sqlite3 may create the
# database's -wal and -shm files, and files another user owns lock the relay out of its database.

set -eu

DB="${MGQ_RELAY_DB:-/var/lib/mgq-relay/relay.sqlite}"
DEST="${BACKUP_DIR:-/var/backups/mgq-relay}"
KEEP="${BACKUP_KEEP:-14}"
SQLITE3="${SQLITE3:-sqlite3}"
# How long the backup waits for the relay's write lock, in milliseconds.
BUSY_MS=30000

# Writes a failure to stderr and ends the script with exit code 1.
fail() {
    echo "backup-relay: $*" >&2
    exit 1
}

# Runs one SQL statement on the copy; sqlite3 builds for Windows end their lines with CR LF.
query() {
    "$SQLITE3" "$PARTIAL" "$1" | tr -d '\r'
}

case "$KEEP" in
    ''|*[!0-9]*|0) fail "BACKUP_KEEP must be a whole number above 0, not '$KEEP'" ;;
esac

case "$DB$DEST" in
    *"'"*) fail "the database and backup paths must not hold a single quote" ;;
esac

command -v "$SQLITE3" >/dev/null 2>&1 || fail "$SQLITE3 is missing (apt install sqlite3)"
[ -f "$DB" ] || fail "the database $DB is missing"

umask 077
mkdir -p "$DEST"

TARGET="$DEST/relay-$(date +%F).sqlite"
PARTIAL="$DEST/.relay-backup.$$.partial"
trap 'rm -f "$PARTIAL"' EXIT

"$SQLITE3" "$DB" ".timeout $BUSY_MS" ".backup '$PARTIAL'" || fail "sqlite3 could not back up $DB"

CHECK="$(query "PRAGMA integrity_check;")"
[ "$CHECK" = "ok" ] || fail "the copy of $DB failed its integrity check: $CHECK"

COUNTS="$(query "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'design%' ORDER BY name;" | while read -r TABLE; do
    printf ' %s=%s' "$TABLE" "$(query "SELECT count(*) FROM \"$TABLE\";")"
done)"
STEP="$(query "PRAGMA user_version;")"
# A pipeline answers with the status of its last command, so the table is looked up, not queried blind.
if [ "$(query "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'worlds';")" = "1" ]; then
    WORLDS="$(query "SELECT count(*) FROM worlds;") worlds"
else
    WORLDS="no worlds table"
fi

mv -f "$PARTIAL" "$TARGET"
trap - EXIT

COPIES="$(ls -1 "$DEST" | grep -c '^relay-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\.sqlite$' || true)"
EXCESS=$((COPIES - KEEP))

# The dates in the names sort the copies oldest first.
if [ "$EXCESS" -gt 0 ]; then
    ls -1 "$DEST" | grep '^relay-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\.sqlite$' | sort | head -n "$EXCESS" | while read -r OLD; do
        rm -f "$DEST/$OLD"
    done
fi

echo "backup-relay: $DB -> $TARGET ($(wc -c < "$TARGET" | tr -d ' ') bytes, step $STEP, $WORLDS,${COUNTS:- no design tables}), keeping $((COPIES < KEEP ? COPIES : KEEP)) copies"
