param(
    [string]$LuantiRoot = "D:\luanti",
    [ValidateSet("straight","right","left","rotated","no_strip","no_food","partial","blocked","faults","natural_meadow","natural_woodland")]
    [string]$Scenario = "straight",
    [Parameter(Mandatory=$true)][string]$RunId
)
$ErrorActionPreference = "Stop"
if ($RunId -notmatch '^[A-Za-z0-9_-]{1,64}$') { throw "Invalid RunId" }
$integrationRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $integrationRoot "output"
$worldPath = Join-Path $integrationRoot "worlds\$RunId"
if (Test-Path -LiteralPath $worldPath) { throw "World already exists: $worldPath" }
New-Item -ItemType Directory -Force -Path $outputPath,$worldPath | Out-Null
& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
Copy-Item -LiteralPath (Join-Path $integrationRoot "world-template\world.mt") -Destination (Join-Path $worldPath "world.mt")
$config = Join-Path $outputPath "$RunId.conf"
@"
server_announce = false
creative_mode = true
secure.http_mods = rdl_bridge
rdl_runtime_url = http://127.0.0.1:8765/v1/observe
rdl_fixture_mode = finite_exploration
rdl_learning_run_id = $RunId
rdl_exploration_scenario = $Scenario
time_speed = 0
port = 30001
max_users = 1
default_game = rdl_game
mg_name = singlenode
dedicated_server_step = 0.02
"@ | Set-Content -LiteralPath $config -Encoding utf8
$health = Invoke-RestMethod "http://127.0.0.1:8765/health" -TimeoutSec 2
if (-not $health.ok -or $health.run_id -ne $RunId -or $health.schema -ne "l13s-learned-exploration-v1") { throw "Unexpected learned Runtime" }
$luanti = $null
try {
    $initial = Invoke-RestMethod "http://127.0.0.1:8765/v1/exploration-snapshot" -TimeoutSec 5
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") -ArgumentList `
        "--server","--gameid","rdl_game","--world",$worldPath,"--config",$config,"--logfile",(Join-Path $outputPath "$RunId.log"),"--color","never" `
        -WorkingDirectory $LuantiRoot -RedirectStandardOutput (Join-Path $outputPath "$RunId.world.out.log") `
        -RedirectStandardError (Join-Path $outputPath "$RunId.world.err.log") -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(50)
    do {
        Start-Sleep -Milliseconds 100
        $complete = Test-Path -LiteralPath (Join-Path $worldPath "l13a-evidence.json")
    } while (-not $complete -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $complete) { throw "L13S World did not complete" }
    $world = Get-Content -LiteralPath (Join-Path $worldPath "l13a-evidence.json") -Raw | ConvertFrom-Json
    $state = Invoke-RestMethod "http://127.0.0.1:8765/v1/exploration-snapshot" -TimeoutSec 5
    $snapshot = Join-Path $outputPath "$RunId.snapshot.json"
    @{world=$world; runtime=$state; initial=$initial} | ConvertTo-Json -Depth 90 | Set-Content -LiteralPath $snapshot -Encoding utf8
    if ($world.failure) { throw "World failure: $($world.failure)" }
    Write-Output "L13S SNAPSHOT: $snapshot"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
}
