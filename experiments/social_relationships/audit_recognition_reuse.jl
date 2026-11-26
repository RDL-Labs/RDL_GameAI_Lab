# Diagnostic only: recompute every fit, compare immutable snapshots; never reuse results.
using JSON3
const RECOGNITION_AUDIT_COUNTS=Dict{String,Int}()
const RECOGNITION_AUDIT_SCOPES=Dict{String,Dict{String,Int}}()
const RECOGNITION_AUDIT_WINDOWS=Dict{String,Any}()
function recognition_audit_count!(scope,name)
    RECOGNITION_AUDIT_COUNTS[name]=get(RECOGNITION_AUDIT_COUNTS,name,0)+1
    c=get!(() -> Dict{String,Int}(),RECOGNITION_AUDIT_SCOPES,string(scope))
    c[name]=get(c,name,0)+1
end
function recognition_audit_call!(scope)
    OBS_PROFILE_WARM[] || recognition_audit_count!(scope,"correspondence_calls")
end
function recognition_audit_fit!(s,key,frame,node,fit,now,scope)
    OBS_PROFILE_WARM[] && return
    actor=string(s["actor"])
    window=get(RECOGNITION_AUDIT_WINDOWS,actor,nothing)
    if window===nothing || window.now!=now
        window=(now=now,pairs=Dict{Tuple{String,String},Any}())
        RECOGNITION_AUDIT_WINDOWS[actor]=window
    end
    recognition_audit_count!(scope,"fits")
    fit===nothing && recognition_audit_count!(scope,"unknown_fits")
    observed=hasproperty(frame,:features) ? frame.features : mb_features(frame.signature)
    memory=node["features"]
    metric=s["recognition"]["metric"]
    weights=metric["enabled"] ? Tuple(metric["weights"]) : (2.,1.)
    # All numerical inputs of mb_similarity, including feature contents and anchor.
    inputs=(signature=frame.signature,anchor=frame.anchor,observed=copy(observed),
        node_signature=node["signature"],memory=copy(memory),weights=weights)
    pair=(string(frame.key),string(key))
    previous=get(window.pairs,pair,nothing)
    if previous===nothing
        recognition_audit_count!(scope,"first_pair")
    else
        recognition_audit_count!(scope,"repeated_pair")
        if isequal(previous.inputs,inputs)
            recognition_audit_count!(scope,"identical_inputs")
            isequal(previous.fit,fit) || error("equal similarity inputs produced different result")
            recognition_audit_count!(scope,"identical_result")
            fit===nothing && recognition_audit_count!(scope,"reusable_unknown")
            previous.scope!=scope && recognition_audit_count!(scope,"cross_scope_repeat")
            recognition_audit_count!(string(previous.scope)*" -> "*string(scope),"reuse_transition")
        else
            recognition_audit_count!(scope,"changed_inputs")
        end
    end
    window.pairs[pair]=(inputs=inputs,fit=deepcopy(fit),scope=scope)
    nothing
end
const RECOGNITION_AUDIT_DRIVER=joinpath(@__DIR__,"profile_observation_day.jl")
recognition_audit_driver=read(RECOGNITION_AUDIT_DRIVER,String)
recognition_audit_anchor="include(joinpath(OBS_PROFILE_ROOT,\"source/integrations/lightweight_julia/native.jl\"))"
function recognition_audit_install!()
recognition_audit_file=joinpath(OBS_PROFILE_ROOT,"source/src/lw/learning/mb_recognition.jl")
recognition_audit_code=replace(read(recognition_audit_file,String),r"(?m)^include.*\r?\n"=>"")
recognition_audit_before="    frame=s[\"current\"];out=Any[]"
count(recognition_audit_before,recognition_audit_code)==1 || error("call anchor")
recognition_audit_code=replace(recognition_audit_code,recognition_audit_before=>"    Main.recognition_audit_call!(scope)\n"*recognition_audit_before)
recognition_audit_before="fit=mb_similarity(frame,node;metric=s[\"recognition\"][\"metric\"]);fit===nothing && continue"
count(recognition_audit_before,recognition_audit_code)==1 || error("fit anchor")
recognition_audit_code=replace(recognition_audit_code,recognition_audit_before=>"fit=mb_similarity(frame,node;metric=s[\"recognition\"][\"metric\"]);Main.recognition_audit_fit!(s,key,frame,node,fit,now,scope);fit===nothing && continue")
write(joinpath(OBS_PROFILE_OUT,"instrumented_recognition.jl"),recognition_audit_code)
Base.include_string(Main,recognition_audit_code,recognition_audit_file)
end
count(recognition_audit_anchor,recognition_audit_driver)==1 || error("driver anchor")
recognition_audit_driver=replace(recognition_audit_driver,recognition_audit_anchor=>recognition_audit_anchor*"\nrecognition_audit_install!()")
recognition_audit_driver=replace(recognition_audit_driver,"println(\"completed\");flush(stdout)"=>"write(joinpath(OBS_PROFILE_OUT,\"reuse-audit.json\"),JSON3.write((counts=RECOGNITION_AUDIT_COUNTS,scopes=RECOGNITION_AUDIT_SCOPES)))\nprintln(\"completed\");flush(stdout)")
# Keep sampling disabled: snapshots/counters are for work duplication, not speed comparison.
recognition_audit_driver=replace(recognition_audit_driver,"OBS_PROFILE_WARM[] || Profile.start_timer()"=>"nothing")
Base.include_string(Main,recognition_audit_driver,RECOGNITION_AUDIT_DRIVER)
cp(@__FILE__,joinpath(OBS_PROFILE_OUT,"reuse_runner.jl"))
