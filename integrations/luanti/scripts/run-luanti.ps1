param([string]$LuantiRoot = "D:\luanti")

$ErrorActionPreference = "Stop"
$integrationRoot = Split-Path -Parent $PSScriptRoot
$worldPath = Join-Path $integrationRoot "worlds\rdl_l0_l2"
$configPath = Join-Path $integrationRoot "config\luanti.conf"
$worldTemplate = Join-Path $integrationRoot "world-template\world.mt"
$logPath = Join-Path $integrationRoot "output\luanti-l0-l2.log"

& (Join-Path $PSScriptRoot "install-game.ps1") -LuantiRoot $LuantiRoot
New-Item -ItemType Directory -Force -Path $worldPath | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $worldPath "world.mt"))) {
    Copy-Item -LiteralPath $worldTemplate -Destination (Join-Path $worldPath "world.mt")
}

& (Join-Path $LuantiRoot "bin\luanti.exe") --server --gameid rdl_game `
    --world $worldPath --config $configPath --logfile $logPath --color never
