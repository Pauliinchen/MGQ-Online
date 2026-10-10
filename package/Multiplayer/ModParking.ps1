#----------------------------------------------------------------
#  ModParking.ps1
#
#  Changelog:
#      Paulinchen  2026-10-10: Cleared the read-only attribute before a parked file is deleted or moved
#                            - Sent a parked file whose hash differs from the journal's to the conflicts folder
#                            - Skipped a script whose path cannot be resolved instead of ending the restore
#                            - Reached parked scripts in paths over 260 characters through extended paths
#                            - Kept polling when the journal cannot be read for a moment
#                            - Gave up after ten minutes of a journal that cannot be read
#                            - Did not start the game into the world when the journal cannot be read
#                            - Set the read-only attribute again on a parked file wherever it ended up
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# Watches a game that parked mods for a world that turns other mods off: waits for it to close,
# starts it again into the world when it rejoins, and moves the parked mods back into Patch once no
# game of the folder runs any more, whichever way the game closed, a crash included. The DLL starts
# it hidden (GameRestart.WatchParked) and keeps the rules of ModParking.cs: a mod whose place in
# Patch is taken goes to "Parked mods\Conflicts", and nothing is ever overwritten.

param(
    # The game that parked the mods, whose closing this script waits for.
    [int]$GameProcess = 0,

    # The game folder, which holds Game.exe, Patch and "Parked mods".
    [string]$GameFolder = '',

    # 'rejoin' starts the game again into the world once it closed; 'title' only brings the mods
    # back, and starts the game to the title when the journal asks for it.
    [ValidateSet('rejoin', 'title')]
    [string]$Mode = 'title',

    # The id the DLL wrote into the journal for this watchdog; a journal naming another belongs to a
    # later watchdog, which this one leaves it to.
    [string]$Watch = '',

    # How long the journal may stay unreadable before the watchdog gives up and leaves the parked
    # mods to the recovery at the next game start; only tests pass less.
    [int]$UnreadableSeconds = 600
)

$ErrorActionPreference = 'Stop'

# Every path below goes to .NET, since PowerShell takes [ and ] in -Path as wildcards, and a game
# folder such as 'MGQ Paradox [EN]' would match nothing.
$GameExe     = [IO.Path]::Combine($GameFolder, 'Game.exe')
$PatchDir    = [IO.Path]::Combine($GameFolder, 'Patch')
$ParkedDir   = [IO.Path]::Combine($GameFolder, 'Parked mods')
$Journal     = [IO.Path]::Combine($ParkedDir, 'Parked.txt')
$ModDir      = [IO.Path]::Combine($PatchDir, 'Multiplayer')
$LockFile    = [IO.Path]::Combine($ModDir, 'Parking.lock')
$Updater     = [IO.Path]::Combine($ModDir, 'Update.ps1')
$LogDir      = [IO.Path]::Combine($GameFolder, 'Logs')
$LogFile     = [IO.Path]::Combine($LogDir, 'Multiplayer Parking.log')
$OldLogFile  = [IO.Path]::Combine($LogDir, 'Multiplayer Parking.old.log')
$MaxLogBytes = 262144
$PollMilliseconds = 1000
$JournalFailingSince = $null

# Appends a line to the watchdog's own log, which moves aside once it grew past $MaxLogBytes, so it
# never needs the scripts' pruning of the session logs.
#
# $Message: the line.
function Write-Log([string]$Message) {
    try {
        $null = [IO.Directory]::CreateDirectory($LogDir)
        if ([IO.File]::Exists($LogFile) -and (New-Object IO.FileInfo $LogFile).Length -gt $MaxLogBytes) {
            if ([IO.File]::Exists($OldLogFile)) {
                [IO.File]::Delete($OldLogFile)
            }
            [IO.File]::Move($LogFile, $OldLogFile)
        }

        $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $PID, $Message
        [IO.File]::AppendAllText($LogFile, $line + "`r`n", (New-Object Text.UTF8Encoding $false))
    }
    catch {
    }
}

# Takes the game that parked the mods by its process id, once, while it still runs.
#
# The process object keeps its handle, so waiting on it later never waits on another program that
# Windows gave the same id once the game closed.
#
# Returns the game's process, or $null when it closed already or the id names another program.
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

# Reports whether a game of this folder runs.
function Test-GameRunning {
    $name = [IO.Path]::GetFileNameWithoutExtension($GameExe)
    return [bool](Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $GameExe })
}

# Reports whether the mod's updater of this folder runs, which starts the game itself once done.
function Test-UpdaterRunning {
    try {
        $needle = $Updater.ToLowerInvariant()
        foreach ($process in Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'") {
            if ($process.CommandLine -and $process.CommandLine.ToLowerInvariant().Contains($needle)) {
                return $true
            }
        }
    }
    catch {
        Write-Log "could not look for the updater: $($_.Exception.Message)"
    }

    return $false
}

