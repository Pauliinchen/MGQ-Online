#----------------------------------------------------------------
#  Update.ps1
#
#  Changelog:
#      Paulinchen  2026-10-08: Took the game's process from the game that starts the update, waited for it to close and started the game again afterwards, in the Multiplayer menu once updated
#      Paulinchen  2026-10-04: Showed the release notes last and counted the removed files in one line, so they no longer push the notes out of sight
#      Paulinchen  2026-09-30: Found the game folder two levels up, since the mod lives in Patch\Multiplayer
#                            - Fetched MGQ-Online-<version>.zip from the repository under its new name, MGQ-Online
#                            - Created
#
#----------------------------------------------------------------

# Updates the mod in the game folder two levels above this one (this script lives in
# Patch\Multiplayer) to the latest release on GitHub, removing files an earlier version left behind
# that the new one no longer ships, such as a script a later refactor renamed or merged into
# another. Update.bat runs it, started by the player or by the game.

param(
    # The game's process when the game started the update: the update waits for it to close and
    # starts the game again afterwards.
    [int]$GameProcess = 0
)

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

# Tells the game started again to open the Multiplayer menu, see world.rbx.
$OpenWorldsVariable = 'MGQMP_OPEN_WORLDS'

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
#
# Returns how many files were removed.
function Remove-StaleFiles([string[]]$Old, [string[]]$New) {
    $stale = $Old | Where-Object { $_ -notin $New -and ($_ -like 'Multiplayer\*' -or $_ -like 'Patch\*') }
    $removed = 0

    foreach ($relative in $stale) {
        $full = Join-Path $GameDir $relative
        if (Test-Path $full) {
            Remove-Item $full -Force
            $removed++
        }
    }

    return $removed
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

# Waits until the game in this folder is closed, which unlocks the DLL: first for the game that
# started the update, then for any other copy the player has to close.
function Wait-GameClosed {
    if ($GameProcess -gt 0) {
        Write-Host 'Waiting for the game to close . . .'
        Wait-Process -Id $GameProcess -ErrorAction SilentlyContinue
    }

    while (Test-GameRunning) {
        Read-Host 'The game is running. Close it, then press Enter' | Out-Null
    }
}

# Starts the game again after an update the game started.
#
# $OpenMultiplayer: whether the game opens the Multiplayer menu, once the mod is up to date.
function Start-GameAgain([bool]$OpenMultiplayer) {
    Wait-GameClosed

    if ($OpenMultiplayer) {
        # The game inherits this process's environment.
        Set-Item "env:$OpenWorldsVariable" '1'
    }

    Write-Host 'Starting the game again . . .'
    Start-Process -FilePath $GameExe -WorkingDirectory $GameDir
}

# Installs the latest release over the game folder, unless the mod is up to date.
#
# Returns $true once the mod is up to date.
function Install-LatestRelease {
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
        return $true
    }

    $zip = $release.assets | Where-Object { $_.name -like $ReleaseZip } | Select-Object -First 1
    if (-not $zip) {
        throw "Release $latest has no download yet. Try again in a few minutes."
    }

    $from = if ($installed) { $installed } else { 'an unknown version' }
    Write-Host "Updating from $from to $latest."

    Wait-GameClosed

    $oldFiles = Get-ShippedFiles

    $download = Join-Path $env:TEMP $zip.name
    Write-Host "Downloading $($zip.name) . . ."
    Invoke-WebRequest -Uri $zip.browser_download_url -OutFile $download -UserAgent $UserAgent -UseBasicParsing

    Expand-Archive -Path $download -DestinationPath $GameDir -Force
    Remove-Item $download

    $removed = Remove-StaleFiles -Old $oldFiles -New (Get-ShippedFiles)
    if ($removed -gt 0) {
        Write-Host "Removed $removed file(s) of the old version that the new one no longer ships."
    }

    Write-Host "Updated to $latest. Your player name and worlds are kept."
    # Last, so nothing the update prints scrolls the notes out of sight.
    Show-ReleaseNotes $release
    return $true
}

$updated = $false
try {
    $updated = Install-LatestRelease
}
catch {
    Write-Host "The update failed: $($_.Exception.Message)" -ForegroundColor Red
}

if ($GameProcess -gt 0) {
    if (-not $updated) {
        Read-Host 'Press Enter to start the game again' | Out-Null
    }

    try {
        Start-GameAgain -OpenMultiplayer $updated
    }
    catch {
        Write-Host "The game could not start again: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not $updated) {
    exit 1
}
