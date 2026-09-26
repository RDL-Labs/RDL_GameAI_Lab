param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_l4"
$runId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$runtimeOut = Join-Path $outputPath "runtime-l4-$runId.stdout.log"
$runtimeErr = Join-Path $outputPath "runtime-l4-$runId.stderr.log"
$luantiOut = Join-Path $outputPath "luanti-l4-$runId.stdout.log"
$luantiErr = Join-Path $outputPath "luanti-l4-$runId.stderr.log"
$luantiLog = Join-Path $outputPath "luanti-l4-$runId.log"

New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
if (-not (Test-Path -LiteralPath (Join-Path $worldPath "world.mt"))) {
    Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") -Destination (Join-Path $worldPath "world.mt")
}

$runtime = $null
$luanti = $null
try {
    $runtime = Start-Process -FilePath "python" `
        -ArgumentList "-m", "runtime.bridge", "--base-food-life" `
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
        "--config", (Join-Path $integrationRoot "config\luanti-l4.conf"),
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
            $evidence = Select-String -LiteralPath $luantiLog -Pattern "RDL_LUANTI_L4_EVIDENCE.*warning_chase_attack" | Select-Object -Last 1
        }
    } while (-not $evidence -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $evidence) { throw "L4 Territory evidence was not produced within $TimeoutSeconds seconds" }

    $responses = Select-String -LiteralPath $luantiLog -Pattern "territory_response=(warning|chase|attack)" | ForEach-Object {
        if ($_.Line -match "territory_response=(warning|chase|attack)") { $Matches[1] }
    }
    $joined = ($responses -join ",")
    if ($joined -notmatch "^warning,(chase,)+attack$") {
        throw "L4 response order was not warning,chase,attack: $joined"
    }
    Write-Output "L4 PASS: $($evidence.Line.Trim())"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
