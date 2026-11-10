include("../../lw/configured_paths/rabbit_approach_parameters.jl")
include("../../lw/configured_paths/rabbit_cover_foraging.jl")
include("../../lw/configured_paths/rabbit_sparse_departure.jl")
include("../../lw/configured_paths/rabbit_local_rho_experiment.jl")
include("../../lw/configured_paths/rabbit_food_pressure_experiment.jl")
include("../../lw/configured_paths/rabbit_exponential_candidates.jl")
mutable struct RabbitApproachMemory
    H::Dict{Int,Float64}
    target::Int
    start_distance::Float64
    elapsed::Int
    forecast::Int
    rng::Xoshiro
    records::Vector{Any}
    local_rho::RabbitLocalRho
    food_pressure::RabbitFoodPressure
    food_gate::RabbitFoodPressureGate
end
RabbitApproachMemory(seed)=RabbitApproachMemory(Dict{Int,Float64}(),0,0.,0,0,Xoshiro(seed),Any[],RabbitLocalRho(),RabbitFoodPressure(),RabbitFoodPressureGate())
struct RabbitApproachPolicy
    actors::Dict{Int,RabbitApproachMemory}
    seed::Int
end
RabbitApproachPolicy(;seed=20261107)=RabbitApproachPolicy(Dict{Int,RabbitApproachMemory}(),seed)
choose_state(::RabbitApproachPolicy,o)=configured_rabbit_sparse_state(choose_state(StateMachinePolicy(),o),o)
approach_memory(policy,i)=get!(()->RabbitApproachMemory(policy.seed+i),policy.actors,i)
approach_feedback!(policy,w,a,i,t)=nothing
function approach_record!(m,row)
    push!(m.records,row)
    length(m.records)>RABBIT_APPROACH.history_limit && popfirst!(m.records)
end
function target!(w,a,i,t,policy::RabbitApproachPolicy)
    m=approach_memory(policy,i)
    # Reobserving or an action interruption must not reset the fixed forecast.
    if m.target!=0
        a.target[i]=m.target;a.next_sense[i]=t+RABBIT_APPROACH.minimum_ticks;return
    end
    parent_pressure=configured_rabbit_food_selection!(m,a,i,t,0.)
    radius=configured_food_search_radius(parent_pressure)
    observations=filter(!isnothing,observe_neighbors!(w,a,i,t;radius))
    isempty(observations) && (a.target[i]=0;return)
    pressure=maximum(get(m.H,o.cell,0.) for o in observations)
    pressure=configured_rabbit_food_selection!(m,a,i,t,pressure)
    chosen=if RABBIT_EXPONENTIAL_CANDIDATES.enabled
        configured_rabbit_candidate_choice(observations,a,i,m,pressure,RABBIT_APPROACH.temperature_scale)
    else
      scores=[o.grass+configured_rabbit_cover_bonus(o,a.energy[i])-.25o.distance+.2cos(o.direction-a.heading[i])-
          (o.cell==a.previous_cell[i] ? 1. : 0.)-get(m.H,o.cell,0.) for o in observations]
      if pressure==0
        argmax(scores)
      else
        weights=exp.((scores.-maximum(scores))./(1+pressure/RABBIT_APPROACH.temperature_scale))
        threshold=rand(m.rng)*sum(weights);index=length(weights)
        for j in eachindex(weights)
            threshold-=weights[j]
            if threshold<=0;index=j;break;end
        end
        index
      end
    end
    o=observations[chosen]
    if !haskey(m.H,o.cell) && length(m.H)>=RABBIT_APPROACH.memory_limit
        # Deterministic bounded memory: remove the smallest unresolved relation first.
        victim=first(sort!(collect(keys(m.H));by=k->(m.H[k],k)));delete!(m.H,victim)
    end
    get!(m.H,o.cell,0.)
    m.target=o.cell;m.start_distance=o.distance;m.elapsed=0
    m.forecast=max(RABBIT_APPROACH.minimum_ticks,ceil(Int,o.distance/RABBIT_APPROACH.speed))
    a.target[i]=o.cell;a.next_sense[i]=t+RABBIT_APPROACH.minimum_ticks
    approach_record!(m,(event="choice",tick=t,target=o.cell,H=m.H[o.cell],pressure=pressure,forecast=m.forecast,search_radius=radius,parent_H=m.food_pressure.H))
end
function approach_feedback!(policy::RabbitApproachPolicy,w,a,i,t)
    haskey(policy.actors,i) || return
    m=policy.actors[i]
    if a.state[i]==SEARCH
        configured_food_search_update!(m.food_pressure,a,i,t;search_tick=true)
        configured_food_pressure!(m.food_pressure,a,i,t)
    end
    m.target==0 && return
    a.state[i]==SEARCH || return # Other actions cannot credit or debit this approach.
    # Entering the selected cell is local movement success, not food/energy success.
    if cell(w,a.x[i],a.z[i])==m.target
        before=m.H[m.target];m.H[m.target]=0.
        approach_record!(m,(event="arrived",tick=t,target=m.target,H_before=before,H=0.))
        m.target=0;a.target[i]=0;return
    end
    m.elapsed+=1
    m.elapsed<m.forecast && return
    p=center(w,m.target);distance=hypot(a.x[i]-p[1],a.z[i]-p[2])
    expected=max(0.,m.start_distance-RABBIT_APPROACH.speed*m.elapsed)
    residual=max(0.,distance-expected-RABBIT_APPROACH.distance_band)/max(RABBIT_APPROACH.distance_band,m.start_distance)
    m.H[m.target]=min(RABBIT_APPROACH.H_limit,m.H[m.target]+residual)
    approach_record!(m,(event="forecast",tick=t,target=m.target,residual=residual,H=m.H[m.target],elapsed=m.elapsed,distance=distance))
    m.target=0;a.target[i]=0;a.next_sense[i]=t+1
end


