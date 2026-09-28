param([string]$LuantiRoot = "D:\luanti")

$ErrorActionPreference = "Stop"
$integrationRoot = Split-Path -Parent $PSScriptRoot
$sourceGame = Join-Path $integrationRoot "game\rdl_game"
$targetGame = Join-Path $LuantiRoot "games\rdl_game"

if (-not (Test-Path -LiteralPath (Join-Path $LuantiRoot "bin\luanti.exe"))) {
    throw "Luanti executable not found under $LuantiRoot"
}

New-Item -ItemType Directory -Force -Path (Join-Path $targetGame "mods\rdl_bridge") | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceGame "game.conf") -Destination $targetGame -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\mod.conf") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\init.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\multi_agent_food.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\sensor_profiles.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\distant_observation.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\audition_observation.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\audition_receive_window.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\life_sensory.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\distant_sensor.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\audition_window_sensor.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\audition_transmission.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force

Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\auditory_candidates_fixture.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\visual_probe.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\visual_probe_fixture.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\visual_probe_checks.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\continuous_visual_controller.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\probe_arbiter.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\continuous_probe_fixture.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\probe_arbiter_checks.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\observation_v1_fixture.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\observation_v1_sampler.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\observation_v1_checks.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Write-Output "Installed rdl_game into $targetGame"
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\sensory_learning_fixture.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\multi_sensory_learning_fixture.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
foreach ($module in @("shared_food_trial.lua", "shared_food_trial_checks.lua", "shared_food_learning_fixture.lua")) {
    Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\$module") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
}
foreach ($module in @("resource_use_trial.lua", "resource_use_checks.lua", "resource_use_fixture.lua", "boundary_defense_trial.lua", "boundary_defense_checks.lua", "boundary_defense_fixture.lua")) {
    Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\$module") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
}

foreach ($module in @("exploration_fixture.lua", "multi_resource_fixture.lua", "movement_surface.lua", "exploration_ground.lua", "exploration_controller.lua", "exploration_checks.lua", "exploration_natural.lua", "exploration_natural_checks.lua", "exploration_landmarks.lua", "elevated_landmarks.lua", "exploration_landmark_checks.lua", "exploration_food_set.lua", "exploration_food_set_checks.lua", "resource_patches.lua", "resource_patches_checks.lua")) {
    Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\$module") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
}
$textureTarget = Join-Path $targetGame "mods\rdl_bridge\textures"
Copy-Item -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\movement_surface_checks.lua") -Destination (Join-Path $targetGame "mods\rdl_bridge") -Force
New-Item -ItemType Directory -Force -Path $textureTarget | Out-Null
Get-ChildItem -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\textures") -Filter "rdl_l13_*.png" | Copy-Item -Destination $textureTarget -Force
Get-ChildItem -LiteralPath (Join-Path $sourceGame "mods\rdl_bridge\textures") -Filter "rdl_l14_*.png" | Copy-Item -Destination $textureTarget -Force
