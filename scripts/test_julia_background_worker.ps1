# Regression: Windows PowerShell must not convert Julia warnings into failures.
# Artifacts remain under the unique temporary directory printed at completion.
param([Parameter(Mandatory)][string]$JuliaPath, [Parameter(Mandatory)][string]$DepotPath)
$ErrorActionPreference='Stop'
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('rdl-julia-worker-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$testWorker=Join-Path $PSScriptRoot 'run_julia_scheduled.ps1'
$testCases=@(
    @{name='warning';expression='@warn :background_warning_probe; println(:continued_after_warning); exit(0)';exit_code=0},
    @{name='failure';expression='exit(7)';exit_code=7}
)
foreach ($testCase in $testCases) {
    $testPrefix=Join-Path $testRoot $testCase.name
    $testConfig=$testPrefix+'.config.json'
    @{julia_path=(Resolve-Path $JuliaPath).Path;working_directory=$testRoot;depot_path=(Resolve-Path $DepotPath).Path;arguments=@('--startup-file=no','-e',$testCase.expression);prefix=$testPrefix;threads=1} | ConvertTo-Json | Set-Content -LiteralPath $testConfig -Encoding UTF8
    $testProcess=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -Wait -PassThru -ArgumentList ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$testWorker+'" -WorkerConfig "'+$testConfig+'"')
    $testExit=Get-Content -LiteralPath ($testPrefix+'.exit.json') -Raw | ConvertFrom-Json
    if ($testExit.exit_code -ne $testCase.exit_code -or $testProcess.ExitCode -ne $testCase.exit_code -or $null -ne $testExit.error) { throw "Wrong exit result: $($testCase.name)" }
    if ($testCase.name -eq 'warning') {
        if ((Get-Content ($testPrefix+'.stderr.log') -Raw) -notmatch 'background_warning_probe') { throw 'Warning was lost.' }
        if ((Get-Content ($testPrefix+'.stdout.log') -Raw) -notmatch 'continued_after_warning') { throw 'Execution did not continue after warning.' }
    }
}
Write-Output "PASS: warning continues and is logged; nonzero exit is preserved. Artifacts: $testRoot"
