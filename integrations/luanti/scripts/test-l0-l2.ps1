param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_l0_l2"
$runId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$runtimeOut = Join-Path $outputPath "runtime-$runId.stdout.log"
$runtimeErr = Join-Path $outputPath "runtime-$runId.stderr.log"
$luantiOut = Join-Path $outputPath "luanti-$runId.stdout.log"
$luantiErr = Join-Path $outputPath "luanti-$runId.stderr.log"
$luantiLog = Join-Path $outputPath "luanti-$runId.log"

New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
if (-not (Test-Path -LiteralPath (Join-Path $worldPath "world.mt"))) {
    Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") -Destination (Join-Path $worldPath "world.mt")
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
        "--config", (Join-Path $integrationRoot "config\luanti.conf"),
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
            $evidence = Select-String -LiteralPath $luantiLog -Pattern "RDL_LUANTI_EVIDENCE.*pickup_succeeded" | Select-Object -Last 1
        }
    } while (-not $evidence -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $evidence) { throw "L0-L2 pickup evidence was not produced within $TimeoutSeconds seconds" }
    Write-Output "L0-L2 PASS: $($evidence.Line.Trim())"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
