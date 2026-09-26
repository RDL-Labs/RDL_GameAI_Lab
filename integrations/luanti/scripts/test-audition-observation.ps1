param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_audition_observation"
$runId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$runtimeOut = Join-Path $outputPath "runtime-audition-$runId.stdout.log"
$runtimeErr = Join-Path $outputPath "runtime-audition-$runId.stderr.log"
$luantiOut = Join-Path $outputPath "luanti-audition-$runId.stdout.log"
$luantiErr = Join-Path $outputPath "luanti-audition-$runId.stderr.log"
$luantiLog = Join-Path $outputPath "luanti-audition-$runId.log"

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
        "--sensory-profile", "npc_a=fixture-audition-enabled", `
        "--sensory-profile", "npc_b=fixture-audition-compact" `
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
        "--config", (Join-Path $integrationRoot "config\luanti-audition-observation.conf"),
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
                -Pattern "RDL_LUANTI_OBS4.*agent=npc_b" | Select-Object -Last 1
        }
    } while (-not $delivered -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $delivered) { throw "Audition observation evidence was not produced" }

    $snapshot = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/sensory-observation-snapshot" -TimeoutSec 3
    $frames = @($snapshot.frames | Where-Object { $_.channel -eq "audition" })
    if ($frames.Count -ne 4) { throw "Expected four audition frames, got $($frames.Count)" }
    $a = $frames | Where-Object { $_.agent_id -eq "npc_a" -and $_.sample_seq -eq 1 }
    $b = $frames | Where-Object { $_.agent_id -eq "npc_b" -and $_.sample_seq -eq 1 }
    $aDetections = @($a.payload.detections)
    $bDetections = @($b.payload.detections)
    if ($aDetections.Count -ne 1) { throw "Normal-gain A must receive one mixed detection" }
    if ($aDetections[0].received_strength_band -ne "weak" -or `
            $aDetections[0].dominant_band -ne "mid") {
        throw "A must receive the wall-attenuated weak/mid detection"
    }
    if ($aDetections[0].observer_frame_ref -ne "npc_a:ear-pose:before-turn" -or `
            $aDetections[0].received_interval_us[0] -ne 100000 -or `
            $aDetections[0].received_interval_us[1] -ne 120000) {
        throw "First window must preserve emit-time pose and receive interval"
    }
    if ($bDetections.Count -ne 0) { throw "Compact-gain B must remain below threshold" }
    if ($a.coverage -ne "COMPLETE_WITHIN_PLAN" -or $b.coverage -ne "COMPLETE_WITHIN_PLAN") {
        throw "Audition fixture must complete its finite path checks"
    }
    $overflowFrames = @($frames | Where-Object { $_.sample_seq -eq 2 })
    if ($overflowFrames.Count -ne 2) { throw "Expected one overflow frame per agent" }
    foreach ($frame in $overflowFrames) {
        if ($frame.coverage -ne "PARTIAL" -or -not $frame.output_limited) {
            throw "Overflow must be recorded as partial/output-limited, not silence"
        }
    }
    $aOverflow = $overflowFrames | Where-Object { $_.agent_id -eq "npc_a" }
    $bOverflow = $overflowFrames | Where-Object { $_.agent_id -eq "npc_b" }
    if (@($aOverflow.payload.detections).Count -ne 1 -or `
            @($bOverflow.payload.detections).Count -ne 0) {
        throw "Accepted overflow-window receipts must still be processed per profile"
    }
    if ($aOverflow.payload.detections[0].received_interval_us[0] -ne 250000 -or `
            $aOverflow.payload.detections[0].observer_frame_ref -ne "npc_a:ear-pose:after-turn") {
        throw "Boundary event must occur once in the second window using emit-time pose"
    }
    $serialized = $frames | ConvertTo-Json -Depth 12
    foreach ($forbidden in @("source_id", "world_position", "distance", "footstep", "beast")) {
        if ($serialized -match [regex]::Escape($forbidden)) { throw "Forbidden sound detail leaked: $forbidden" }
    }
    if ($snapshot.rejection_count -ne 0) { throw "Runtime rejected a valid audition frame" }
    Write-Output "OBS4B PASS: frames=4 first_window_mixed=2 boundary_once=true pose_preserved=true delayed=true overflow_partial=true"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
