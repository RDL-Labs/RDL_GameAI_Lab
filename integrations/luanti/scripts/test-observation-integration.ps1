param(
    [string]$LuantiRoot = "D:\luanti",
    [int]$TimeoutSeconds = 25
)

$ErrorActionPreference = "Stop"
$integrationRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot "test-multi-agent.ps1") `
    -LuantiRoot $LuantiRoot `
    -TimeoutSeconds $TimeoutSeconds `
    -ConfigPath (Join-Path $integrationRoot "config\luanti-observation-integration.conf") `
    -ExpectedAVisible 2 `
    -ExpectedBVisible 1 `
    -ResultLabel "OBS6 LIFE PASS" `
    -SensoryObservation