# Reports whether an update was asked for, in which case the updater starts the game and this
# script never does.
#
# $Parked: the journal, or $null.
function Test-UpdateAsked($Parked) {
    return ($Parked -and $Parked.Update) -or (Test-UpdaterRunning)
}

# Reads the journal the DLL writes, see ModParking.cs.
#
# Returns the world, what happens afterwards, the update mark, the watchdog's id, the parked
# scripts relative to the game folder and their hashes by script; $null when there is no journal.
function Read-Journal {
    $text = $null
    for ($attempt = 1; $null -eq $text; $attempt++) {
        if (-not [IO.File]::Exists($Journal)) {
            return $null
        }

        try {
            # Shared for writing and deleting, so a game replacing or deleting the journal meanwhile
            # never fails because this script reads it.
            $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
            $stream = New-Object IO.FileStream($Journal, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
            try {
                $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding $false))
                $text = $reader.ReadToEnd()
            }
            finally {
                $stream.Dispose()
            }
        }
        catch {
            if (-not [IO.File]::Exists($Journal)) {
                return $null
            }

            if ($attempt -ge 5) {
                throw
            }

            Start-Sleep -Milliseconds 100
        }
    }

    $parked = @{ World = ''; After = 'none'; Update = $false; Watch = ''; Files = (New-Object System.Collections.ArrayList); Hashes = @{} }
    foreach ($line in $text.Split("`n")) {
        $fields = $line.TrimEnd("`r").Split("`t")
        switch ($fields[0]) {
            'world'  { if ($fields.Count -eq 2) { $parked.World = $fields[1] } }
            'after'  { if ($fields.Count -eq 2) { $parked.After = $fields[1] } }
            'update' { if ($fields.Count -eq 2) { $parked.Update = $fields[1] -eq '1' } }
            'watch'  { if ($fields.Count -eq 2) { $parked.Watch = $fields[1] } }
            'file'   {
                if ($fields.Count -eq 4 -and $fields[1] -ne '') {
                    $null = $parked.Files.Add($fields[1])
                    $parked.Hashes[$fields[1]] = $fields[2]
                }
            }
        }
    }

    return $parked
}

# Reads the journal in the poll loop, where a failure must not end the watchdog: it logs the first
# failure of a run of them and answers that the journal is unknown for now.
#
# Returns what Read-Journal returns, or $false when the journal could not be read.
function Read-JournalWhilePolling {
    try {
        $parked = Read-Journal
        $script:JournalFailingSince = $null
        return $parked
    }
    catch {
        if ($null -eq $script:JournalFailingSince) {
            Write-Log "the journal could not be read, trying again: $($_.Exception.Message)"
            $script:JournalFailingSince = [DateTime]::UtcNow
        }
        return $false
    }
}

# Waits one poll after the journal could not be read, or ends the watchdog once it stayed unreadable
# for $UnreadableSeconds, so a journal that never becomes readable again keeps no hidden process alive.
function Wait-UnreadableJournal {
    if (([DateTime]::UtcNow - $script:JournalFailingSince).TotalSeconds -ge $UnreadableSeconds) {
        Write-Log "the journal stayed unreadable for $UnreadableSeconds seconds, so the next game start brings the mods back"
        exit 1
    }

    Start-Sleep -Milliseconds $PollMilliseconds
}

# Prefixes a full path on a drive with \\?\, without which Windows PowerShell reports a file in a
# path longer than 260 characters as missing, so a long parked path would count as restored.
#
# $Path: the full path.
#
# Returns the prefixed path; the path itself when it lies on no drive.
function ConvertTo-LongPath([string]$Path) {
    if ($Path -match '^[A-Za-z]:\\') {
        return '\\?\' + $Path
    }

    return $Path
}

# Clears a file's read-only attribute, which keeps it from being deleted and from a move that copies.
#
# $Path: the file.
#
# Returns whether it was read-only.
function Clear-ReadOnly([string]$Path) {
    $attributes = [IO.File]::GetAttributes($Path)
    if (-not ($attributes -band [IO.FileAttributes]::ReadOnly)) {
        return $false
    }

    [IO.File]::SetAttributes($Path, ($attributes -band -bnot [IO.FileAttributes]::ReadOnly))
    return $true
}

# Sets a file's read-only attribute again that Clear-ReadOnly cleared. A failure only logs, since the
# move before it happened.
#
# $Path: the file.
# $ReadOnly: whether it was read-only; nothing happens otherwise.
function Set-ReadOnlyAgain([string]$Path, [bool]$ReadOnly) {
    if (-not $ReadOnly) {
        return
    }

    try {
        [IO.File]::SetAttributes($Path, ([IO.File]::GetAttributes($Path) -bor [IO.FileAttributes]::ReadOnly))
    }
    catch {
        Write-Log "$Path could not be made read-only again: $($_.Exception.Message)"
    }
}

