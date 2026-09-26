param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_visual_probe"
$runId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$runtimeOut = Join-Path $outputPath "runtime-obs8-$runId.stdout.log"
$runtimeErr = Join-Path $outputPath "runtime-obs8-$runId.stderr.log"
$luantiOut = Join-Path $outputPath "luanti-obs8-$runId.stdout.log"
$luantiErr = Join-Path $outputPath "luanti-obs8-$runId.stderr.log"
$luantiLog = Join-Path $outputPath "luanti-obs8-$runId.log"

New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
if (-not (Test-Path -LiteralPath (Join-Path $worldPath "world.mt"))) {
    Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") `
        -Destination (Join-Path $worldPath "world.mt")
}

$probeConfig = Join-Path $outputPath "obs8-$runId.conf"
@"
server_announce = false
creative_mode = true
secure.http_mods = rdl_bridge
rdl_runtime_url = http://127.0.0.1:8765/v1/observe
rdl_fixture_mode = visual_probe
rdl_sensor_profile_npc_a = fixture-distant-enabled
rdl_probe_run_id = obs8-$runId
port = 30001
max_users = 1
default_game = rdl_game
mg_name = singlenode
"@ | Set-Content -Encoding utf8 $probeConfig
$runtime = $null
$luanti = $null
try {
    $runtime = Start-Process -FilePath "python" -ArgumentList `
        "-m", "runtime.bridge", "--sensory-observation", `
        "--sensory-profile", "npc_a=fixture-distant-enabled", `
        "--sensory-run-id", "obs8-$runId" `
        -WorkingDirectory $repoRoot -RedirectStandardOutput $runtimeOut `
        -RedirectStandardError $runtimeErr -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 100
        try { $health = Invoke-RestMethod -Uri "http://127.0.0.1:8765/health" -TimeoutSec 1 }
        catch { $health = $null }
    } while (-not $health.ok -and [DateTime]::UtcNow -lt $deadline)
    if (-not $health.ok) { throw "Runtime bridge did not become healthy" }

    $args = @(
        "--server", "--gameid", "rdl_game", "--world", $worldPath,
        "--config", $probeConfig,
        "--logfile", $luantiLog, "--color", "never"
    )
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") `
        -ArgumentList $args -WorkingDirectory $LuantiRoot `
        -RedirectStandardOutput $luantiOut -RedirectStandardError $luantiErr `
        -WindowStyle Hidden -PassThru

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $delivered = $null
    do {
        Start-Sleep -Milliseconds 200
        if (Test-Path -LiteralPath $luantiLog) {
            $delivered = Select-String -LiteralPath $luantiLog `
                -Pattern "RDL_LUANTI_OBS8.*complete cases=15" | Select-Object -Last 1
        }
    } while (-not $delivered -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $delivered) { throw "Visual probe evidence was not produced" }

    $snapshot = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/sensory-observation-snapshot" -TimeoutSec 3
    $snapshotPath = Join-Path $outputPath "obs8-$runId.snapshot.json"
    $snapshot | ConvertTo-Json -Depth 30 | Set-Content -Encoding utf8 $snapshotPath
    $evidencePath = Join-Path $outputPath "obs8-$runId.evidence.json"
    Copy-Item -LiteralPath (Join-Path $worldPath "obs8-evidence.json") -Destination $evidencePath
    Push-Location $repoRoot
    try {
        & python -m integrations.luanti.tests.check_visual_probe $snapshotPath $evidencePath
        if ($LASTEXITCODE -ne 0) { throw "OBS-8 replay checks failed" }
    } finally { Pop-Location }
    Write-Output "OBS8 SNAPSHOT: $snapshotPath"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
