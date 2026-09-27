param(
    [string]$LuantiRoot = "D:\luanti",
    [ValidateSet("straight","right","left","rotated","no_strip","no_food","partial","blocked","faults")]
    [string]$Scenario = "straight",
    [switch]$Matrix
)
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
if ($Matrix) {
    $paths = @()
    foreach ($case in @("straight","right","left","rotated","no_strip","no_food","partial","blocked","faults")) {
        $result = & $PSCommandPath -LuantiRoot $LuantiRoot -Scenario $case
        $result | Write-Output
        $paths += ($result | Where-Object { $_ -like "L13A SNAPSHOT: *" }).Substring(15)
    }
    $manifest = Join-Path $outputPath ("l13a-matrix-" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss") + ".json")
    $paths | ConvertTo-Json | Set-Content -LiteralPath $manifest -Encoding utf8
    Write-Output "L13A MATRIX: $manifest"
    return
}
$runId = "l13a-" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
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
rdl_fixture_mode = finite_exploration
rdl_learning_run_id = $runId
rdl_exploration_scenario = $Scenario
time_speed = 0
port = 30001
max_users = 1
default_game = rdl_game
mg_name = singlenode
dedicated_server_step = 0.02
"@ | Set-Content -LiteralPath $config -Encoding utf8
$runtime = $null
$luanti = $null
try {
    $runtime = Start-Process -FilePath "python" -ArgumentList @("-m","runtime.bridge","--finite-exploration","--sensory-run-id",$runId) `
        -WorkingDirectory $repoRoot -RedirectStandardOutput (Join-Path $outputPath "$runId.runtime.out.log") `
        -RedirectStandardError (Join-Path $outputPath "$runId.runtime.err.log") -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 100
        try { $health = Invoke-RestMethod "http://127.0.0.1:8765/health" -TimeoutSec 1 } catch { $health = $null }
    } while (-not $health.ok -and [DateTime]::UtcNow -lt $deadline)
    if (-not $health.ok -or $runtime.HasExited) { throw "L13A Runtime did not start" }
    $initial = Invoke-RestMethod "http://127.0.0.1:8765/v1/exploration-snapshot"
    if ($initial.exploration.schema -ne "l13a-exploration-v1" -or $initial.exploration.config) { throw "Unexpected Runtime instance" }
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") -ArgumentList `
        "--server","--gameid","rdl_game","--world",$worldPath,"--config",$config,"--logfile",(Join-Path $outputPath "$runId.log"),"--color","never" `
        -WorkingDirectory $LuantiRoot -RedirectStandardOutput (Join-Path $outputPath "$runId.world.out.log") `
        -RedirectStandardError (Join-Path $outputPath "$runId.world.err.log") -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(50)
    do {
        Start-Sleep -Milliseconds 100
        $complete = Test-Path -LiteralPath (Join-Path $worldPath "l13a-evidence.json")
    } while (-not $complete -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $complete) {
        Get-Content -LiteralPath (Join-Path $outputPath "$runId.world.err.log") -Tail 15
        throw "L13A did not complete"
    }
    $world = Get-Content -LiteralPath (Join-Path $worldPath "l13a-evidence.json") -Raw | ConvertFrom-Json
    $state = Invoke-RestMethod "http://127.0.0.1:8765/v1/exploration-snapshot"
    $snapshot = Join-Path $outputPath "$runId.snapshot.json"
    @{world=$world; runtime=$state; initial=$initial} | ConvertTo-Json -Depth 90 | Set-Content -LiteralPath $snapshot -Encoding utf8
    Push-Location $repoRoot
    try {
        & python -m integrations.luanti.tests.check_exploration $snapshot
        if ($LASTEXITCODE -ne 0) { throw "L13A checks failed: $snapshot" }
    } finally { Pop-Location }
    Write-Output "L13A SNAPSHOT: $snapshot"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
