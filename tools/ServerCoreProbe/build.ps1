#----------------------------------------------------------------
#  build.ps1
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Builds the probe library for linux-x64 in Docker, on Ubuntu 24.04, whose glibc (2.39) is older
# than the VPS's, and packs the VPS kit into out\server-core-probe.tar.gz. Needs Docker Desktop.

$ErrorActionPreference = 'Stop'

# The .NET 10 SDK image with NativeAOT's native tools (clang, zlib), pinned so a later build
# makes the same library.
$Image = 'mcr.microsoft.com/dotnet/sdk:10.0-noble-aot@sha256:9e172d8230f2bcd756a478b796bdf6fc79096bb6f05496b3c5382de82f94cda7'

$Probe = $PSScriptRoot
$BattleLib = Join-Path $PSScriptRoot '..\..\BattleServer\lib' | Resolve-Path

# The NuGet cache lives in a volume of its own, so a second build downloads nothing.
docker run --rm `
    -v "${Probe}:/probe" `
    -v "${BattleLib}:/battle:ro" `
    -v 'mgq-server-core-probe-nuget:/root/.nuget/packages' `
    -e DOTNET_CLI_TELEMETRY_OPTOUT=1 `
    -e DOTNET_NOLOGO=1 `
    $Image sh /probe/container-build.sh
if ($LASTEXITCODE -ne 0) { throw "the build failed with exit code $LASTEXITCODE" }
