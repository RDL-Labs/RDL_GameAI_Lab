param([string]$JuliaExe, [string]$Depot, [string]$OutputPrefix)
$ErrorActionPreference = 'Stop'
if (!$JuliaExe -or !$Depot -or !$OutputPrefix) { throw 'JuliaExe, Depot and OutputPrefix required' }
$env:JULIA_DEPOT_PATH = $Depot
$common = @('--natural-rocks','--finite-scattered-food','--choice-seed','20261006',
 '--goal-arrival','--camp-experience-mb','--camp-landmark-shortcut','--central-bonfire',
 '--checkpoints','--no-artificial-roads','--world-seed','20261027','--ordinary-only',
 '--staged-food','--distinctive-landmarks','--far-transfer-map','--hazards','off',
 '--daily-delivery','on','--camp-safe-zone','on','--days','3','--rho','home-distance',
 '--rho-openings','on','--food-roads','on','--general-landmarks','on','--body-purpose','on',
 '--mb-simulation','on','--mb-chunks','on','--mb-sleep','on','--home-observation','on',
 '--camp-provisions','0','--mb-sensitivities','experiments/rock_gate/sensitivity_c1.json',
 '--world-features','on','--similarity-learning','on','--home-rest-reward','on',
 '--embedded-rest','on','--night-fear','on')
foreach ($k in @(1,2,4,8)) {
 $dest = "$OutputPrefix-k$k"
 Write-Output "START top-k=$k output=$dest"
 & $JuliaExe --startup-file=no --project=. experiments/rock_gate/run.jl $dest @common --retrieval-top-k $k *> "$dest.log"
 if ($LASTEXITCODE -ne 0) { throw "top-k=$k failed; inspect $dest.log" }
 Write-Output "COMPLETE top-k=$k"
}
