using Serialization, SHA

# Persistent state only: observations/plans are rebuilt on the next tick.
# Serialize as ONE graph to preserve aliases and private RNG states.
const LW_CHECKPOINT_FIELDS=Tuple(Symbol.(split("relations trades foods wildlife mb_maps cue_states repetitions breadth_stats lateral_stats w climb_stats hazard_world sky safety_loops safety horizons inertia trails bundles configured_body_states hunger guts metabolism body_fields response_stats skyline_states reposition_states ground_models ground_receipts wear wear_offset ground_views ground_stats food dropped observation_states yaw stock shared storage_stats stores states live results answered learning counts events previous distance run_stats routes relation_fields harvest harvest_pending field_stats cargo max_radius loops action_models general purposes pending daily day_starts initial replenished replenishments")))
macro lw_capture()
    esc(:(Dict{Symbol,Any}($( [:( $(QuoteNode(k)) => $k) for k in LW_CHECKPOINT_FIELDS]...))))
end
macro lw_restore(state)
    esc(Expr(:block,[:($k=$state[$(QuoteNode(k))]) for k in LW_CHECKPOINT_FIELDS]...))
end
function checkpoint_code_hash()
    root=normpath(joinpath(@__DIR__,"../.."))
    files=sort([joinpath(d,f) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl")])
    bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
end
function checkpoint_save(dir,day,state,identity,code)
    mkpath(dir);path=joinpath(dir,"day-"*lpad(day,3,'0')*".jls")
    ispath(path) && error("checkpoint already exists: $path")
    temp=path*".tmp"
    try
        serialize(temp,(format="lw-daily-v1",julia=string(VERSION),code=code,identity=identity,day=day,state=state))
        mv(temp,path)
    finally
        isfile(temp) && rm(temp)
    end
    path
end
function checkpoint_load(path,identity,code,days)
    c=deserialize(path) # Local trusted files only; Julia serialization is not an interchange format.
    c.format=="lw-daily-v1" || error("checkpoint format mismatch")
    c.julia==string(VERSION) || error("checkpoint Julia version mismatch")
    c.code==code || error("checkpoint source mismatch")
    c.identity==identity || error("checkpoint input mismatch")
    0<c.day<days || error("checkpoint day must precede requested final day")
    Set(keys(c.state))==Set(LW_CHECKPOINT_FIELDS) || error("checkpoint fields mismatch")
    c
end
