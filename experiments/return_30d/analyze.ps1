param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
$days=@(Get-Content (Join-Path $OutputPath 'daily_return.json') -Raw | ConvertFrom-Json)
$episodes=@(Get-Content (Join-Path $OutputPath 'return_episodes.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
$report=foreach ($a in @('npc_a','npc_b','npc_c')) {
 $rows=@($days | Where-Object actor -eq $a)
 $es=@($episodes | Where-Object actor -eq $a)
 $last=$rows[-1]
 $durations=@($es | ForEach-Object { $_.ticks / 17280.0 })
 $completed=@($es | Where-Object completed -eq $true).Count
 if ($completed -ne $last.purpose.completed) { throw "Episode count mismatch: $a" }
 [ordered]@{
   actor=$a;final_distance=$last.distance;final_reserve=$last.reserve
   final_return_active=$last.purpose.active;final_active_age_days=$last.active_age_days
   final_home_H=$last.home_H;completed_return_count=$last.purpose.completed
   recorded_completed_episodes=$completed
   max_observed_return_days=($durations | Measure-Object -Maximum).Maximum
   zero_reserve_day_ends=@($rows | Where-Object reserve -le 0 | ForEach-Object day)
   all_rest_days=@($rows | Where-Object { $_.actions.rest -eq 17280 } | ForEach-Object day)
   prolonged_episodes=@($es | Where-Object ticks -ge 17280)
 }
}
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $OutputPath 'return_audit.json')
$days | Select-Object day,actor,distance,reserve,active_age_days,home_H,
 @{Name='return_active';Expression={$_.purpose.active}},
 @{Name='completed';Expression={$_.purpose.completed}},
 @{Name='walk';Expression={$_.actions.walk}},
 @{Name='run';Expression={$_.actions.run}},
 @{Name='rest';Expression={$_.actions.rest}},
 @{Name='eat';Expression={$_.actions.eat}},
 @{Name='pickup';Expression={$_.actions.pickup}} |
 Export-Csv (Join-Path $OutputPath 'daily_return.csv') -NoTypeInformation -Encoding utf8
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$old=Import-Csv (Join-Path $repo 'experiments/julia_migration/diagnostics/evidence/cloud_90d_20261015/daily_agents.csv')
$differences=@()
foreach ($row in $days) {
 $prior=$old | Where-Object { [int]$_.day -eq $row.day -and $_.agent -eq $row.actor }
 foreach ($field in @('reserve','home_H')) {
  if ([double]$prior.$field -ne [double]$row.$field) { $differences+="$($row.day):$($row.actor):$field" }
 }
 if ([double]$prior.x -ne $row.position[0] -or [double]$prior.z -ne $row.position[1]) { $differences+="$($row.day):$($row.actor):position" }
 foreach ($field in @('walk','run','rest','scan','pickup','deposit','eat','give','request','retrieve')) {
  if ([int]$prior.$field -ne [int]$row.actions.$field) { $differences+="$($row.day):$($row.actor):$field" }
 }
}
[ordered]@{agent_days=$days.Count;fields='position,reserve,home_H,10 action counts';differences=$differences;exact_match=($differences.Count -eq 0)} |
 ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutputPath 'historical_comparison.json')
$report | ConvertTo-Json -Depth 12
