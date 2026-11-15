# Local proposal probe only: never included by LW or its normal life loop.
# Fixed initial vocabulary and response decisions are test scaffolding, not learned aid.
using Unicode
const LOCAL_LANGUAGE=(max_chars=64,reply_seconds=5.)
mutable struct LocalLexicon
    names::Dict{String,Vector{Int}}
end
LocalLexicon()=LocalLexicon(Dict{String,Vector{Int}}())
function local_seed!(lex,name,kind)
    lex.names[Unicode.normalize(name,:NFC)]=[Int(kind)]
end
function local_interpret(lex,expression)
    length(expression)<=LOCAL_LANGUAGE.max_chars || return (status=:too_long,kind=nothing)
    text=Unicode.normalize(strip(expression),:NFC)
    text=="どうぞ" && return (status=:give_marker,kind=nothing)
    text=="いや" && return (status=:refuse,kind=nothing)
    suffix="、ちょうだい"
    endswith(text,suffix) || return (status=:unknown_form,kind=nothing)
    name=chop(text;tail=length(suffix))
    candidates=get(lex.names,name,Int[])
    isempty(candidates) && return (status=:unknown_name,kind=nothing)
    length(candidates)==1 || return (status=:unresolved_referent,kind=nothing)
    (status=:request,kind=only(candidates))
end
# Fixture delivery uses the existing contact/hearing checks. No hidden request tag.
function local_receive(w,sender,receiver,id,expression)
    LW.contact(w,sender,receiver) && w.hearing[receiver] || return nothing
    (id=id,sender=sender,receiver=receiver,expression=expression,received=w.seconds)
end
# Fixed response is explicitly supplied by the test; no autonomous social policy here.
# Re-resolve current inventory before mutating; receipt contains the actual item.
function local_answer!(receipts,lex,obs,w,r,cargo;accept)
    obs===nothing && return (status=:unobserved,)
    key=(obs.receiver,obs.id)
    if haskey(receipts,key)
        prior,result=receipts[key]
        prior==obs || error("conflicting utterance ID")
        return result
    end
    interpretation=local_interpret(lex,obs.expression)
    result=if interpretation.status!=:request
        (status=interpretation.status,)
    elseif w.seconds-obs.received>LOCAL_LANGUAGE.reply_seconds
        (status=:expired,)
    elseif !accept
        (status=:declined,)
    elseif !LW.contact(w,obs.sender,obs.receiver)
        (status=:out_of_contact,)
    else
        giver=obs.receiver;receiver=obs.sender
        index=findfirst(==(interpretation.kind),r.inventory[giver])
        if index===nothing
            (status=:unavailable,)
        else
            length(cargo[giver])==length(r.inventory[giver])==w.inventory[giver] || error("giver inventory mismatch")
            length(cargo[receiver])==length(r.inventory[receiver])==w.inventory[receiver] || error("receiver inventory mismatch")
            kind=Int(r.inventory[giver][index]);quality=LW.food_quality(r,giver,index)
            deadline=LW.food_inventory_deadline(r,giver,index)
            if deadline<=r.game.expiry_day
                (status=:expired_food,)
            else
                LW.food_give!(r,giver,receiver,index)
                push!(cargo[receiver],popat!(cargo[giver],index))
                w.inventory[giver]-=1;w.inventory[receiver]+=1
                (status=:transferred,kind=kind,quality=quality,deadline=deadline)
            end
        end
    end
    receipts[key]=(obs,result)
    result
end
