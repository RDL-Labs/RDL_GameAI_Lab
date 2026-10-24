# Bounded early-exit experiment: World geometry is used ONLY by the observer.
using JSON3, SHA, Test
root=normpath(joinpath(@__DIR__,"../.."))
out=abspath(ARGS[1]);ispath(out) && error("fresh output required");mkpath(out)
input_path=abspath(ARGS[2])
snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(root,"src"),joinpath(snapshot,"src"))
cp(joinpath(root,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
dayfile=joinpath(snapshot,"src/lw/simulation/day.jl");original=read(dayfile,String)
anchor="        advance_physiology!(w,metabolism,guts,food_body)"
@assert count(anchor,original)==1
write(dayfile,replace(original,anchor=>anchor*"\n        Main.exit_probe!(sec,w,plans,spec.home)"))
struct ProbeComplete <: Exception end
first_exit=Dict{String,Int}();offered_selected=Dict{String,Int}()
const limit=3000
function exit_probe!(sec,w,plans,home)
    for a in keys(w.positions)
        p=w.positions[a]
        if hypot(p[1]-home[1],p[2]-home[2])>5 && !haskey(first_exit,a)
            first_exit[a]=sec+1
        end
        haskey(plans[a],"opening_samples") && (offered_selected[a]=get(offered_selected,a,0)+1)
    end
    sec+1==limit && throw(ProbeComplete())
end
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
base=JSON3.read(read(input_path,String),Dict{String,Any});base["config"]["days"]=1
results=Any[]
seeds=length(ARGS)>=3 ? parse.(Int,split(ARGS[3],',')) : [20261005,20261006,20261007]
for seed in seeds, mode in ("off","on")
    empty!(first_exit);empty!(offered_selected)
    input=deepcopy(base);input["config"]["seed"]=seed
    input["config"]["rho_profile"]="coarse";input["config"]["rho_openings"]=mode
    write(joinpath(out,"spec-$seed-$mode.json"),JSON3.write(input))
    elapsed=@elapsed try
        run_integrated(JSON3.read(JSON3.write(input)))
        error("probe did not stop")
    catch e
        e isa ProbeComplete || rethrow()
    end
    @test all(0<t<=limit for t in values(first_exit))
    mode=="off" && (@test isempty(offered_selected))
    row=(seed=seed,mode=mode,limit=limit,first_exit=copy(first_exit),opening_selected=copy(offered_selected),seconds=elapsed)
    push!(results,row);write(joinpath(out,"comparison.json"),JSON3.write(results))
    println(JSON3.write(row));flush(stdout)
end
write(joinpath(out,"provenance.json"),JSON3.write((julia=string(VERSION),input_sha256=bytes2hex(sha256(read(input_path))),
    source_day_sha256=bytes2hex(sha256(original)),scope="first exit within 3000 ticks; early stop; no return success claim")))
