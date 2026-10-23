#!/bin/sh
#----------------------------------------------------------------
#  container-build.sh
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Runs inside the .NET SDK container build.ps1 starts: publishes the probe library twice (without
# and with a baked GC heap limit) and assembles the VPS kit. /probe is the probe folder, out/ in
# it receives the results; /battle is the battle server's lib folder.
set -eu

# The heap limit baked into ServerCoreProbe.baked.so: 256 MB.
BAKED_LIMIT=268435456

# A copy outside the mounted folder, so no obj/ of a Linux restore lands next to the sources.
rm -rf /work
mkdir -p /work /probe/out
cp /probe/ServerCoreProbe.csproj /probe/Exports.cs /work/

publish() {
    dotnet publish /work/ServerCoreProbe.csproj -c Release -o "/work/publish-$1" --nologo "$2"
}
publish plain -p:BakedHeapHardLimit=
publish baked "-p:BakedHeapHardLimit=$BAKED_LIMIT"
cp /work/publish-plain/ServerCoreProbe.so /probe/out/ServerCoreProbe.so
cp /work/publish-baked/ServerCoreProbe.so /probe/out/ServerCoreProbe.baked.so

echo "built on: $(ldd --version | head -n 1), dotnet $(dotnet --version)"
for lib in /probe/out/ServerCoreProbe.so /probe/out/ServerCoreProbe.baked.so; do
    echo "$lib: $(stat -c %s "$lib") bytes"
    readelf -d "$lib" | grep NEEDED
    echo "newest glibc symbol: $(objdump -T "$lib" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -n 1)"
done

# The kit the lead copies to the VPS: everything probe.rb needs, sandbox.rb taken from the
# battle server as it is.
kit=/work/server-core-probe
mkdir -p "$kit"
cp /probe/vps/run.sh /probe/probe.rb /battle/sandbox.rb /probe/out/ServerCoreProbe.so /probe/out/ServerCoreProbe.baked.so "$kit/"
tar -C /work -czf /probe/out/server-core-probe.tar.gz server-core-probe
echo "kit: /probe/out/server-core-probe.tar.gz"