# Moves a file without overwriting, its read-only attribute cleared for the move and set again
# wherever the file ends up.
#
# $Source: the file.
# $Destination: where it goes.
function Move-KeepingReadOnly([string]$Source, [string]$Destination) {
    $readOnly = Clear-ReadOnly $Source
    try {
        [IO.File]::Move($Source, $Destination)
    }
    catch {
        Set-ReadOnlyAgain $Source $readOnly
        throw
    }

    Set-ReadOnlyAgain $Destination $readOnly
}

# Deletes a file, its read-only attribute cleared first and set again when the delete fails.
#
# $Path: the file.
function Remove-KeepingReadOnly([string]$Path) {
    $readOnly = Clear-ReadOnly $Path
    try {
        [IO.File]::Delete($Path)
    }
    catch {
        Set-ReadOnlyAgain $Path $readOnly
        throw
    }
}

# Hashes a mod's file as the DLL's ModHash does: SHA-256 in lowercase hexadecimal, a script without
# its carriage returns.
#
# $Path: the file.
function Get-ModHash([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($Path.EndsWith('.rb', [StringComparison]::OrdinalIgnoreCase)) {
        # Latin-1 maps every byte to one character and back, so only the carriage returns go.
        $latin = [Text.Encoding]::GetEncoding(28591)
        $bytes = $latin.GetBytes($latin.GetString($bytes).Replace("`r", ''))
    }

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
    }
    finally {
        $sha.Dispose()
    }

    return -join ($hash | ForEach-Object { $_.ToString('x2') })
}

# Names this restore's folder in "Parked mods\Conflicts": the time, and a number when that folder
# exists already.
function New-ConflictStamp {
    $time = Get-Date -Format 'yyyy-MM-dd HH-mm-ss'
    $stamp = $time
    $number = 2
    while ([IO.Directory]::Exists([IO.Path]::Combine($ParkedDir, 'Conflicts', $stamp))) {
        $stamp = "$time ($number)"
        $number++
    }

    return $stamp
}

# Opens the lock every game of this folder holds while it runs, so no game starts moving mods
# while this script does. The lock goes once closed, as a game's does.
#
# Returns the open lock, or $null while a game holds it.
function Open-Lock {
    try {
        $null = [IO.Directory]::CreateDirectory($ModDir)
        return New-Object IO.FileStream($LockFile, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 1, [IO.FileOptions]::DeleteOnClose)
    }
    catch {
        return $null
    }
}

# Moves every parked script back into Patch, or into the conflicts folder when another file took
# its place or it is not the file the DLL parked; drops the parked copy when the one in its place is
# the same. Deletes the journal once every script is handled.
#
# $Parked: the journal.
#
# Returns $true once nothing is parked any more.
function Restore-ParkedMods($Parked) {
    $patchRoot = [IO.Path]::GetFullPath($PatchDir).TrimEnd('\') + '\'
    $stamp = $null
    $failed = 0

    foreach ($relative in $Parked.Files) {
        $native = $relative.Replace('/', '\')

        try {
            $parkedFile = [IO.Path]::GetFullPath([IO.Path]::Combine($ParkedDir, $native))
            $original = [IO.Path]::GetFullPath([IO.Path]::Combine($GameFolder, $native))

            if (-not $original.StartsWith($patchRoot, [StringComparison]::OrdinalIgnoreCase)) {
                Write-Log "skipped $relative, which lies outside Patch"
                continue
            }

            $parkedFile = ConvertTo-LongPath $parkedFile
            $original = ConvertTo-LongPath $original
            if (-not [IO.File]::Exists($parkedFile)) {
                continue
            }

            $parkedHash = Get-ModHash $parkedFile
            $journalHash = $Parked.Hashes[$relative]
            $stranger = $journalHash -and $parkedHash -ne $journalHash
            if ($stranger -or [IO.File]::Exists($original)) {
                if (-not $stranger -and (Get-ModHash $original) -eq $parkedHash) {
                    Remove-KeepingReadOnly $parkedFile
                    Write-Log "$relative is back in Patch already, the parked copy is dropped"
                    continue
                }

                if (-not $stamp) {
                    $stamp = New-ConflictStamp
                }

                $aside = ConvertTo-LongPath ([IO.Path]::GetFullPath([IO.Path]::Combine($ParkedDir, 'Conflicts', $stamp, $native)))
                $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($aside))
                Move-KeepingReadOnly $parkedFile $aside
                if ($stranger) {
                    Write-Log "parked $relative is not the file the tool parked, so it went to Conflicts\$stamp instead of Patch"
                }
                else {
                    Write-Log "$relative has another file in its place in Patch, so the parked one went to Conflicts\$stamp"
                }
                continue
            }

            $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($original))
            Move-KeepingReadOnly $parkedFile $original
            Write-Log "restored $relative"
        }
        catch {
            $failed++
            Write-Log "restoring $relative failed: $($_.Exception.Message)"
        }
    }

    if ($failed -gt 0) {
        Write-Log "$failed parked mod(s) could not be moved; the game moves them back as it starts"
        return $false
    }

    [IO.File]::Delete($Journal)

    # Every mod is back once the journal is gone, so empty folders that stay are no failure. The
    # parking folder stays only while it holds conflicts.
    try {
        $parkedPatch = ConvertTo-LongPath ([IO.Path]::GetFullPath([IO.Path]::Combine($ParkedDir, 'Patch')))
        if ([IO.Directory]::Exists($parkedPatch) -and [IO.Directory]::GetFiles($parkedPatch, '*', [IO.SearchOption]::AllDirectories).Count -eq 0) {
            [IO.Directory]::Delete($parkedPatch, $true)
        }

        if ([IO.Directory]::Exists($ParkedDir) -and [IO.Directory]::GetFileSystemEntries($ParkedDir).Count -eq 0) {
            [IO.Directory]::Delete($ParkedDir)
        }
    }
    catch {
        Write-Log "the empty folders of the parked mods could not be removed: $($_.Exception.Message)"
    }

    return $true
}

