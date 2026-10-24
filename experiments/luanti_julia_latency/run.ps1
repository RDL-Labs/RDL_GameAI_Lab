param(
 [string]$Luanti = 'C:\Users\ken_m\AppData\Local\luanti\5.17.0\bin\luanti.exe',
 [string]$Julia = 'C:\Users\ken_m\Documents\Codex\tools\julia-1.13.1\bin\julia.exe'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output=Join-Path $repo ('outputs/luanti-julia-latency-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path "$output/user/games" -Force | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/game" -Destination "$output/user/games/julia_probe" -Recurse
$oldUser=$env:MINETEST_USER_PATH
$oldDepot=$env:JULIA_DEPOT_PATH
$env:MINETEST_USER_PATH="$output/user"
$env:JULIA_DEPOT_PATH='C:\Users\ken_m\Documents\Codex\tools\julia-depot'
$server=$null
$engine=$null
try {
 $server=Start-Process -FilePath $Julia -ArgumentList @('--startup-file=no','--project=.', 'experiments/luanti_julia_latency/server.jl') -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardOutput "$output/server.log" -RedirectStandardError "$output/server.err"
 $deadline=(Get-Date).AddSeconds(60)
 while (-not ((Get-Content "$output/server.log" -Raw -ErrorAction SilentlyContinue) -match 'READY')) {
   if ($server.HasExited -or (Get-Date) -gt $deadline) { throw "Julia did not become ready: $output/server.err" }
   Start-Sleep -Milliseconds 250
 }
 foreach ($n in @(3,6)) {
   $world="$output/world-$n"
   New-Item -ItemType Directory -Path $world | Out-Null
   @"
gameid = julia_probe
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
"@ | Set-Content "$world/world.mt"
   @"
secure.http_mods = latency_probe
probe_agents = $n
server_announce = false
server_address = 127.0.0.1
bind_address = 127.0.0.1
port = 30987
dedicated_server_step = 0.01
mg_name = singlenode
"@ | Set-Content "$world/probe.conf"
   $engine=Start-Process -FilePath $Luanti -ArgumentList @('--server','--world',"`"$world`"",'--gameid','julia_probe','--config',"`"$world/probe.conf`"",'--logfile',"`"$world/engine.log`"") -WindowStyle Hidden -PassThru -RedirectStandardOutput "$world/stdout.log" -RedirectStandardError "$world/stderr.log"
   if (-not $engine.WaitForExit(45000)) { throw 'Luanti timeout' }
   if ($engine.ExitCode -ne 0 -or -not (Test-Path "$world/latency.json")) { throw "Luanti failed: $world/stderr.log" }
   $data=Get-Content "$world/latency.json" -Raw | ConvertFrom-Json
   if ($data.errors -ne 0 -or $data.pending -ne 0 -or $data.sent -ne $data.received) { throw 'Response audit failed' }
   $rows=@($data.rows | Where-Object seq -gt 4)
   $rtt=@($rows.rtt_ms | Sort-Object)
   $cpu=@($rows.processing_us | Sort-Object)
   $summary=[ordered]@{agents=$n;samples=$rows.Count;sent=$data.sent;errors=$data.errors;skipped=$data.skipped;peak_pending=$data.peak_pending;rtt_p50_ms=$rtt[[int][math]::Floor(($rtt.Count-1)*.5)];rtt_p95_ms=$rtt[[int][math]::Floor(($rtt.Count-1)*.95)];rtt_max_ms=$rtt[-1];processing_p50_us=$cpu[[int][math]::Floor(($cpu.Count-1)*.5)];processing_p95_us=$cpu[[int][math]::Floor(($cpu.Count-1)*.95)];processing_max_us=$cpu[-1]}
   $summary | ConvertTo-Json | Set-Content "$world/summary.json"
   $summary | ConvertTo-Json -Compress | Write-Output
 }
 Write-Output "OUTPUT=$output"
} finally {
 if ($engine -and -not $engine.HasExited) { Stop-Process -Id $engine.Id }
 if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id }
 $env:MINETEST_USER_PATH=$oldUser
 $env:JULIA_DEPOT_PATH=$oldDepot
}
