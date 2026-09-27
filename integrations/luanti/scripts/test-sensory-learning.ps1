param(
    [string]$LuantiRoot = "D:\luanti",
    [bool]$Activate = $true,
    [bool]$Reverse = $false,
    [ValidateSet("", "opposite", "a_only", "b_only")][string]$MultiScenario = "",
    [int]$TimeoutSeconds = 60
)
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$runId = "l10-" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$mode = "sensory_learning"
$evidenceFile = "l10-evidence.json"
$checker = "integrations.luanti.tests.check_sensory_learning"
if ($MultiScenario) {
    $runId = $runId.Replace("l10-", "l10b-$MultiScenario-")
    $mode = "sensory_learning_multi"
    $evidenceFile = "l10b-evidence.json"
    $checker = "integrations.luanti.tests.check_multi_sensory_learning"
}
$worldPath = Join-Path $integrationRoot "worlds\$runId"
New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") -Destination (Join-Path $worldPath "world.mt")
$config = Join-Path $outputPath "$runId.conf"
$log = Join-Path $outputPath "$runId.log"
@"
server_announce = false
creative_mode = true
secure.http_mods = rdl_bridge
rdl_runtime_url = http://127.0.0.1:8765/v1/observe
rdl_fixture_mode = $mode
rdl_sensor_profile_npc_a = fixture-life-sensory
rdl_sensor_profile_npc_b = fixture-life-sensory-compact
rdl_learning_multi_scenario = $MultiScenario
rdl_learning_run_id = $runId
rdl_learning_activate = $($Activate.ToString().ToLowerInvariant())
rdl_learning_reverse = $($Reverse.ToString().ToLowerInvariant())
port = 30001
max_users = 1
default_game = rdl_game
mg_name = singlenode
"@ | Set-Content -LiteralPath $config -Encoding utf8
$runtime = $null
$luanti = $null
try {
    $runtimeArgs = @("-m","runtime.bridge","--sensory-observation","--luanti-learning-loop",
        "--sensory-profile","npc_a=fixture-life-sensory","--sensory-run-id",$runId)
    if ($MultiScenario) { $runtimeArgs += @("--luanti-learning-multi-agent","--sensory-profile","npc_b=fixture-life-sensory-compact") }
    $runtime = Start-Process -FilePath "python" -ArgumentList $runtimeArgs `
        -WorkingDirectory $repoRoot -RedirectStandardOutput (Join-Path $outputPath "$runId.runtime.out.log") `
        -RedirectStandardError (Join-Path $outputPath "$runId.runtime.err.log") -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 100
        try { $health = Invoke-RestMethod "http://127.0.0.1:8765/health" -TimeoutSec 1 } catch { $health = $null }
    } while (-not $health.ok -and [DateTime]::UtcNow -lt $deadline)
    if (-not $health.ok -or $runtime.HasExited) { throw "L10 Runtime did not start" }
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") -ArgumentList `
        "--server","--gameid","rdl_game","--world",$worldPath,"--config",$config,"--logfile",$log,"--color","never" `
        -WorkingDirectory $LuantiRoot -RedirectStandardOutput (Join-Path $outputPath "$runId.world.out.log") `
        -RedirectStandardError (Join-Path $outputPath "$runId.world.err.log") -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Milliseconds 200
        $complete = Test-Path -LiteralPath (Join-Path $worldPath $evidenceFile)
    } while (-not $complete -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $complete) {
        Get-Content -LiteralPath (Join-Path $outputPath "$runId.world.err.log") -Tail 15
        throw "L10 did not complete; $log"
    }
    $world = Get-Content -LiteralPath (Join-Path $worldPath $evidenceFile) -Raw | ConvertFrom-Json
    $learning = Invoke-RestMethod "http://127.0.0.1:8765/v1/luanti-learning-snapshot"
    $sensory = Invoke-RestMethod "http://127.0.0.1:8765/v1/sensory-observation-snapshot"
    $canonical = Invoke-RestMethod "http://127.0.0.1:8765/v1/canonical-snapshot"
    $snapshot = Join-Path $outputPath "$runId.snapshot.json"
    @{world=$world; learning=$learning; sensory=$sensory; canonical=$canonical} | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $snapshot -Encoding utf8
    Push-Location $repoRoot
    try {
        & python -m $checker $snapshot
        if ($LASTEXITCODE -ne 0) { throw "L10 checks failed" }
    } finally { Pop-Location }
    Write-Output "L10 SNAPSHOT: $snapshot"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
