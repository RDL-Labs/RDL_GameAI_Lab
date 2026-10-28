param([Parameter(Mandatory=$true)][string]$Julia,[Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference='Stop'
$env:JULIA_NUM_THREADS='1'
$env:OPENBLAS_NUM_THREADS='1'
foreach ($mode in @('standard','angle60','distance2','colors')) {
    $inputPath=Join-Path $Root "$mode.json"
    $outputPath=Join-Path $Root $mode
    $logPath=Join-Path $Root "$mode.log"
    Write-Output "START $mode"
    & $Julia --startup-file=no --project=. experiments/rock_gate/run_channel_trial.jl $inputPath $outputPath 3 20261007 *> $logPath
    if ($LASTEXITCODE -ne 0) { throw "Trial failed: $mode (see $logPath)" }
    Write-Output "COMPLETE $mode"
}
