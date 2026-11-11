using JSON3, Serialization, Random
include(joinpath(abspath(ARGS[1]),"source/src/lw/LW.jl"))
# Compare values recursively, including RNG fields, without consuming RNG.
# Dictionary iteration order is not state equality. This does not audit alias topology.
function state_equal(a,b,seen=Set{Tuple{UInt,UInt}}())
    typeof(a)===typeof(b) || return false
    a===b && return true
    a isa Union{Number,AbstractString,Symbol,Char,Type} && return isequal(a,b)
    pair=(objectid(a),objectid(b));pair in seen && return true;push!(seen,pair)
    if a isa AbstractDict
        length(a)==length(b) || return false
        return all(haskey(b,k) && state_equal(v,b[k],seen) for (k,v) in a)
    elseif a isa AbstractSet
        return isequal(a,b)
    elseif a isa AbstractArray
        axes(a)==axes(b) || return false
        return all(state_equal(a[i],b[i],seen) for i in eachindex(a))
    end
    all(state_equal(getfield(a,i),getfield(b,i),seen) for i in 1:fieldcount(typeof(a)))
end
baseline_dir=abspath(ARGS[2]);revised_dir=abspath(ARGS[3]);day=parse(Int,ARGS[4])
file="day-"*lpad(day,3,'0')*".jls"
baseline=deserialize(joinpath(baseline_dir,"checkpoints",file)).state
revised=deserialize(joinpath(revised_dir,"checkpoints",file)).state
checks=Dict{String,Bool}()
for key in (:events,:counts,:mb_maps,:loops,:states,:storage_stats)
    @assert haskey(baseline,key) key
    checks[string(key)]=state_equal(baseline[key],revised[key])
end
checks["physical"]=state_equal(baseline[:daily][end]["physical"],revised[:daily][end]["physical"])
checks["home_activity"]=state_equal(baseline[:daily][end]["home_activity"],revised[:daily][end]["home_activity"])
before=JSON3.read(read(joinpath(baseline_dir,"result.json"),String),Dict{String,Any})
after=JSON3.read(read(joinpath(revised_dir,"result.json"),String),Dict{String,Any})
checks["cognition_ticks"]=Dict(k=>v for (k,v) in before["timing"] if occursin(':',k))==Dict(k=>v for (k,v) in after["timing"] if occursin(':',k))
result=(;day,baseline_dir,revised_dir,checks,before,after)
write(ARGS[5],JSON3.write(result));println(JSON3.write((day,checks)))
@assert all(values(checks)) checks
