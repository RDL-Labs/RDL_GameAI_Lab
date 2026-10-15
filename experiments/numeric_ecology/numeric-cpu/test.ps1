$ErrorActionPreference='Stop'
$env:JULIA_DEPOT_PATH='C:\Users\ken_m\Documents\Codex\tools\julia-depot'
$env:JULIA_NUM_THREADS='1'
$env:OPENBLAS_NUM_THREADS='1'
$julia='C:\Users\ken_m\Documents\Codex\tools\julia-1.13.1\bin\julia.exe'
foreach($variant in @('baseline','test-numeric')) {
 & $julia --startup-file=no "--project=$PSScriptRoot\source\julia" "$PSScriptRoot\parity.jl" $variant *> "$PSScriptRoot\$variant.log"
 if($LASTEXITCODE -ne 0){throw "$variant failed; inspect log"}
}