# Starts the game in its folder.
#
# Returns the game's process, $null when it did not start.
function Start-Game {
    try {
        $start = New-Object System.Diagnostics.ProcessStartInfo $GameExe
        $start.WorkingDirectory = $GameFolder
        $start.UseShellExecute = $true
        return [Diagnostics.Process]::Start($start)
    }
    catch {
        Write-Log "starting the game failed: $($_.Exception.Message)"
        return $null
    }
}

try {
    Write-Log "watching game $GameProcess in $Mode mode, watchdog $Watch"

    if (-not [IO.File]::Exists($GameExe)) {
        Write-Log "Game.exe is not in $GameFolder, nothing to watch"
        exit 1
    }

    $game = Get-StartingGame
    if ($game) {
        $game.WaitForExit()
        Write-Log 'the game closed'
    }
    else {
        Write-Log 'the game had closed already'
    }

    if ($Mode -eq 'rejoin') {
        $parked = Read-JournalWhilePolling
        if ($parked -is [bool]) {
            Write-Log 'the game is not started again, since the journal could not be read'
        }
        elseif ($parked -and $parked.Watch -ne $Watch) {
            Write-Log 'the journal belongs to a later watchdog, which starts the game'
        }
        elseif (Test-UpdateAsked $parked) {
            Write-Log 'an update was asked for, whose updater starts the game'
        }
        elseif (Test-GameRunning) {
            Write-Log 'a game of this folder runs already'
        }
        else {
            $started = Start-Game
            if ($started) {
                Write-Log 'started the game again into the world'
                $started.WaitForExit()
                Write-Log 'the game started into the world closed'
            }
            else {
                Write-Log 'the game did not start again'
            }
        }
    }

    $startTitle = $false
    while ($true) {
        $parked = Read-JournalWhilePolling
        if ($parked -is [bool]) {
            Wait-UnreadableJournal
            continue
        }

        if (-not $parked) {
            Write-Log 'no mods are parked any more'
            break
        }

        if ($parked.Watch -ne $Watch) {
            Write-Log 'the journal belongs to a later watchdog now'
            break
        }

        if (Test-GameRunning) {
            Start-Sleep -Milliseconds $PollMilliseconds
            continue
        }

        $lock = Open-Lock
        if (-not $lock) {
            Start-Sleep -Milliseconds $PollMilliseconds
            continue
        }

        try {
            # Read again under the lock, which no game can have changed it behind.
            $parked = Read-JournalWhilePolling
            if ($parked -isnot [bool] -and $parked -and $parked.Watch -eq $Watch) {
                Write-Log "bringing back $($parked.Files.Count) mod(s) parked for world $($parked.World)"
                if ((Restore-ParkedMods $parked) -and $parked.After -eq 'title' -and -not (Test-UpdateAsked $parked)) {
                    $startTitle = $true
                }
            }
        }
        finally {
            $lock.Dispose()
        }

        if ($parked -is [bool]) {
            Wait-UnreadableJournal
            continue
        }

        break
    }

    if ($startTitle -and -not (Test-GameRunning)) {
        if (Start-Game) {
            Write-Log 'started the game again to the title'
        }
        else {
            Write-Log 'the game did not start again'
        }
    }
}
catch {
    Write-Log "the watchdog failed: $($_.Exception.Message)"
    exit 1
}
