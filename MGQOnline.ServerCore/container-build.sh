#!/bin/sh
#----------------------------------------------------------------
#  container-build.sh
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Runs inside the .NET SDK container build.ps1 starts: publishes MGQOnline.ServerCore for
# linux-x64 into /out. /repo is the repository, mounted read-only; $1 is the version to stamp.
set -eu

VERSION="${1:-0.0.0-dev}"

# The projects the core is built from, copied without their bin/ and obj/, so no restore of
# another system meets the Windows one in the mounted folders.
PROJECTS="MGQOnline.Bridge MGQOnline.Bridge.Native MGQOnline.Game MGQOnline.ServerCore"

rm -rf /work
mkdir -p /work /out
cp /repo/Directory.Build.targets /work/
for project in $PROJECTS; do
    mkdir -p "/work/$project"
    tar -C "/repo/$project" --exclude=./bin --exclude=./obj -cf - . | tar -C "/work/$project" -xf -
done

dotnet publish /work/MGQOnline.ServerCore/MGQOnline.ServerCore.csproj -c Release -r linux-x64 \
    "-p:Version=$VERSION" -o /work/publish --nologo
cp /work/publish/MGQOnline.ServerCore.so /out/MGQOnline.ServerCore.so

lib=/out/MGQOnline.ServerCore.so
echo "built on: $(ldd --version | head -n 1), dotnet $(dotnet --version), version $VERSION"
echo "$lib: $(stat -c %s "$lib") bytes, sha256 $(sha256sum "$lib" | cut -d ' ' -f 1)"
readelf -d "$lib" | grep NEEDED
echo "newest glibc symbol: $(objdump -T "$lib" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -n 1)"
echo "exports: $(objdump -T "$lib" | grep -o 'mp_[a-z_]*' | sort -u | tr '\n' ' ')"
