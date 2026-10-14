#----------------------------------------------------------------
#  game_battles.ps1
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# Plays comparison battles in a running test game through its test driver, one after another,
# each named save:troop:seed:name, and waits up to 300 s for each battle's log.
#   game_battles.ps1 -GameDir <test install> -Specs "Save09:101:3:Save09_101", ...
param([Parameter(Mandatory)][string]$GameDir, [string[]]$Specs)
$dir = Join-Path $GameDir "TestDriver"
$index = 10
foreach ($spec in $Specs) {
  $save, $troop, $seed, $name = $spec.Split(":")
  $index++
  $log = "$dir\out\battle_$name.txt"
  if (Test-Path $log) { Remove-Item -LiteralPath $log }
  Set-Content -Path "$dir\in\${index}_$name.rb" -Value "CompareBattle.start(`"TestDriver/saves/$save.rvdata2`", $troop, $seed, `"$name`")" -Encoding ASCII
  $started = Get-Date
  while (-not (Test-Path $log) -and ((Get-Date) - $started).TotalSeconds -lt 300) { Start-Sleep -Seconds 1 }
  $answer = Get-Content "$dir\out\${index}_$name.txt" -Raw -ErrorAction SilentlyContinue
  if (Test-Path $log) { "{0}: done in {1:N0} s ({2})" -f $name, ((Get-Date) - $started).TotalSeconds, ((Get-Content $log -TotalCount 2) -join ", ") }
  else { "${name}: no log after 300 s; the driver said $answer" }
  Start-Sleep -Seconds 2
}
