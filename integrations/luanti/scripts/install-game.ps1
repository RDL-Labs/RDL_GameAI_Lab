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
Write-Output "Installed rdl_game into $targetGame"
