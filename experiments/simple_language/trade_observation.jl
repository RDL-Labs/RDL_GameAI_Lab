# Local-only public-event projection. Not loaded by the normal LW life loop.
# Food appearances are provisional observable categories, not dictionary meanings.
const TRADE_OBSERVATION = (hearing_radius=8., minimum_samples=2., minimum_share=.7)
mutable struct ObservedVocabulary
    evidence::Dict{String,Dict{String,Float64}}
    seen::Set{String}
end
ObservedVocabulary()=ObservedVocabulary(Dict{String,Dict{String,Float64}}(),Set{String}())

function observe_trade_event(w,observer,yaw,event;attending=true)
    attending || return nothing
    # Existing visual geometry supplies occlusion/FOV. No private trade terms,
    # inventory, valuation, acceptance flag or speaker dictionary cross this boundary.
    sight=LW.social_sight(w,observer,yaw,0;illumination=1.)
    visible=Set(p["ref"] for p in sight["peers"])
    origin=w.positions[event.actor];position=w.positions[observer]
    heard=w.hearing[observer] && hypot(origin[1]-position[1],origin[2]-position[2])<=TRADE_OBSERVATION.hearing_radius
    seen=event.actor in visible
    (!heard && !seen) && return nothing
    (id=event.id,text=heard ? event.text : "",motion=seen ? event.motion : nothing,
     appearances=seen ? copy(event.appearances) : String[])
end

function learn_observed_words!(memory,observation)
    observation===nothing && return false
    observation.id in memory.seen && return false
    push!(memory.seen,observation.id)
    # Each utterance contributes one unit, divided across plausible visible objects.
    # Ambiguity is retained; no correct referent or food-kind label is supplied.
    appearances=unique(observation.appearances)
    isempty(appearances) && return false
    for word in unique(split(observation.text))
        evidence=get!(()->Dict{String,Float64}(),memory.evidence,String(word))
        for appearance in appearances
            evidence[appearance]=get(evidence,appearance,0.)+1/length(appearances)
        end
    end
    !isempty(observation.text)
end

function observed_word_prediction(memory,word)
    evidence=get(memory.evidence,word,Dict{String,Float64}())
    isempty(evidence) && return (status="unknown",appearance=nothing,share=0.,samples=0.)
    ordered=sort(collect(evidence);by=p->(-p.second,p.first))
    samples=sum(values(evidence));share=first(ordered).second/samples
    resolved=samples>=TRADE_OBSERVATION.minimum_samples && share>=TRADE_OBSERVATION.minimum_share
    (status=resolved ? "provisional" : "ambiguous",appearance=resolved ? first(ordered).first : nothing,share=share,samples=samples)
end
