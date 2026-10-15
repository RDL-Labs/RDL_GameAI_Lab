$ErrorActionPreference='Stop'
$env:JULIA_DEPOT_PATH='C:\Users\ken_m\Documents\Codex\tools\julia-depot'
$env:JULIA_NUM_THREADS='1'
$env:OPENBLAS_NUM_THREADS='1'
$env:NUMERIC_AGENT_COUNT='30'
$env:NUMERIC_ID_TRACKING='off'
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class NumericTrackingAwake { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags); }'
[NumericTrackingAwake]::SetThreadExecutionState(2147483649) | Out-Null
try {
 $started=Get-Date
 $proc=Start-Process -FilePath 'C:\Users\ken_m\Documents\Codex\tools\julia-1.13.1\bin\julia.exe' -ArgumentList @('--startup-file=no',"--project=$PSScriptRoot\source\julia","$PSScriptRoot\run.jl","$PSScriptRoot\..\numeric-cpu-full\30agents-1day.json","$PSScriptRoot\off-30.json") -PassThru -WindowStyle Hidden -RedirectStandardOutput "$PSScriptRoot\30agents.stdout.log" -RedirectStandardError "$PSScriptRoot\30agents.stderr.log"
 $null=$proc.Handle
 Set-Content "$PSScriptRoot\30agents.status.txt" 'running'
 Set-Content "$PSScriptRoot\30agents.pid.txt" $proc.Id
 while(-not $proc.HasExited) {
  $proc.Refresh()
  if(-not $proc.HasExited) {
   [pscustomobject]@{wall_seconds=((Get-Date)-$started).TotalSeconds;working_set_bytes=$proc.WorkingSet64;peak_working_set_bytes=$proc.PeakWorkingSet64;cpu_seconds=$proc.TotalProcessorTime.TotalSeconds} | ConvertTo-Json -Compress | Add-Content "$PSScriptRoot\30agents.memory.jsonl"
  }
  if(((Get-Date)-$started).TotalSeconds -gt 1800){Stop-Process -Id $proc.Id; throw '30 minute test limit'}
  Start-Sleep -Seconds 5
 }
 $proc.WaitForExit()
 Set-Content "$PSScriptRoot\30agents.status.txt" "finished; exit_code=$($proc.ExitCode); wall_seconds=$(((Get-Date)-$started).TotalSeconds)"
} catch { Set-Content "$PSScriptRoot\30agents.status.txt" "failed: $_"; if($proc -and -not $proc.HasExited){Stop-Process -Id $proc.Id}; throw } finally { [NumericTrackingAwake]::SetThreadExecutionState(2147483648) | Out-Null }


