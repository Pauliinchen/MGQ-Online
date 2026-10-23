#----------------------------------------------------------------
#  probe-local.ps1
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Runs the VPS kit (out\server-core-probe.tar.gz, see build.ps1) in a privileged Docker container
# of Ubuntu 26.04 with ruby3.3 from apt, as the VPS has, the same way the lead runs it there.

$ErrorActionPreference = 'Stop'

$Image = 'mgq-server-core-probe-ruby'
$Kit = Join-Path $PSScriptRoot 'out\server-core-probe.tar.gz'
if (-not (Test-Path $Kit)) { throw "build the kit first with build.ps1" }

$Dockerfile = @'
FROM ubuntu:26.04
RUN apt-get update && apt-get install -y --no-install-recommends ruby3.3 binutils procps && rm -rf /var/lib/apt/lists/*
'@
$Dockerfile | docker build -t $Image -
if ($LASTEXITCODE -ne 0) { throw "the image could not be built" }

# Privileged, so the sandbox can chroot, unshare its network and drop root as on the VPS.
docker run --rm --privileged -v "${Kit}:/kit.tar.gz:ro" $Image `
    bash -c 'tar -C /tmp -xzf /kit.tar.gz && bash /tmp/server-core-probe/run.sh'
if ($LASTEXITCODE -ne 0) { throw "the probe failed with exit code $LASTEXITCODE" }
