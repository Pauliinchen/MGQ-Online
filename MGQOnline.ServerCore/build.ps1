#----------------------------------------------------------------
#  build.ps1
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Builds MGQOnline.ServerCore.so, the battle server's core for linux-x64, in Docker on Ubuntu
# 24.04, whose glibc (2.39) is older than the server's, into bin\linux-x64. Needs Docker; the
# Release workflow runs it the same way.
#
#   .\MGQOnline.ServerCore\build.ps1 [-Version 0.6.9]

param(
    # The version the core names in the handshake.
    [string] $Version = '0.0.0-dev'
)

$ErrorActionPreference = 'Stop'

# The .NET 10 SDK image with NativeAOT's native tools (clang, zlib), pinned so a later build
# makes the same library.
$Image = 'mcr.microsoft.com/dotnet/sdk:10.0-noble-aot@sha256:9e172d8230f2bcd756a478b796bdf6fc79096bb6f05496b3c5382de82f94cda7'

$Repo = Join-Path $PSScriptRoot '..' | Resolve-Path
$Out = Join-Path $PSScriptRoot 'bin/linux-x64'
New-Item -ItemType Directory -Force $Out | Out-Null

# The NuGet cache lives in a volume of its own, so a second build downloads nothing.
docker run --rm `
    -v "${Repo}:/repo:ro" `
    -v "${Out}:/out" `
    -v 'mgq-server-core-nuget:/root/.nuget/packages' `
    -e DOTNET_CLI_TELEMETRY_OPTOUT=1 `
    -e DOTNET_NOLOGO=1 `
    $Image sh /repo/MGQOnline.ServerCore/container-build.sh $Version
if ($LASTEXITCODE -ne 0) { throw "the build failed with exit code $LASTEXITCODE" }
