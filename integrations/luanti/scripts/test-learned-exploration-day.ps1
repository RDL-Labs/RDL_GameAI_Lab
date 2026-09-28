param(
    [string]$LuantiRoot = "D:\luanti",
    [ValidateSet("straight","right","left","rotated","no_strip","no_food","partial","blocked","faults","natural_meadow","natural_woodland")]
    [string]$Scenario = "straight",
    [Parameter(Mandatory=$true)][string]$RunId,
    [switch]$Landmarks,
    [switch]$Neighborhood,
    [switch]$MultiFood,
    [switch]$Resources,
    [ValidateRange(1,30)][int]$ResourcePeriods = 30,
    [switch]$ResourceControl,
    [switch]$ResourceFaults,
    [switch]$MultiResources,
    [ValidateSet("off","disabled","enabled")][string]$ReversalReviewMode = "off",
    [ValidateSet(0,16,32,64)][int]$TaskSeconds = 0,
    [ValidateRange(1,16)][double]$SimulationSpeed = 1,
    [switch]$MovementTerrain,
    [switch]$MovementSteering,
    [ValidateSet("off","disabled","fatigue","repetition","combined")][string]$RestMode = "off",
    [ValidateSet("off","disabled","enabled")][string]$ReassessmentMode = "off",
    [ValidateSet("off","persistent","removed")][string]$ObstacleProbe = "off",
    [ValidateSet("off","disabled","enabled")][string]$ReactivationMode = "off",
    [ValidateSet("off","disabled","frozen")][string]$TieBreakMode = "off",
    [ValidateSet("off","neutral","mixed","swapped","left","right")][string]$LateralAssignment = "off",
    [ValidateSet("mixed","swapped","steady")][string]$ResourceAssignment = "mixed"
)
$ErrorActionPreference = "Stop"
if ($ReversalReviewMode -ne "off" -and $TaskSeconds -eq 0) { throw "Review requires task deadline" }
if ($TaskSeconds -ne 0 -and (-not $MultiResources -or $ResourcePeriods -ne 1 -or $ReassessmentMode -eq "off")) { throw "Single reassessment task required" }
if ($SimulationSpeed -ne 1 -and -not $MultiResources) { throw "Speed experiment requires MultiResources" }
if ($MultiResources) { $Resources = [switch]::new($true) }
if ($MovementSteering) { $MovementTerrain = [switch]::new($true) }
if ($RestMode -ne "off" -and (-not $MovementSteering -or $TieBreakMode -ne "off" -or $LateralAssignment -ne "off")) { throw "Rest requires isolated steering" }
if ($ReassessmentMode -ne "off" -and $ReactivationMode -eq "off") { throw "Reassessment requires reactivation" }
if ($ObstacleProbe -ne "off" -and (-not $MultiResources -or $ReactivationMode -eq "off")) { throw "Obstacle probe requires multi-agent reactivation" }
if ($ReactivationMode -ne "off" -and $RestMode -eq "off") { throw "Reactivation requires rest" }
if ($TieBreakMode -ne "off") {
    if ($MovementSteering -or $LateralAssignment -ne "off") { throw "Tie break only mode" }
    $MovementTerrain = [switch]::new($true)
}
if ($LateralAssignment -ne "off") {
    if ($MovementSteering) { throw "Lateral bias only cannot enable MovementSteering" }
    $MovementTerrain = [switch]::new($true)
}
if ($MovementTerrain -and -not $MultiResources) { throw "MovementTerrain requires MultiResources" }
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
rdl_fixture_mode = $(if ($MultiResources) { "multi_resource_exploration" } else { "finite_exploration" })
rdl_learning_run_id = $RunId
rdl_exploration_scenario = $Scenario
rdl_exploration_landmarks = $($Landmarks.IsPresent.ToString().ToLowerInvariant())
rdl_exploration_neighborhood = $($Neighborhood.IsPresent.ToString().ToLowerInvariant())
rdl_exploration_multi_food = $($MultiFood.IsPresent.ToString().ToLowerInvariant())
rdl_exploration_resources = $($Resources.IsPresent.ToString().ToLowerInvariant())
rdl_resource_periods = $ResourcePeriods
rdl_simulation_speed = $($SimulationSpeed.ToString([Globalization.CultureInfo]::InvariantCulture))
rdl_resource_control = $($ResourceControl.IsPresent.ToString().ToLowerInvariant())
rdl_resource_faults = $($ResourceFaults.IsPresent.ToString().ToLowerInvariant())
rdl_resource_assignment = $ResourceAssignment
rdl_movement_terrain = $($MovementTerrain.IsPresent.ToString().ToLowerInvariant())
rdl_movement_steering = $($MovementSteering.IsPresent.ToString().ToLowerInvariant())
rdl_rest_mode = $RestMode
rdl_reactivation_mode = $ReactivationMode
rdl_obstacle_probe = $ObstacleProbe
rdl_reassessment_mode = $ReassessmentMode
rdl_task_seconds = $TaskSeconds
rdl_reversal_review_mode = $ReversalReviewMode
rdl_lateral_assignment = $LateralAssignment
rdl_tie_break_mode = $TieBreakMode
time_speed = 0
port = 30001
max_users = 1
default_game = rdl_game
mg_name = singlenode
dedicated_server_step = $((0.02/$SimulationSpeed).ToString([Globalization.CultureInfo]::InvariantCulture))
"@ | Set-Content -LiteralPath $config -Encoding utf8
if ($Resources) { Add-Content -LiteralPath $config -Value "max_forceloaded_blocks = 256" -Encoding utf8 }
$health = Invoke-RestMethod "http://127.0.0.1:8765/health" -TimeoutSec 2
$expectedSchema = if ($Resources) { "l14a-continuous-resource-exploration-v1" } else { "l13s-learned-exploration-v1" }
if ($MultiResources) { $expectedSchema = "l14b-multi-resource-predictability-v1" }
if ($MovementTerrain) { $expectedSchema = "l15a-terrain-resource-exploration-v1" }
if ($MovementSteering) { $expectedSchema = "l15a-terrain-resource-steering-v2" }
if ($RestMode -ne "off") { $expectedSchema = "l15a-movement-rest-v1" }
if ($ReactivationMode -ne "off") { $expectedSchema = "l15a-rest-reactivation-v1" }
if ($ReassessmentMode -ne "off") { $expectedSchema = "l15a-goal-reassessment-v1" }
if ($TaskSeconds -ne 0) { $expectedSchema = "l15a-task-deadline-v1" }
if ($ReversalReviewMode -ne "off") { $expectedSchema = "l15a-reversal-review-v1" }
if ($LateralAssignment -ne "off") { $expectedSchema = "l15a-terrain-lateral-bias-v1" }
if ($TieBreakMode -ne "off") { $expectedSchema = "l15a-terrain-tie-break-v1" }
if (-not $health.ok -or $health.run_id -ne $RunId -or $health.schema -ne $expectedSchema) { throw "Unexpected exploration Runtime" }
if ($Resources -and $health.periods -ne $ResourcePeriods) { throw "Resource period mismatch" }
$luanti = $null
try {
    $initial = Invoke-RestMethod "http://127.0.0.1:8765/v1/exploration-snapshot" -TimeoutSec 5
    $luanti = Start-Process -FilePath (Join-Path $LuantiRoot "bin\luanti.exe") -ArgumentList `
        "--server","--gameid","rdl_game","--world",$worldPath,"--config",$config,"--logfile",(Join-Path $outputPath "$RunId.log"),"--color","never" `
        -WorkingDirectory $LuantiRoot -RedirectStandardOutput (Join-Path $outputPath "$RunId.world.out.log") `
        -RedirectStandardError (Join-Path $outputPath "$RunId.world.err.log") -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($(if ($Resources) { $ResourcePeriods*$(if ($TaskSeconds) { $TaskSeconds } else { 16 })+35 } else { 50 }))
    do {
        Start-Sleep -Milliseconds 100
        $evidenceFile = if ($MultiResources) { "l14b-evidence.json" } else { "l13a-evidence.json" }
        $complete = Test-Path -LiteralPath (Join-Path $worldPath $evidenceFile)
    } while (-not $complete -and -not $luanti.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if (-not $complete) { throw "L13S World did not complete" }
    $world = Get-Content -LiteralPath (Join-Path $worldPath $evidenceFile) -Raw | ConvertFrom-Json
    $state = Invoke-RestMethod "http://127.0.0.1:8765/v1/exploration-snapshot" -TimeoutSec 5
    $snapshot = Join-Path $outputPath "$RunId.snapshot.json"
    @{world=$world; runtime=$state; initial=$initial} | ConvertTo-Json -Depth 90 | Set-Content -LiteralPath $snapshot -Encoding utf8
    if ($world.failure) { throw "World failure: $($world.failure)" }
    Write-Output "L13S SNAPSHOT: $snapshot"
} finally {
    if ($luanti -and -not $luanti.HasExited) { Stop-Process -Id $luanti.Id -Force; $luanti.WaitForExit() }
}
