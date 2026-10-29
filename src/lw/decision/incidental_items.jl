# A small observer-owned child loop for an optional, in-reach pickup. The weak
# novelty value below is an INITIAL prior, not learned usefulness, food value,
# another actor's preference, or a claim that an object should be collected.
const INCIDENTAL_ITEM_MEMORY_LIMIT=128
const INCIDENTAL_ITEM_RECORD_LIMIT=64
const INCIDENTAL_ITEM_NOVELTY_PRIOR=.2
const INCIDENTAL_ITEM_REACH=1.25

function incidental_item_state(actor,seed=0)
    D("actor"=>String(actor),
      "loop"=>BasicLoop("$actor:incidental-items";parent="$actor:activity",probabilistic=true,seed),
      "metric"=>mb_metric_state(),"memory"=>D(),"handled_refs"=>Int[],
      "records"=>Any[],"decisions"=>0,"continued"=>0,"selected"=>0,
      "succeeded"=>0,"failed"=>0,"ignored"=>0)
end

incidental_body(body,name,default)=body isa AbstractDict ? get(body,name,default) :
    hasproperty(body,Symbol(name)) ? getproperty(body,Symbol(name)) : default
incidental_finite(x)=x isa Real && !(x isa Bool) && isfinite(x)

function incidental_item_feature(row)
    color=get(row,"color",nothing);size=get(row,"size",nothing);light=get(row,"light_source",nothing)
    (color isa AbstractString && incidental_finite(size) && size>0 &&
        incidental_finite(light) && light>=0) || return nothing
    D("color"=>String(color),"size"=>Float64(size),"light_source"=>Float64(light))
end

# The key only bounds storage and binds a reusable method. Retrieval below uses
# continuous similarities; neither the world's kind nor its object ID is a key.
incidental_item_key(f)="pickup:$(repr(f["color"])):$(floor(Int,4log1p(f["size"]))):$(floor(Int,4log1p(f["light_source"])))"
function incidental_item_parts(a,b)
    (a["color"]==b["color"] ? 0. : 1.,
     (abs(log(a["size"]/b["size"]))+abs(log1p(a["light_source"])-log1p(b["light_source"])))/2)
end
function incidental_item_fit(state,a,b)
    p=incidental_item_parts(a,b);w=state["metric"]["weights"]
    exp(-w[1]*p[1]-w[2]*p[2])
end

function incidental_item_prediction(state,feature,context,H)
    memory=collect(values(state["memory"]))
    sort!(memory;by=m->(-incidental_item_fit(state,feature,m["feature"]),m["method"]))
    # H expands the number of recalled relations, not the number of world rows
    # silently examined. Counts inside a prototype retain repeated experience.
    budget=min(8,mb_retrieval_budget(H));familiarity=0.;successes=0.;attempts=0.;cost=0.
    for m in Iterators.take(memory,budget)
        fit=incidental_item_fit(state,feature,m["feature"])
        familiarity+=fit*m["successes"]
        c=m["context"]
        situation=exp(-4abs(context["load_fraction"]-c["load_fraction"])-
            abs(log(context["capacity_mass"]/c["capacity_mass"]))-
            abs(log(context["capacity_size"]/c["capacity_size"])))
        weight=fit*situation
        successes+=weight*m["successes"];attempts+=weight*m["attempts"]
        cost+=weight*m["cost_total"]
    end
    novelty=INCIDENTAL_ITEM_NOVELTY_PRIOR/(1+familiarity)
    # The unknown pickup outcome has a weak symmetric prior. A visible size is
    # known, but mass remains unknown until the world accepts/rejects the act.
    probability=(1+successes)/(2+attempts)
    effort=(.002+cost)/(1+attempts)
    (novelty=novelty,probability=probability,effort=effort,
        expected=novelty*probability-effort,familiarity=familiarity,budget=budget)
end

