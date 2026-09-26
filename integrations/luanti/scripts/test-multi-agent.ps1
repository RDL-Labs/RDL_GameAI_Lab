param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 25
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_multi_agent"
$runId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$runtimeOut = Join-Path $outputPath "runtime-multi-$runId.stdout.log"
$runtimeErr = Join-Path $outputPath "runtime-multi-$runId.stderr.log"
$luantiOut = Join-Path $outputPath "luanti-multi-$runId.stdout.log"
$luantiErr = Join-Path $outputPath "luanti-multi-$runId.stderr.log"
$luantiLog = Join-Path $outputPath "luanti-multi-$runId.log"

New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
if (-not (Test-Path -LiteralPath (Join-Path $worldPath "world.mt"))) {
    Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") `
        -Destination (Join-Path $worldPath "world.mt")
}

$runtime = $null
$luanti = $null
try {
    $runtime = Start-Process -FilePath "python" -ArgumentList "-m", "runtime.bridge" `
        -WorkingDirectory $repoRoot -RedirectStandardOutput $runtimeOut `
        -RedirectStandardError $runtimeErr -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 100
        try { $health = Invoke-RestMethod -Uri "http://127.0.0.1:8765/health" -TimeoutSec 1 }
        catch { $health = $null }
    } while (-not $health.ok -and [DateTime]::UtcNow -lt $deadline)
    if (-not $health.ok) { throw "Runtime bridge did not become healthy" }

    $luantiArgs = @(
        "--server", "--gameid", "rdl_game", "--world", $worldPath,
        "--config", (Join-Path $integrationRoot "config\luanti-multi-agent.conf"),
        "--logfile", $luantiLog, "--color", "never"
    )
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") `
        -ArgumentList $luantiArgs -WorkingDirectory $LuantiRoot `
        -RedirectStandardOutput $luantiOut -RedirectStandardError $luantiErr `
        -WindowStyle Hidden -PassThru

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $complete = $null
    do {
        Start-Sleep -Milliseconds 250
        if (Test-Path -LiteralPath $luantiLog) {
            $complete = Select-String -LiteralPath $luantiLog `
                -Pattern "RDL_LUANTI_MULTI_EVIDENCE.*complete agents=2" | Select-Object -Last 1
        }
    } while (-not $complete -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $complete) { throw "Multi-agent Luanti evidence was not produced" }

    $lines = Get-Content -LiteralPath $luantiLog
    foreach ($expected in @("pickup agent=npc_a target=food_a", "pickup agent=npc_b target=food_b")) {
        if (-not ($lines -match [regex]::Escape($expected))) { throw "Missing evidence: $expected" }
    }
    $snapshot = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/canonical-snapshot" -TimeoutSec 3
    if (-not $snapshot.latest_sections.npc_a -or -not $snapshot.latest_sections.npc_b) {
        throw "Canonical snapshot did not retain both agent sections"
    }
    Write-Output "MULTI PASS: agents=2 independent_pickups=true canonical_agents=2"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
