param(
    [string]$LuantiRoot = "D:\luanti",
    [ValidateSet("npc_a","npc_b")][string]$Defender = "npc_a",
    [ValidateSet(0,1)][int]$Inclusion = 0,
    [ValidateSet(3,9)][int]$Threshold = 3,
    [ValidateSet("single","dense","spaced")][string]$Schedule = "single",
    [ValidateSet("","presence","outside")][string]$Negative = "",
    [switch]$Loss,
    [switch]$Matrix
)
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
if ($Matrix) {
    $paths = @()
    foreach ($role in @("npc_a","npc_b")) { foreach ($inc in @(0,1)) { foreach ($th in @(3,9)) { foreach ($seq in @("single","dense","spaced")) {
        $inject = ($role -eq "npc_a" -and $inc -eq 0 -and $th -eq 3 -and $seq -eq "dense")
        $result = & $PSCommandPath -LuantiRoot $LuantiRoot -Defender $role -Inclusion $inc -Threshold $th -Schedule $seq -Loss:$inject
        $result | Write-Output
        $paths += ($result | Where-Object { $_ -like "L11 SNAPSHOT: *" }).Substring(14)
    } } } }
    foreach ($neg in @("presence","outside")) {
        $result = & $PSCommandPath -LuantiRoot $LuantiRoot -Negative $neg
        $result | Write-Output
        $paths += ($result | Where-Object { $_ -like "L11 SNAPSHOT: *" }).Substring(14)
    }
    $manifest = Join-Path $outputPath ("l11-matrix-" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss") + ".json")
    $paths | ConvertTo-Json | Set-Content -LiteralPath $manifest -Encoding utf8
    Write-Output "L11 MATRIX: $manifest"
    return
}
$runId = "l11-$Defender-$Inclusion-$Threshold-$Schedule-$Negative-" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$worldPath = Join-Path $integrationRoot "worlds\$runId"
New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") -Destination (Join-Path $worldPath "world.mt")
$config = Join-Path $outputPath "$runId.conf"
@"
server_announce = false
creative_mode = true
secure.http_mods = rdl_bridge
rdl_runtime_url = http://127.0.0.1:8765/v1/observe
rdl_fixture_mode = boundary_defense
rdl_sensor_profile_npc_a = fixture-life-sensory
rdl_sensor_profile_npc_b = fixture-life-sensory-compact
rdl_learning_run_id = $runId
rdl_boundary_defender = $Defender
rdl_boundary_inclusion = $Inclusion
rdl_boundary_threshold = $Threshold
rdl_boundary_schedule = $Schedule
rdl_boundary_negative = $Negative
rdl_boundary_loss = $($Loss.IsPresent.ToString().ToLowerInvariant())
port = 30001
max_users = 1
default_game = rdl_game
mg_name = singlenode
dedicated_server_step = 0.02
"@ | Set-Content -LiteralPath $config -Encoding utf8
$runtime = $null
$luanti = $null
try {
    $runtime = Start-Process -FilePath "python" -ArgumentList @("-m","runtime.bridge","--boundary-defense","--sensory-run-id",$runId) `
        -WorkingDirectory $repoRoot -RedirectStandardOutput (Join-Path $outputPath "$runId.runtime.out.log") `
        -RedirectStandardError (Join-Path $outputPath "$runId.runtime.err.log") -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 100
        try { $health = Invoke-RestMethod "http://127.0.0.1:8765/health" -TimeoutSec 1 } catch { $health = $null }
    } while (-not $health.ok -and [DateTime]::UtcNow -lt $deadline)
    if (-not $health.ok -or $runtime.HasExited) { throw "L11 Runtime did not start" }
    $initial = Invoke-RestMethod "http://127.0.0.1:8765/v1/boundary-defense-snapshot"
    if ($initial.schema -ne "l11-boundary-defense-v1" -or $initial.config) { throw "Unexpected Runtime instance" }
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") -ArgumentList `
        "--server","--gameid","rdl_game","--world",$worldPath,"--config",$config,"--logfile",(Join-Path $outputPath "$runId.log"),"--color","never" `
        -WorkingDirectory $LuantiRoot -RedirectStandardOutput (Join-Path $outputPath "$runId.world.out.log") `
        -RedirectStandardError (Join-Path $outputPath "$runId.world.err.log") -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(25)
    do {
        Start-Sleep -Milliseconds 100
        $complete = Test-Path -LiteralPath (Join-Path $worldPath "l11-evidence.json")
    } while (-not $complete -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $complete) {
        Get-Content -LiteralPath (Join-Path $outputPath "$runId.world.err.log") -Tail 15
        throw "L11 did not complete"
    }
    $world = Get-Content -LiteralPath (Join-Path $worldPath "l11-evidence.json") -Raw | ConvertFrom-Json
    $reaction = Invoke-RestMethod "http://127.0.0.1:8765/v1/boundary-defense-snapshot"
    $snapshot = Join-Path $outputPath "$runId.snapshot.json"
    @{world=$world; reaction=$reaction} | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $snapshot -Encoding utf8
    Push-Location $repoRoot
    try {
        & python -m integrations.luanti.tests.check_boundary_defense $snapshot
        if ($LASTEXITCODE -ne 0) { throw "L11 checks failed: $snapshot" }
    } finally { Pop-Location }
    Write-Output "L11 SNAPSHOT: $snapshot"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
