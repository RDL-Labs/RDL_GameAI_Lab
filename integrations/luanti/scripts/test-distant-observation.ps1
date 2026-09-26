param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 25
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_distant_observation"
$runId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$runtimeOut = Join-Path $outputPath "runtime-distant-$runId.stdout.log"
$runtimeErr = Join-Path $outputPath "runtime-distant-$runId.stderr.log"
$luantiOut = Join-Path $outputPath "luanti-distant-$runId.stdout.log"
$luantiErr = Join-Path $outputPath "luanti-distant-$runId.stderr.log"
$luantiLog = Join-Path $outputPath "luanti-distant-$runId.log"

New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
if (-not (Test-Path -LiteralPath (Join-Path $worldPath "world.mt"))) {
    Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") `
        -Destination (Join-Path $worldPath "world.mt")
}

$runtime = $null
$luanti = $null
try {
    $runtime = Start-Process -FilePath "python" -ArgumentList `
        "-m", "runtime.bridge", "--sensory-observation", `
        "--sensory-profile", "npc_a=fixture-distant-enabled" `
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
        "--config", (Join-Path $integrationRoot "config\luanti-distant-observation.conf"),
        "--logfile", $luantiLog, "--color", "never"
    )
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") `
        -ArgumentList $args -WorkingDirectory $LuantiRoot `
        -RedirectStandardOutput $luantiOut -RedirectStandardError $luantiErr `
        -WindowStyle Hidden -PassThru

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $second = $null
    do {
        Start-Sleep -Milliseconds 200
        if (Test-Path -LiteralPath $luantiLog) {
            $second = Select-String -LiteralPath $luantiLog `
                -Pattern "RDL_LUANTI_OBS3.*sample seq=2" | Select-Object -Last 1
        }
    } while (-not $second -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $second) { throw "Distant observation evidence was not produced" }

    $snapshot = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/sensory-observation-snapshot" -TimeoutSec 3
    $frames = @($snapshot.frames | Where-Object { $_.channel -eq "vision_distant" })
    if ($frames.Count -ne 2) { throw "Expected exactly two distant frames, got $($frames.Count)" }
    $firstFeatures = @($frames[0].payload.features)
    $secondFeatures = @($frames[1].payload.features)
    if ($firstFeatures.Count -ne 1 -or $firstFeatures[0].color_band -ne "muted_red") {
        throw "First frame must expose only the unoccluded muted-red feature"
    }
    if ($secondFeatures.Count -ne 0) { throw "Turned-away second frame must be empty" }
    $serialized = $frames | ConvertTo-Json -Depth 12
    foreach ($forbidden in @("world_position", "target_id", "distance", "distant_dark", "distant_red")) {
        if ($serialized -match [regex]::Escape($forbidden)) { throw "Forbidden distant detail leaked: $forbidden" }
    }
    if ($snapshot.rejection_count -ne 0) { throw "Runtime rejected a valid distant frame" }
    Write-Output "OBS3 PASS: frames=2 visible_first=1 visible_after_turn=0 occluded_hidden=true"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
