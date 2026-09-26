param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 10
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\rdl_invalid_sensor_profile"
$runId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff")
$luantiLog = Join-Path $outputPath "luanti-invalid-sensor-$runId.log"
$luantiOut = Join-Path $outputPath "luanti-invalid-sensor-$runId.stdout.log"
$luantiErr = Join-Path $outputPath "luanti-invalid-sensor-$runId.stderr.log"

New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
if (-not (Test-Path -LiteralPath (Join-Path $worldPath "world.mt"))) {
    Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") `
        -Destination (Join-Path $worldPath "world.mt")
}

$luanti = $null
try {
    $args = @(
        "--server", "--gameid", "rdl_game", "--world", $worldPath,
        "--config", (Join-Path $integrationRoot "config\luanti-invalid-sensor-profile.conf"),
        "--logfile", $luantiLog, "--color", "never"
    )
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") `
        -ArgumentList $args -WorkingDirectory $LuantiRoot `
        -RedirectStandardOutput $luantiOut -RedirectStandardError $luantiErr `
        -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $rejection = $null
    do {
        Start-Sleep -Milliseconds 100
        if (Test-Path -LiteralPath $luantiLog) {
            $rejection = Select-String -LiteralPath $luantiLog `
                -Pattern "unknown RDL sensor profile for npc_a: unknown-profile" | Select-Object -Last 1
        }
    } while (-not $rejection -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $rejection) { throw "Unknown sensor profile was not explicitly rejected" }
    Write-Output "INVALID SENSOR PROFILE PASS: unknown-profile rejected"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
}
