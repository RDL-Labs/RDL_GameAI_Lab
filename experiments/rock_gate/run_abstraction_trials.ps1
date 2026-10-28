param([Parameter(Mandatory=$true)][string]$Julia,[Parameter(Mandatory=$true)][string]$Root,[ValidateSet(3,30,90)][int]$Days=3)
$ErrorActionPreference='Stop'
$env:JULIA_NUM_THREADS='1'
$env:OPENBLAS_NUM_THREADS='1'
# Freeze all four cases together, so later repository edits cannot change queued runs.
$frozen=Join-Path $Root 'frozen'
if (Test-Path -LiteralPath $frozen) { throw 'Fresh batch directory required' }
$null=New-Item -ItemType Directory -Path (Join-Path $frozen 'integrations'),(Join-Path $frozen 'experiments/rock_gate')
Copy-Item -LiteralPath src -Destination $frozen -Recurse
Copy-Item -LiteralPath integrations/lightweight_julia -Destination (Join-Path $frozen 'integrations') -Recurse
Copy-Item -LiteralPath Project.toml,Manifest.toml -Destination $frozen
$runner=Join-Path $frozen 'experiments/rock_gate/run_channel_trial.jl'
Copy-Item -LiteralPath experiments/rock_gate/run_channel_trial.jl -Destination $runner
@{days=$Days;seed=20261007;commit=(git rev-parse HEAD);order=@('standard','angle60','distance2','colors')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Root 'batch.json')
foreach ($mode in @('standard','angle60','distance2','colors')) {
    $inputPath=Join-Path $Root "$mode.json"
    $outputPath=Join-Path $Root $mode
    $logPath=Join-Path $Root "$mode.log"
    Write-Output "START $mode days=$Days"
    & $Julia --startup-file=no "--project=$frozen" $runner $inputPath $outputPath $Days 20261007 *> $logPath
    if ($LASTEXITCODE -ne 0) { throw "Trial failed: $mode (see $logPath)" }
    Write-Output "COMPLETE $mode"
}
