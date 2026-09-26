param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_auditory_candidates"
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
        "--config", (Join-Path $integrationRoot "config\luanti-auditory-candidates.conf"),
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
                -Pattern "RDL_LUANTI_OBS7B.*complete frames=8 accepted=true" | Select-Object -Last 1
        }
    } while (-not $delivered -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $delivered) { throw "Audition observation evidence was not produced" }

    $snapshot = Invoke-RestMethod -Uri "http://127.0.0.1:8765/v1/sensory-observation-snapshot" -TimeoutSec 3
    $snapshotPath = Join-Path $outputPath "obs7b-$runId.snapshot.json"
    $snapshot | ConvertTo-Json -Depth 30 | Set-Content -Encoding utf8 $snapshotPath
    Push-Location $repoRoot
    try {
        & python -m integrations.luanti.tests.check_auditory_candidates $snapshotPath
        if ($LASTEXITCODE -ne 0) { throw "OBS-7B replay checks failed" }
    } finally { Pop-Location }
    Write-Output "OBS7B SNAPSHOT: $snapshotPath"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
    if ($runtime -and -not $runtime.HasExited) { Stop-Process -Id $runtime.Id -Force; $runtime.WaitForExit() }
}
