# Local common receiver for ALL utterance types, not just free API speech.
# Caller loads trade_observation.jl. Context is perceived co-occurrence, not
# a true referent, speaker intention, favorable relationship or successful trade.
function observe_utterance_context(w,observer,yaw,event,now;attending=true,items=nothing,home=(0.,0.))
    heard=observe_trade_event(w,observer,yaw,event;attending)
    project_utterance_context(w,observer,yaw,event,now,heard;items,home)
end
function project_utterance_context(w,observer,yaw,event,now,heard;items=nothing,home=(0.,0.))
    (heard===nothing || isempty(strip(heard.text))) && return nothing
    sight=LW.social_sight(w,observer,yaw,now;illumination=1.)
    speaker=any(p->p["ref"]==event.actor,sight["peers"]) ? event.actor : nothing
    # Only currently visible objects, never own/peer warehouse contents.
    rows=items===nothing ? Any[] : LW.item_visible(items,w,home,observer,yaw,now;open_stores=false,illumination=1.)["visible"]
    objects=[Dict(k=>deepcopy(row[k]) for k in ("ref","color","size","light_source") if haskey(row,k)) for row in rows]
    forms=[JSON3.write((color=get(row,"color",nothing),size=get(row,"size",nothing),light_source=get(row,"light_source",nothing))) for row in objects]
    (id=String(event.id),us=now,text=String(heard.text),speaker=speaker,
        motion=hasproperty(heard,:motion) ? heard.motion : nothing,objects=objects,
        appearances=unique(vcat(hasproperty(heard,:appearances) ? String.(heard.appearances) : String[],forms)))
end

# Live bindings point at the simulation's existing per-owner dictionaries.
# Only the binding is transient; the actual MB is checkpointed in relations.
const UTTERANCE_LIVE_CONTEXT=Ref{Any}(nothing)
function bind_utterance_context!(relations,memories,items,home,now,yaw)
    UTTERANCE_LIVE_CONTEXT[]=(;relations,memories,items,home,now,yaw)
end
function receive_observed_utterance!(w,observer,yaw,event,heard)
    ctx=UTTERANCE_LIVE_CONTEXT[]
    (ctx===nothing || ctx.relations===nothing || !haskey(ctx.relations,observer)) && return heard
    observed=project_utterance_context(w,observer,yaw,event,ctx.now,heard;items=ctx.items,home=ctx.home)
    observed===nothing && return heard
    remember_utterance_context!(ctx.relations[observer],ctx.memories[observer].words,observed)
    # Preserve sensory-specific fields (strength, words_available, transfers).
    merge(heard,observed)
end

function remember_utterance_context!(relation,vocabulary,observed)
    observed===nothing && return false
    isempty(strip(observed.text)) && return false
    # Dictionary extension survives existing relation snapshots/serialization;
    # no schema change to ObservedVocabulary or TradeChannelObserver.
    mb=get!(() -> Dict{String,Any}("nodes"=>Dict{String,Any}(),"receipts"=>Dict{String,Any}()),relation,"utterance_mb")
    if haskey(mb["receipts"],observed.id)
        mb["receipts"][observed.id]==observed || error("conflicting utterance observation")
        return false
    end
    mb["receipts"][observed.id]=deepcopy(observed)
    key=JSON3.write((speaker=observed.speaker,text=observed.text))
    node=get!(() -> Dict{String,Any}("speaker"=>observed.speaker,"utterance"=>observed.text,
        "samples"=>0,"first_us"=>observed.us,"last_us"=>observed.us,"appearance_support"=>Dict{String,Float64}()),mb["nodes"],key)
    node["samples"]+=1;node["last_us"]=observed.us
    appearances=unique(observed.appearances)
    for appearance in appearances
        support=node["appearance_support"]
        support[appearance]=get(support,appearance,0.)+1/length(appearances)
    end
    # Same associative vocabulary machinery for proposals, replies, calls, free
    # speech. Japanese unsegmented sentences remain whole tokens for now.
    learn_observed_words!(vocabulary,observed)
    true
end

function receive_utterance_context!(relation,vocabulary,w,observer,yaw,event,now;kwargs...)
    observed=observe_utterance_context(w,observer,yaw,event,now;kwargs...)
    remember_utterance_context!(relation,vocabulary,observed)
    observed
end
