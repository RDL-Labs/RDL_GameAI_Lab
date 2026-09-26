param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 25,
    [string]$ConfigPath = "",
    [int]$ExpectedAVisible = 2,
    [int]$ExpectedBVisible = 1,
    [string]$ResultLabel = "MULTI LIFE PASS",
    [switch]$SensoryObservation
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
if (-not $ConfigPath) { $ConfigPath = Join-Path $integrationRoot "config\luanti-multi-agent.conf" }

New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
if (-not (Test-Path -LiteralPath (Join-Path $worldPath "world.mt"))) {
    Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") `
        -Destination (Join-Path $worldPath "world.mt")
}

$runtime = $null
$luanti = $null
try {
    $runtimeArgs = @("-m", "runtime.bridge", "--base-food-life")
    if ($SensoryObservation) {
        $runtimeArgs += @(
            "--sensory-observation",
            "--sensory-profile", "npc_a=fixture-life-sensory",
            "--sensory-profile", "npc_b=fixture-life-sensory-compact"
        )
    }
    $runtime = Start-Process -FilePath "python" -ArgumentList $runtimeArgs `
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
        "--config", $ConfigPath,
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
                -Pattern "RDL_LUANTI_MULTI_LIFE_EVIDENCE.*complete agents=2 results=2" | Select-Object -Last 1
        }
    } while (-not $complete -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $complete) { throw "Multi-agent Luanti life evidence was not produced" }

    $lines = Get-Content -LiteralPath $luantiLog
    foreach ($expected in @("pickup agent=npc_a target=food_a", "pickup agent=npc_b target=food_b")) {
        if (-not ($lines -match [regex]::Escape($expected))) { throw "Missing evidence: $expected" }
    }
    foreach ($expected in @("deposit agent=npc_a base=base_a accepted=true", "deposit agent=npc_b base=base_b accepted=true")) {
        if (-not ($lines -match [regex]::Escape($expected))) { throw "Missing evidence: $expected" }
    }
    $life = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/life-snapshot" -TimeoutSec 3
    $results = @($life.results)
    if ($results.Count -ne 2) { throw "Expected exactly two life results, got $($results.Count)" }
    $resultAgents = @($results | ForEach-Object { $_.agent_id } | Sort-Object -Unique)
    if (($resultAgents -join ",") -ne "npc_a,npc_b") {
        throw "Life results were not separated by agent: $($resultAgents -join ',')"
    }
    foreach ($field in @("result_id", "source_observation_id", "cue_id")) {
        $unique = @($results | ForEach-Object { $_.$field } | Sort-Object -Unique)
        if ($unique.Count -ne 2) { throw "Life result $field values must be distinct per agent" }
    }
    $snapshot = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/canonical-snapshot" -TimeoutSec 3
    if (-not $snapshot.latest_sections.npc_a -or -not $snapshot.latest_sections.npc_b) {
        throw "Canonical snapshot did not retain both agent sections"
    }
    $aVisible = [int]$snapshot.latest_sections.npc_a.values.visible_agents_count
    $bVisible = [int]$snapshot.latest_sections.npc_b.values.visible_agents_count
    if ($aVisible -ne $ExpectedAVisible) {
        throw "npc_a visible-agent count mismatch: expected $ExpectedAVisible, got $aVisible"
    }
    if ($bVisible -ne $ExpectedBVisible) {
        throw "npc_b visible-agent count mismatch: expected $ExpectedBVisible, got $bVisible"
    }
    if ($SensoryObservation) {
        $sensory = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/sensory-observation-snapshot" -TimeoutSec 3
        if ($sensory.rejection_count -ne 1) {
            $details = @($sensory.rejections | ForEach-Object { $_.detail }) -join "; "
            throw "Expected one recoverable OBS-6D sensory rejection, got $($sensory.rejection_count): $details"
        }
        if ($sensory.rejections[0].detail -notmatch "delivery tick") {
            throw "OBS-6D rejection probe did not exercise delivery-tick isolation"
        }
        foreach ($agentId in @("npc_a", "npc_b")) {
            $agentFrames = @($sensory.frames | Where-Object { $_.agent_id -eq $agentId })
            $channels = @($agentFrames | ForEach-Object { $_.channel } | Sort-Object -Unique)
            if (($channels -join ",") -ne "audition,vision_distant,vision_local") {
                throw "Missing integrated channels for ${agentId}: $($channels -join ',')"
            }
            foreach ($frame in $agentFrames) {
                if ($frame.agent_id -ne $agentId) { throw "Cross-agent sensory frame leakage" }
                if ($frame.capture_window.end_us -gt $frame.sampled_world_tick * 250000) {
                    throw "Sensory capture time advanced beyond its World tick"
                }
            }
            $distantFeatures = @($agentFrames | Where-Object { $_.channel -eq "vision_distant" } |
                ForEach-Object { @($_.payload.features) })
            $auditionDetections = @($agentFrames | Where-Object { $_.channel -eq "audition" } |
                ForEach-Object { @($_.payload.detections) })
            if ($distantFeatures.Count -lt 1) { throw "No distant feature was sampled for $agentId" }
            if ($auditionDetections.Count -lt 1) { throw "No action sound was received for $agentId" }
        }
        $bFrames = @($sensory.frames | Where-Object { $_.agent_id -eq "npc_b" })
        $delayedWindow = @($bFrames | Where-Object {
            $_.channel -eq "audition" -and $_.sampled_world_tick -eq 1 -and
            $_.capture_window.start_us -eq 0 -and $_.capture_window.end_us -eq 250000
        })
        $bLocalAtOne = @($bFrames | Where-Object {
            $_.channel -eq "vision_local" -and $_.sampled_world_tick -eq 1
        })
        if ($delayedWindow.Count -ne 1 -or $bLocalAtOne.Count -ne 0) {
            throw "Skipped sensory delivery did not preserve the original audition window"
        }
        if (-not ($lines -match "RDL_LUANTI_OBS6C.*world_probe=PASS")) {
            throw "OBS-6C World-change probe did not pass"
        }
        $deliveryLines = @($lines | Where-Object { $_ -match "RDL_LUANTI_OBS6D.*delivery" })
        if ($deliveryLines.Count -lt 1) { throw "No OBS-6D delivery batches were logged" }
        foreach ($line in $deliveryLines) {
            if ($line -match "frames=(\d+)" -and [int]$Matches[1] -gt 4) {
                throw "OBS-6D exceeded the four-frame delivery limit: $line"
            }
        }
        if (-not ($deliveryLines -match "agent=npc_b frames=4 pending=[5-9]")) {
            throw "Four-tick delayed sensory backlog was not split into a bounded batch"
        }
        if (-not ($lines -match "RDL_LUANTI_OBS6D.*ack agent=npc_b")) {
            throw "OBS-6D did not receive an explicit sensory acknowledgement for npc_b"
        }
        if (-not ($lines -match "RDL_LUANTI_OBS6D.*receipt rejected; retained agent=npc_a") -or
                -not ($lines -match "RDL_LUANTI_OBS6D.*simulated transport failure; retained agent=npc_a")) {
            throw "OBS-6D rejection or transport-failure retention probe did not run"
        }
        $latestA = $sensory.latest_by_agent.npc_a
        $latestB = $sensory.latest_by_agent.npc_b
        if (-not $latestA.vision_local -or -not $latestA.vision_distant -or -not $latestA.audition -or `
                -not $latestB.vision_local -or -not $latestB.vision_distant -or -not $latestB.audition) {
            throw "Latest sensory channels were not independently retained for both agents"
        }
        foreach ($agentId in @("npc_a", "npc_b")) {
            $agentFrames = @($sensory.frames | Where-Object { $_.agent_id -eq $agentId })
            $localTimes = @($agentFrames | Where-Object { $_.channel -eq "vision_local" } |
                ForEach-Object { $_.capture_window.end_us })
            $distantTimes = @($agentFrames | Where-Object { $_.channel -eq "vision_distant" } |
                ForEach-Object { $_.capture_window.end_us })
            $localOnly = @($localTimes | Where-Object { $_ -notin $distantTimes })
            if ($localOnly.Count -lt 1) {
                throw "Local and periodic distant sample schedules were not independently retained"
            }
        }
        Write-Output "OBS6 SENSORY: agents=2 channels=3 rejection_recovered=1 transport_retry=1 life_compatible=true"
    }
    Write-Output "${ResultLabel}: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:$aVisible,B:$bVisible"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
