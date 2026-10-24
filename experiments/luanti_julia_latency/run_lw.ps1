param(
 [string]$Luanti='C:\Users\ken_m\AppData\Local\luanti\5.17.0\bin\luanti.exe',
 [string]$Julia='C:\Users\ken_m\Documents\Codex\tools\julia-1.13.1\bin\julia.exe'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output=Join-Path $repo ('outputs/luanti-lw-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path "$output/user/games","$output/world" -Force | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/game" -Destination "$output/user/games/julia_probe" -Recurse
Copy-Item -LiteralPath "$PSScriptRoot/lw_probe.lua" -Destination "$output/user/games/julia_probe/mods/latency_probe/init.lua"
$oldUser=$env:MINETEST_USER_PATH;$oldDepot=$env:JULIA_DEPOT_PATH
$env:MINETEST_USER_PATH="$output/user"
$env:JULIA_DEPOT_PATH='C:\Users\ken_m\Documents\Codex\tools\julia-depot'
$server=$null;$engine=$null
Write-Output "OUTPUT=$output"
try {
 $server=Start-Process -FilePath $Julia -ArgumentList @('--startup-file=no','--project=.','experiments/luanti_julia_latency/lw_server.jl',"`"$output`"") -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardOutput "$output/server.log" -RedirectStandardError "$output/server.err"
 $deadline=(Get-Date).AddMinutes(8)
 while (-not ((Get-Content "$output/server.log" -Raw -ErrorAction SilentlyContinue) -match 'READY')) {
  if ($server.HasExited -or (Get-Date) -gt $deadline) { throw "Julia startup/baseline failed: $output/server.err" }
  Start-Sleep -Milliseconds 500
 }
 Write-Output 'Standalone baseline complete; starting Luanti-paced run.'
 @"
gameid = julia_probe
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
"@ | Set-Content "$output/world/world.mt"
 @"
secure.http_mods = latency_probe
server_announce = false
bind_address = 127.0.0.1
port = 30987
dedicated_server_step = 0.01
mg_name = singlenode
"@ | Set-Content "$output/world/probe.conf"
 $engine=Start-Process -FilePath $Luanti -ArgumentList @('--server','--world',"`"$output/world`"",'--gameid','julia_probe','--config',"`"$output/world/probe.conf`"",'--logfile',"`"$output/world/engine.log`"") -WindowStyle Hidden -PassThru -RedirectStandardOutput "$output/world/stdout.log" -RedirectStandardError "$output/world/stderr.log"
 if (-not $engine.WaitForExit(600000)) { throw 'Luanti exceeded ten-minute limit' }
 $data=Get-Content "$output/world/latency.json" -Raw | ConvertFrom-Json
 if (-not $data.ok) { throw 'Luanti response audit failed' }
 $parity=Get-Content "$output/parity.json" -Raw | ConvertFrom-Json
 if (-not $parity.full_result_equal -or $data.rows.Count -ne $parity.ticks) { throw 'Final LW parity failed' }
 $stats=[ordered]@{ticks=$parity.ticks;operations=3*$parity.ticks;full_result_equal=$true;elapsed_ms=$data.elapsed_ms}
 foreach ($entry in @(@('rtt_ms',@($data.rows.rtt_ms)),@('live_compute_ms',@($parity.live_ms)),@('baseline_compute_ms',@($parity.baseline_ms)))) {
   $values=@($entry[1] | Sort-Object)
   $stats[$entry[0]]=[ordered]@{p50=$values[[int][math]::Floor(($values.Count-1)*.5)];p95=$values[[int][math]::Floor(($values.Count-1)*.95)];max=$values[-1];sum=($values | Measure-Object -Sum).Sum}
 }
 $stats | ConvertTo-Json -Depth 5 | Set-Content "$output/summary.json"
 $stats | ConvertTo-Json -Depth 5 | Write-Output
} finally {
 if ($engine -and -not $engine.HasExited) { Stop-Process -Id $engine.Id }
 if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id }
 $env:MINETEST_USER_PATH=$oldUser;$env:JULIA_DEPOT_PATH=$oldDepot
}
