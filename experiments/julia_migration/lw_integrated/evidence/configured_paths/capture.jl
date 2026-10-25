include(joinpath(@__DIR__,"../../../../../integrations/lightweight_julia/native.jl"))
input=JSON3.read(read(joinpath(@__DIR__,"../../search_review_spec.json"),String),Dict{String,Any})
input["config"]["days"]=1
input["config"]["general_landmarks"]="on"
input["config"]["rho_profile"]="coarse"
input["scene"]["reserve"]=[60.,60.,60.]
input["clock"]["day_us"]=600_000_000
input["clock"]["phase_boundaries_us"]=[1_000_000,2_000_000,3_000_000,600_000_000]
input["clock"]["quiet_night_us"]=4_000_000
for mode in ("off","on")
 input["config"]["body_purpose"]=mode
 r,s=run_integrated(JSON3.read(JSON3.write(input)))
 write(ARGS[1]*"-"*mode*".json",JSON3.write(r))
end