"Read-only candidates from this observer's current item view and own body."
function incidental_item_candidates(state,view,body,parent_loop;family,pressure=0.)
    view===nothing && return Any[]
    check(incidental_finite(pressure) && pressure>=0,"incidental_pressure")
    reserve=Float64(incidental_body(body,"reserve",100.))
    strain=Float64(incidental_body(body,"strain",0.));damage=Float64(incidental_body(body,"damage",0.))
    (reserve>0 && strain<1 && damage<1) || return Any[]
    capacity=get(view,"carry_capacity",nothing);load=get(view,"own_load",nothing)
    (capacity isa AbstractDict && load isa AbstractDict) || return Any[]
    mass=get(capacity,"mass",nothing);size=get(capacity,"size",nothing);held=get(load,"mass",nothing)
    all(incidental_finite,(mass,size,held)) || return Any[]
    (mass>0 && size>0 && held>=0 && held<mass) || return Any[]
    context=D("load_fraction"=>Float64(held/mass),"capacity_mass"=>Float64(mass),"capacity_size"=>Float64(size))
    candidates=D();H=max(state["loop"].H,parent_loop.H)
    for row in get(view,"visible",Any[])
        # A ref is only an executor address and a bounded receipt against picking
        # up the same handled object again for fresh novelty. It supplies no value.
        ref=get(row,"ref",nothing);distance=get(row,"distance",nothing)
        (ref isa Integer && !(ref isa Bool) && ref>0 && incidental_finite(distance) &&
            0<=distance<=INCIDENTAL_ITEM_REACH && get(row,"location",nothing)==Int(ITEM_GROUND) &&
            get(row,"holder",nothing)===nothing && !(ref in state["handled_refs"])) || continue
        feature=incidental_item_feature(row);feature===nothing && continue
        feature["size"]<=size || continue
        method=incidental_item_key(feature)
        previous=get(candidates,method,nothing)
        # Visibly equivalent opportunities are one method, with the nearest
        # current executor binding. This is not an object-identity classifier.
        previous!==nothing && previous["observed_distance"]<=distance && continue
        prediction=incidental_item_prediction(state,feature,context,H)
        candidates[method]=D("method"=>method,"action"=>"item_pickup","priority"=>2prediction.expected,
            "question"=>"observed_pickup_interest_confirmed","incidental_item"=>true,
            "portable_item_action"=>true,"item_id"=>Int(ref),"family"=>String(family),"purpose_family"=>String(family),
            "feature"=>feature,"context"=>copy(context),"observed_distance"=>Float64(distance),
            "expected_benefit"=>prediction.expected,"confirmed_novelty"=>prediction.novelty,
            "predicted_success"=>prediction.probability,"predicted_effort"=>prediction.effort,
            "familiarity"=>prediction.familiarity,"retrieval_budget"=>prediction.budget,
            "interest_source"=>"initial_observable_novelty_prior")
    end
    isempty(candidates) && return Any[]
    pickups=sort!(collect(values(candidates));by=c->(-c["expected_benefit"],c["observed_distance"],c["method"]))
    length(pickups)>8 && resize!(pickups,8)
    urgency=max(Float64(pressure),clamp((80-reserve)/80,0.,1.),clamp(strain,0.,1.),clamp(damage,0.,1.))
    parent_method=parent_loop.last_method===nothing ? nothing : get(parent_loop.methods,parent_loop.last_method,nothing)
    continuation=parent_method===nothing ? 0. : clamp(log1p(parent_method.reward)-failure_repulsion(parent_method),0.,2.)
    result=Any[D("method"=>"continue_activity","action"=>"continue","priority"=>2.0+continuation,
        "observation_log_prior"=>4urgency,"question"=>"continue_parent_activity","incidental_continue"=>true)]
    for candidate in pickups
        # More clutter does not manufacture a stronger aggregate attraction.
        candidate["observation_log_prior"]=log(candidate["confirmed_novelty"]/INCIDENTAL_ITEM_NOVELTY_PRIOR)-log(length(pickups))
        push!(result,candidate)
    end
    result
end

function incidental_item_bound_methods!(state,candidates)
    loop=state["loop"];keep=Set(String(c["method"]) for c in candidates)
    # choose_method! admits all candidate methods. Leave room before it does so.
    absent=count(name->!haskey(loop.methods,name),keep)
    while length(loop.methods)+absent>INCIDENTAL_ITEM_MEMORY_LIMIT+1
        removable=filter(name->!(name in keep) && name!="continue_activity",collect(keys(loop.methods)))
        isempty(removable) && break
        sort!(removable;by=name->(loop.methods[name].last_selected,name))
        delete!(loop.methods,first(removable))
    end
end

