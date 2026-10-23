#----------------------------------------------------------------
#  core_check.ps1
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Runs core_check.rb against the linux-x64 core library (MGQOnline.ServerCore\build.ps1 builds
# it) in a privileged Docker container of Ubuntu 26.04 with ruby3.3 from apt, as the battle
# server's host has, so the sandbox can chroot, unshare its network and drop root as there.
#
#   .\BattleServer\tools\core_check.ps1 [-Library <path to MGQOnline.ServerCore.so>]

param(
    # The library to check; the one build.ps1 builds unless given.
    [string] $Library = (Join-Path $PSScriptRoot '../../MGQOnline.ServerCore/bin/linux-x64/MGQOnline.ServerCore.so')
)

$ErrorActionPreference = 'Stop'

$Image = 'mgq-battle-core-check'
$Repo = Join-Path $PSScriptRoot '../..' | Resolve-Path
if (-not (Test-Path $Library)) { throw "build the library first with MGQOnline.ServerCore\build.ps1" }
$Library = Resolve-Path $Library

$Dockerfile = @'
FROM ubuntu:26.04
RUN apt-get update && apt-get install -y --no-install-recommends ruby3.3 procps && rm -rf /var/lib/apt/lists/*
'@
$Dockerfile | docker build -t $Image -
if ($LASTEXITCODE -ne 0) { throw "the image could not be built" }

# No double quotes in the command: Windows PowerShell 5.1 passes them on to docker unescaped.
docker run --rm --privileged `
    -v "${Repo}:/repo:ro" `
    -v "${Library}:/core/MGQOnline.ServerCore.so:ro" `
    -e BATTLE_CORE_LIBRARY=/core/MGQOnline.ServerCore.so `
    $Image bash -c 'grep PRETTY_NAME /etc/os-release; uname -r; ruby3.3 -v; ruby3.3 -W0 /repo/BattleServer/tools/core_check.rb'
if ($LASTEXITCODE -ne 0) { throw "the check failed with exit code $LASTEXITCODE" }
