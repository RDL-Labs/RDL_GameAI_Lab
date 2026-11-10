<#
One-shot Windows Julia run owned by Task Scheduler, not the calling tool's job.
No recurring trigger, password, administrator principal, or global setting change.
The user must remain logged in. Sleep/reboot recovery is not implemented.
Inspect <RunPrefix>.exit.json AND the experiment's completed.json, then unregister
the task named in <RunPrefix>.launch.json. Never reuse a RunPrefix.
#>
[CmdletBinding(DefaultParameterSetName='Launch')]
param(
    [Parameter(Mandatory, ParameterSetName='Launch')][string]$JuliaPath,
    [Parameter(Mandatory, ParameterSetName='Launch')][string]$WorkingDirectory,
    [Parameter(Mandatory, ParameterSetName='Launch')][string]$DepotPath,
    [Parameter(Mandatory, ParameterSetName='Launch')][string[]]$JuliaArguments,
    [Parameter(Mandatory, ParameterSetName='Launch')][string]$RunPrefix,
    [Parameter(ParameterSetName='Launch')][ValidateRange(1,256)][int]$Threads=1,
    # Explicit wall-time limit; 0 disables it for user-requested open-ended runs.
    [Parameter(ParameterSetName='Launch')][ValidateRange(0,168)][int]$MaxHours=24,
    [Parameter(Mandatory, ParameterSetName='Worker')][string]$WorkerConfig
)
$ErrorActionPreference='Stop'
if ($PSCmdlet.ParameterSetName -eq 'Worker') {
    $runConfig=Get-Content -LiteralPath $WorkerConfig -Raw | ConvertFrom-Json
    $runStarted=[DateTime]::UtcNow
    $runExit=1
    $runError=$null
    try {
        Set-Location -LiteralPath $runConfig.working_directory
        $env:JULIA_DEPOT_PATH=$runConfig.depot_path
        $env:JULIA_NUM_THREADS=[string]$runConfig.threads
        # All arguments are quoted individually; embedded quotes are rejected below.
        $runArguments=($runConfig.arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
        @{started_utc=$runStarted.ToString('o');wrapper_pid=$PID} | ConvertTo-Json | Set-Content -LiteralPath ($runConfig.prefix+'.started.json') -Encoding UTF8
        # -Wait keeps the process handle available even for immediately exiting Julia.
        $runProcess=Start-Process -FilePath $runConfig.julia_path -ArgumentList $runArguments -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput ($runConfig.prefix+'.stdout.log') -RedirectStandardError ($runConfig.prefix+'.stderr.log')
        $runExit=$runProcess.ExitCode
        if ($null -eq $runExit) { throw 'Julia exited without a readable exit code.' }
    } catch {
        $runError=$_.Exception.ToString()
    } finally {
        @{started_utc=$runStarted.ToString('o');ended_utc=[DateTime]::UtcNow.ToString('o');exit_code=$runExit;error=$runError} | ConvertTo-Json | Set-Content -LiteralPath ($runConfig.prefix+'.exit.json') -Encoding UTF8
    }
    exit $runExit
}
$JuliaPath=(Resolve-Path -LiteralPath $JuliaPath).Path
$WorkingDirectory=(Resolve-Path -LiteralPath $WorkingDirectory).Path
$DepotPath=(Resolve-Path -LiteralPath $DepotPath).Path
$RunPrefix=[IO.Path]::GetFullPath($RunPrefix)
foreach ($runArgument in $JuliaArguments) {
    if ($runArgument.Contains('"') -or $runArgument.EndsWith('\')) {
        throw 'Arguments containing a quote or trailing backslash are unsupported; normalize the path first.'
    }
}
foreach ($runSuffix in @('', '.config.json','.launch.json','.started.json','.exit.json','.stdout.log','.stderr.log','.worker.ps1')) {
    if (Test-Path -LiteralPath ($RunPrefix+$runSuffix)) { throw "Run prefix already exists: $RunPrefix$runSuffix" }
}
$runParent=Split-Path -Parent $RunPrefix
if (!(Test-Path -LiteralPath $runParent -PathType Container)) { throw "Missing output parent: $runParent" }
$runTaskName='RDL-Julia-'+[Guid]::NewGuid().ToString('N')
$runConfigPath=$RunPrefix+'.config.json'
$runWorkerPath=$RunPrefix+'.worker.ps1'
Copy-Item -LiteralPath $PSCommandPath -Destination $runWorkerPath
@{julia_path=$JuliaPath;working_directory=$WorkingDirectory;depot_path=$DepotPath;arguments=$JuliaArguments;prefix=$RunPrefix;threads=$Threads} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $runConfigPath -Encoding UTF8
$runUser=[Security.Principal.WindowsIdentity]::GetCurrent().Name
$runAction=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$runWorkerPath+'" -WorkerConfig "'+$runConfigPath+'"') -WorkingDirectory $WorkingDirectory
$runPrincipal=New-ScheduledTaskPrincipal -UserId $runUser -LogonType Interactive -RunLevel Limited
# Scheduler priority 4 maps to normal process priority (default 7 is below normal).
$runSettings=New-ScheduledTaskSettingsSet -Priority 4 -ExecutionTimeLimit (New-TimeSpan -Hours $MaxHours) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $runTaskName -Action $runAction -Principal $runPrincipal -Settings $runSettings -Description 'One-shot RDL Julia experiment; remove after verifying outputs.' | Out-Null
@{task_name=$runTaskName;registered_utc=[DateTime]::UtcNow.ToString('o');max_hours=$MaxHours;scheduler_priority=4;user=$runUser;config=$runConfigPath} | ConvertTo-Json | Set-Content -LiteralPath ($RunPrefix+'.launch.json') -Encoding UTF8
Start-ScheduledTask -TaskName $runTaskName
Get-Content -LiteralPath ($RunPrefix+'.launch.json')

