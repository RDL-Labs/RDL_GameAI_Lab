# Behavioral experiment: preserve original checkpoint validation, then explicitly
# overlay both trade planners and switch peer rho after restoring each trial.
length(ARGS)==5 || error("usage: benchmark_peer_rho_day.jl RUN DAY rho-off|rho-on NEW_OUTPUT OVERLAY_SOURCE")
ARGS[3] in ("rho-off","rho-on") || error("peer rho mode")
const PEER_RHO=ARGS[3]=="rho-on"
ARGS[3]="on" # gradient logging always enabled
const benchmark_path=joinpath(@__DIR__,"benchmark_gradient_day.jl")
code=read(benchmark_path,String)
function swap_once(code,old,new)
    count(old,code)==1 || error("peer rho benchmark anchor mismatch")
    replace(code,old=>new)
end
code=swap_once(code,"prior_captured[a]=get(get(r,\"gradient_maps\",Dict()),\"captured\",0)",
    "r[\"peer_rho_enabled\"]=PEER_RHO\n        prior_captured[a]=get(get(r,\"gradient_maps\",Dict()),\"captured\",0)")
code=swap_once(code,"(\"src/lw/decision/item_exchange_memory.jl\",\"src/lw/decision/item_social.jl\")",
    "(\"src/lw/learning/social_peer_resolution.jl\",\"src/lw/decision/item_social.jl\",\"src/lw/decision/food_exchange.jl\")")
code=swap_once(code,"warmup_seconds=512,threads=Threads.nthreads()",
    "peer_rho_enabled=PEER_RHO,experiment=\"behavioral-peer-resolution\",warmup_seconds=512,threads=Threads.nthreads()")
Base.include_string(Main,code,benchmark_path)