function incidental_item_plan!(state,view,body,parent_loop,now;family,pressure=0.)
    candidates=incidental_item_candidates(state,view,body,parent_loop;family,pressure)
    isempty(candidates) && return nothing # no RNG, memory, sequence or H mutation
    loop=state["loop"];check(loop.trial===nothing,"incidental_active_trial")
    incidental_item_bound_methods!(state,candidates)
    source="incidental:$now:$(state["actor"]):$(loop.sequence+1)"
    plan=choose_method!(loop,candidates,source);state["decisions"]+=1
    if get(plan,"incidental_continue",false)
        state["continued"]+=1
        resolve_method!(loop,source,nothing,nothing;creditable=false,goal_H_increment=0.)
        return nothing
    end
    state["selected"]+=1;plan["incidental_source"]=source
    plan
end

function incidental_item_result!(state,plan,status,energy,now)
    check(get(plan,"incidental_item",false),"incidental_result_plan")
    check(incidental_finite(energy) && energy>=0,"incidental_energy")
    source=plan["incidental_source"];success=status=="item_picked_up"
    # Unknown/unexecuted callbacks carry no failure evidence. Physical refusal
    # from the item executor is an observed result and can revise the forecast.
    executed=success || status in ("item_unavailable","item_failed","item_rejected")
    actual=executed ? (success ? plan["confirmed_novelty"] : 0.)-Float64(energy) : nothing
    resolve_prediction!(state["loop"],source,plan["expected_benefit"],actual;
        executed,observed=executed,fulfilled=success) || return false
    if !executed
        state["ignored"]+=1
        return true
    end
    method=plan["method"];feature=plan["feature"];context=plan["context"]
    # The shared metric learns similarity of pickup affordance only from
    # executed outcomes under comparable known carrying conditions. It is not
    # trained by our own learned similarity or a hidden identity/kind label.
    compared=0
    for previous in sort!(collect(values(state["memory"]));by=m->(-m["last_us"],m["method"]))
        c=previous["context"]
        (abs(context["load_fraction"]-c["load_fraction"])<=.1 &&
            abs(log(context["capacity_mass"]/c["capacity_mass"]))<=.1 &&
            abs(log(context["capacity_size"]/c["capacity_size"]))<=.1) || continue
        mb_metric_update!(state["metric"],[incidental_item_parts(feature,previous["feature"])],
            success==previous["last_success"] ? 1. : 0.,source)
        compared+=1;compared>=8 && break
    end
    memory=state["memory"]
    if !haskey(memory,method)
        if length(memory)>=INCIDENTAL_ITEM_MEMORY_LIMIT
            oldest=first(sort!(collect(keys(memory));by=k->(memory[k]["last_us"],k)))
            delete!(memory,oldest)
        end
        memory[method]=D("method"=>method,"feature"=>copy(feature),"context"=>copy(context),
            "attempts"=>0,"successes"=>0,"cost_total"=>0.,"last_success"=>success,"last_us"=>now)
    end
    record=memory[method];record["attempts"]+=1;record["successes"]+=Int(success)
    record["cost_total"]+=Float64(energy);record["last_success"]=success;record["last_us"]=now
    record["context"]=copy(context)
    state[success ? "succeeded" : "failed"]+=1
    if success
        push!(state["handled_refs"],plan["item_id"])
        length(state["handled_refs"])>INCIDENTAL_ITEM_MEMORY_LIMIT && popfirst!(state["handled_refs"])
    end
    push!(state["records"],D("source"=>source,"us"=>now,"method"=>method,"item_id"=>plan["item_id"],
        "status"=>status,"family"=>plan["family"],"feature"=>copy(feature),
        "expected"=>plan["expected_benefit"],"actual"=>actual,"energy"=>Float64(energy),
        "confirmed_novelty"=>plan["confirmed_novelty"],"selection_probability"=>get(plan,"selection_probability",nothing)))
    length(state["records"])>INCIDENTAL_ITEM_RECORD_LIMIT && popfirst!(state["records"])
    true
end

function incidental_item_snapshot(state)
    D("actor"=>state["actor"],"loop"=>loop_snapshot(state["loop"]),
      "metric"=>deepcopy(state["metric"]),"memory"=>deepcopy(state["memory"]),
      "handled_refs"=>copy(state["handled_refs"]),"records"=>deepcopy(state["records"]),
      (name=>state[name] for name in ("decisions","continued","selected","succeeded","failed","ignored"))...)
end
