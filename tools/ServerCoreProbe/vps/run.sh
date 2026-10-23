#!/bin/bash
#----------------------------------------------------------------
#  run.sh
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Runs the probe on the VPS as root, as the battle server runs, from the kit unpacked into
# /tmp/server-core-probe, and removes the kit afterwards. It reads the running battle server's
# memory from /proc and touches nothing else of it: no file in /opt, no service, no setting.
set -u

KIT=/tmp/server-core-probe

if [ "$(cd "$(dirname "$0")" && pwd)" != "$KIT" ]; then
    echo "unpack the kit into /tmp, so it runs from $KIT" >&2
    exit 1
fi
if [ "$(id -u)" != 0 ]; then
    echo "run it with sudo: the sandbox needs root, as the battle server does" >&2
    exit 1
fi
trap 'rm -rf "$KIT"' EXIT

RUBY=$(command -v ruby3.3 || command -v ruby)
echo "host: $(. /etc/os-release && echo "$PRETTY_NAME"), kernel $(uname -r), $(ldd --version | head -n 1)"
echo "ruby: $("$RUBY" -v)"
echo "library needs: $(objdump -T "$KIT/ServerCoreProbe.so" 2>/dev/null | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -n 1)"

# The children start with the address space of the battle server's parent when it runs.
PARENT_MB=1229
SERVER_PID=$(systemctl show -p MainPID --value mgq-battle 2>/dev/null || echo 0)
if [ -n "$SERVER_PID" ] && [ "$SERVER_PID" != 0 ] && [ -r "/proc/$SERVER_PID/status" ]; then
    echo "battle server parent $SERVER_PID: $(grep -E '^(VmSize|VmRSS|Threads):' "/proc/$SERVER_PID/status" | tr -s ' \t\n' ' ')"
    PARENT_MB=$(awk '/^VmSize:/ { print int($2 / 1024) }' "/proc/$SERVER_PID/status")
    echo "nobody runs $(ps -L -u nobody --no-headers 2>/dev/null | wc -l) threads now (the sandbox allows 1024 in all)"
fi

# As the battle server's game folder: owned by root, written by nobody else.
chown -R root:root "$KIT"
chmod -R go-w "$KIT"
mkdir -p "$KIT/root"

PROBE_PARENT_MB=$PARENT_MB PROBE_ROOT="$KIT/root" "$RUBY" "$KIT/probe.rb" "$KIT/ServerCoreProbe.so" "$KIT/ServerCoreProbe.baked.so"
