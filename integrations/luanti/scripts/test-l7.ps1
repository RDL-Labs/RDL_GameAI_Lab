param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 45
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_l7"
$runId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$runtimeOut = Join-Path $outputPath "runtime-l7-$runId.stdout.log"
$runtimeErr = Join-Path $outputPath "runtime-l7-$runId.stderr.log"
$luantiOut = Join-Path $outputPath "luanti-l7-$runId.stdout.log"
$luantiErr = Join-Path $outputPath "luanti-l7-$runId.stderr.log"
$luantiLog = Join-Path $outputPath "luanti-l7-$runId.log"

New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
if (-not (Test-Path -LiteralPath (Join-Path $worldPath "world.mt"))) {
    Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") -Destination (Join-Path $worldPath "world.mt")
}

$runtime = $null
$luanti = $null
try {
    $runtime = Start-Process -FilePath "python" `
        -ArgumentList "-m", "runtime.bridge", "--base-food-life", "--luanti-outcome-learning" `
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
        "--config", (Join-Path $integrationRoot "config\luanti-l6.conf"),
        "--logfile", $luantiLog, "--color", "never"
    )
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") `
        -ArgumentList $luantiArgs -WorkingDirectory $LuantiRoot `
        -RedirectStandardOutput $luantiOut -RedirectStandardError $luantiErr `
        -WindowStyle Hidden -PassThru

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $cycleEvidence = $null
    do {
        Start-Sleep -Milliseconds 250
        if (Test-Path -LiteralPath $luantiLog) {
            $cycleEvidence = Select-String -LiteralPath $luantiLog -Pattern "outcome_cycle=3" | Select-Object -Last 1
        }
    } while (-not $cycleEvidence -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $cycleEvidence) { throw "Three L7 outcome cycles were not produced" }

    $sleepBody = @{
        agent_id = "npc_a"; sleep_cycle = "luanti-night-l7"; formation_tick = 40
    } | ConvertTo-Json
    $sleep = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/v1/luanti-bias-sleep" `
        -ContentType "application/json" -Body $sleepBody -TimeoutSec 3
    if ($sleep.result.status -ne "CANDIDATE_FORMED") { throw "L7 requires a shadow candidate" }

    $canonical = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/canonical-snapshot" -TimeoutSec 3
    $pending = @($canonical.assessment.records | Where-Object {
        -not $_.reviewed -and [Math]::Abs([double]$_.E.deltas.visible_objects_count) -ge 1
    })
    if ($pending.Count -eq 0) { throw "No finite pending canonical comparison was available" }
    $assessment = $pending[-1]
    $dimensions = @{}
    foreach ($property in $assessment.E.deltas.PSObject.Properties) {
        $delta = [double]$property.Value
        if ($delta -eq 0) {
            $dimensions[$property.Name] = @{ status = "zero" }
        } elseif ($property.Name -eq "visible_objects_count") {
            $dimensions[$property.Name] = @{ status = "unresolved"; residual = 1.0 }
        } else {
            $dimensions[$property.Name] = @{ status = "ordinary_temporal_change"; residual = 0.0 }
        }
    }
    $reviewBody = @{
        assessment_id = $assessment.assessment_id
        expected_revision = [int]$assessment.revision
        reviewer = "luanti-l7-evidence"
        basis = "explicit independent finite rupture review"
        evidence = "real Luanti bounded observation comparison"
        dimensions = $dimensions
    } | ConvertTo-Json -Depth 8
    Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/v1/assessment-review" `
        -ContentType "application/json" -Body $reviewBody -TimeoutSec 3 | Out-Null

    $t1Body = @{
        assessment_id = $assessment.assessment_id
        reviewer = "luanti-l7-evidence"
        basis = "explicit finite Luanti candidate inspection and activation"
        evidence = "three real Luanti attack outcome sources"
        candidate_disposition = "RETAIN"
        experience_disposition = "DEFER"
    } | ConvertTo-Json
    $t1 = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/v1/luanti-t1-cutover" `
        -ContentType "application/json" -Body $t1Body -TimeoutSec 5
    if ($t1.result.projected_candidates.Count -ne 3) { throw "Expected three projected candidates" }
    if ($t1.result.artifact.status -ne "RECONSTRUCTED_INACTIVE") { throw "M_B prime was not reconstructed" }
    if ($t1.result.cutover.status -ne "CUTOVER_ACCEPTED") { throw "Cutover was not accepted" }

    Start-Sleep -Seconds 1
    $after = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/canonical-snapshot" -TimeoutSec 3
    if ($after.M_delta.active_count -ne 0) { throw "M_delta remained active after cutover" }
    if ($after.M_delta.states[-1].phase -ne "REENTERED") { throw "Expected REENTERED phase" }
    $newModel = $t1.result.artifact.model_ref
    if (-not $after.models.PSObject.Properties[$newModel]) { throw "Reconstructed model is not active" }
    if (-not $after.model_archive.PSObject.Properties[$t1.result.artifact.parent_model_ref]) {
        throw "Parent model was not archived"
    }
    Write-Output "L7 PASS: model=$newModel phase=REENTERED projected=3"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
