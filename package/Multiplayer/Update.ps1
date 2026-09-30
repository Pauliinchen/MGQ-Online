#----------------------------------------------------------------
#  Update.ps1
#
#  Changelog:
#      Paulinchen  2026-09-30: Found the game folder two levels up, since the mod lives in Patch\Multiplayer
#                            - Fetched MGQ-Online-<version>.zip from the repository under its new name, MGQ-Online
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Updates the mod in the game folder two levels above this one (this script lives in
# Patch\Multiplayer) to the latest release on GitHub, removing files an earlier version left behind
# that the new one no longer ships, such as a script a later refactor renamed or merged into
# another. Update.bat runs it.

$ErrorActionPreference = 'Stop'

# Invoke-WebRequest slows to a crawl while it draws its progress bar.
$ProgressPreference = 'SilentlyContinue'

$LatestReleaseUrl = 'https://api.github.com/repos/Pauliinchen/MGQ-Online/releases/latest'
$UserAgent        = 'MGQ-Online'
$ReleaseZip       = 'MGQ-Online-*.zip'

$ModDir   = $PSScriptRoot
$GameDir  = Split-Path (Split-Path $ModDir -Parent) -Parent
$GameExe  = Join-Path $GameDir 'Game.exe'
$Dll      = Join-Path $ModDir 'Multiplayer.dll'
$Manifest = Join-Path $ModDir 'Manifest.txt'

# Reads the version of the installed DLL.
#
# Returns the version, or $null when there is no DLL or it is a development build like 0.0.0-dev.
function Get-InstalledVersion {
    if (-not (Test-Path $Dll)) {
        return $null
    }

    $version = (Get-Item $Dll).VersionInfo.ProductVersion.Split('+')[0]
    if ($version.Contains('-')) {
        return $null
    }

    return [version]$version
}

# Reports whether the game in this folder is running, which locks the DLL.
function Test-GameRunning {
    $name = [IO.Path]::GetFileNameWithoutExtension($GameExe)
    return [bool](Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $GameExe })
}

# Reads Manifest.txt, every file the installed release ships, relative to the game folder.
#
# Returns the paths, empty when there is none: an install from before this mod shipped a manifest,
# or a fresh extract that never ran this updater.
function Get-ShippedFiles {
    if (-not (Test-Path $Manifest)) {
        return @()
    }

    return @(Get-Content $Manifest | Where-Object { $_.Trim() -ne '' })
}

# Deletes files the old release shipped that the new one does not.
#
# A manifest only ever lists files a release shipped, under Patch\ (or Multiplayer\ next to
# Game.exe, before the mod moved into Patch\Multiplayer), so this never comes near Player.ini,
# Favourites.ini, the worlds or the logs, which no release ships.
#
# $Old: the old manifest's paths.
# $New: the new manifest's paths.
function Remove-StaleFiles([string[]]$Old, [string[]]$New) {
    $stale = $Old | Where-Object { $_ -notin $New -and ($_ -like 'Multiplayer\*' -or $_ -like 'Patch\*') }

    foreach ($relative in $stale) {
        $full = Join-Path $GameDir $relative
        if (Test-Path $full) {
            Remove-Item $full -Force
            Write-Host "Removed $relative, which the new release no longer ships."
        }
    }
}

# Prints a release's notes.
#
# $Release: the release, as GitHub's API describes it.
function Show-ReleaseNotes($Release) {
    Write-Host ''
    Write-Host "What's new in $($Release.tag_name):"
    Write-Host ('-' * 60)

    if ([string]::IsNullOrWhiteSpace($Release.body)) {
        Write-Host "See $($Release.html_url)"
    }
    else {
        Write-Host ($Release.body -replace "`r`n", "`n").Trim()
    }

    Write-Host ('-' * 60)
    Write-Host ''
}

try {
    if (-not (Test-Path $GameExe)) {
        throw "Game.exe is not in $GameDir. Keep this script in Patch\Multiplayer inside the game folder."
    }

    # Windows PowerShell 5.1 may still default to TLS 1.0, which GitHub refuses.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Write-Host 'Looking for the latest release . . .'
    $release = Invoke-RestMethod -Uri $LatestReleaseUrl -UserAgent $UserAgent -UseBasicParsing
    $latest = [version]$release.tag_name.TrimStart('v')
    $installed = Get-InstalledVersion

    if ($installed -and $installed -ge $latest) {
        Write-Host "The mod is up to date ($installed)."
        return
    }

    $zip = $release.assets | Where-Object { $_.name -like $ReleaseZip } | Select-Object -First 1
    if (-not $zip) {
        throw "Release $latest has no download yet. Try again in a few minutes."
    }

    $from = if ($installed) { $installed } else { 'an unknown version' }
    Write-Host "Updating from $from to $latest."
    Show-ReleaseNotes $release

    while (Test-GameRunning) {
        Read-Host 'The game is running. Close it, then press Enter' | Out-Null
    }

    $oldFiles = Get-ShippedFiles

    $download = Join-Path $env:TEMP $zip.name
    Write-Host "Downloading $($zip.name) . . ."
    Invoke-WebRequest -Uri $zip.browser_download_url -OutFile $download -UserAgent $UserAgent -UseBasicParsing

    Expand-Archive -Path $download -DestinationPath $GameDir -Force
    Remove-Item $download

    Remove-StaleFiles -Old $oldFiles -New (Get-ShippedFiles)

    Write-Host "Updated to $latest. Your player name and worlds are kept."
}
catch {
    Write-Host "The update failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
