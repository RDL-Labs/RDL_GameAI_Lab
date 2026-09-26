param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_l5"
$runId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$runtimeOut = Join-Path $outputPath "runtime-l5-$runId.stdout.log"
$runtimeErr = Join-Path $outputPath "runtime-l5-$runId.stderr.log"
$luantiOut = Join-Path $outputPath "luanti-l5-$runId.stdout.log"
$luantiErr = Join-Path $outputPath "luanti-l5-$runId.stderr.log"
$luantiLog = Join-Path $outputPath "luanti-l5-$runId.log"

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
        "--config", (Join-Path $integrationRoot "config\luanti-l5.conf"),
        "--logfile", $luantiLog, "--color", "never"
    )
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") `
        -ArgumentList $luantiArgs -WorkingDirectory $LuantiRoot `
        -RedirectStandardOutput $luantiOut -RedirectStandardError $luantiErr `
        -WindowStyle Hidden -PassThru

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $evidence = $null
    do {
        Start-Sleep -Milliseconds 250
        if (Test-Path -LiteralPath $luantiLog) {
            $evidence = Select-String -LiteralPath $luantiLog -Pattern "RDL_LUANTI_L5_EVIDENCE.*accepted=true" | Select-Object -Last 1
        }
    } while (-not $evidence -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $evidence) { throw "L5 learning evidence was not produced within $TimeoutSeconds seconds" }

    $snapshot = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/luanti-outcome-snapshot" -TimeoutSec 2
    if ($snapshot.experiences.records.Count -ne 1) { throw "Expected one Experience" }
    if ($snapshot.gradients.count -ne 1) { throw "Expected one Outcome Gradient" }
    if ($snapshot.biases.count -ne 3) { throw "Expected three Local Bias records" }
    $relations = @($snapshot.biases.records | ForEach-Object { "$($_.relation):$($_.direction):$($_.strength)" })
    foreach ($expected in @("acquisition:negative:STRONG", "return:negative:MEDIUM", "injury:negative:MEDIUM")) {
        if ($expected -notin $relations) { throw "Missing expected Local Bias: $expected" }
    }
    Write-Output "L5 PASS: $($evidence.Line.Trim())"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
