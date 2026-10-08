#----------------------------------------------------------------
#  Update.ps1
#
#  Changelog:
#      Paulinchen  2026-10-08: Took the game's process from the game that starts the update, waited for it to close and started the game again afterwards, in the Multiplayer menu once updated
#                            - Held the game's process from the start and waited on it, so a later wait never hangs on another program Windows gave its id
#                            - Took every path literally, so a game folder with brackets in its name updates and starts again
#                            - Extracted the release and downloaded it through .NET, which take paths as they are
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

# Every path below goes to cmdlets through -LiteralPath or to .NET, since PowerShell takes [ and ]
# in -Path as wildcards, and a game folder such as 'MGQ Paradox [EN]' would match nothing.
$ModDir   = $PSScriptRoot
$GameDir  = [IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($ModDir))
$GameExe  = [IO.Path]::Combine($GameDir, 'Game.exe')
$Dll      = [IO.Path]::Combine($ModDir, 'Multiplayer.dll')
$Manifest = [IO.Path]::Combine($ModDir, 'Manifest.txt')

# Tells the game started again to open the Multiplayer menu, see world.rbx.
$OpenWorldsVariable = 'MGQMP_OPEN_WORLDS'

# Takes the game that started the update by its process id, once, while it still runs.
#
# The process object keeps its handle, so waiting on it later never waits on another program that
# Windows gave the same id once the game closed.
#
# Returns the game's process, or $null when no game started the update, it closed already, or the
# id names another program.
function Get-StartingGame {
    if ($GameProcess -le 0) {
        return $null
    }

    try {
        $process = Get-Process -Id $GameProcess -ErrorAction Stop
        # Reading the handle opens it, which holds the process until this script ends.
        $null = $process.Handle
        # Windows may deny the path of a process, whose id the game handed over a moment ago.
        if ($null -eq $process.Path -or $process.Path -eq $GameExe) {
            return $process
        }
    }
    catch {
    }

    return $null
}

$StartingGame = Get-StartingGame

# Reads the version of the installed DLL.
#
# Returns the version, or $null when there is no DLL or it is a development build like 0.0.0-dev.
function Get-InstalledVersion {
    if (-not (Test-Path -LiteralPath $Dll)) {
        return $null
    }

    $version = (Get-Item -LiteralPath $Dll).VersionInfo.ProductVersion.Split('+')[0]
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
    if (-not (Test-Path -LiteralPath $Manifest)) {
        return @()
    }

    return @(Get-Content -LiteralPath $Manifest | Where-Object { $_.Trim() -ne '' })
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
        $full = [IO.Path]::Combine($GameDir, $relative)
        if (Test-Path -LiteralPath $full) {
            Remove-Item -LiteralPath $full -Force
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
    if ($StartingGame -and -not $StartingGame.HasExited) {
        Write-Host 'Waiting for the game to close . . .'
        $StartingGame.WaitForExit()
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
        [Environment]::SetEnvironmentVariable($OpenWorldsVariable, '1')
    }

    Write-Host 'Starting the game again . . .'
    $start = New-Object System.Diagnostics.ProcessStartInfo $GameExe
    $start.WorkingDirectory = $GameDir
    $start.UseShellExecute = $false
    $null = [Diagnostics.Process]::Start($start)
}

# Extracts a release's zip over the game folder, replacing the files it holds.
#
# Expand-Archive takes the destination as a wildcard path in Windows PowerShell 5.1, so .NET does
# the work.
#
# $Zip: the zip.
function Expand-Release([string]$Zip) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $root = [IO.Path]::GetFullPath($GameDir).TrimEnd('\') + '\'
    $archive = [IO.Compression.ZipFile]::OpenRead($Zip)

    try {
        foreach ($entry in $archive.Entries) {
            $target = [IO.Path]::GetFullPath([IO.Path]::Combine($root, $entry.FullName))
            if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                throw "The download holds a file outside the game folder: $($entry.FullName)"
            }

            # A folder's entry has no name, only a path that ends in a slash.
            if ($entry.Name -eq '') {
                $null = [IO.Directory]::CreateDirectory($target)
                continue
            }

            $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    }
    finally {
        $archive.Dispose()
    }
}

# Installs the latest release over the game folder, unless the mod is up to date.
#
# Returns $true once the mod is up to date.
function Install-LatestRelease {
    if (-not (Test-Path -LiteralPath $GameExe)) {
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

    $download = [IO.Path]::Combine([IO.Path]::GetTempPath(), $zip.name)
    Write-Host "Downloading $($zip.name) . . ."
    # WebClient writes to the path as it is, which -OutFile would not promise for one with brackets.
    $client = New-Object System.Net.WebClient
    try {
        $client.Headers.Add('User-Agent', $UserAgent)
        $client.DownloadFile($zip.browser_download_url, $download)
    }
    finally {
        $client.Dispose()
    }

    Expand-Release $download
    Remove-Item -LiteralPath $download

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
