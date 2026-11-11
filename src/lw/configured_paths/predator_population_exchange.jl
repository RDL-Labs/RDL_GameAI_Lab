# 暫定固定の世界境界条件。通常はOFF、crossing_longrunの第15引数ratioで有効。
# 世界の生存兎数を直接数え、初回100匹・以後50匹刻み、退場は50匹下で日次調整。
# 個体の判断ではない。境界への歩行・場外生態は省略し、出入りを瞬時に扱う。
# 将来は外部個体群と、局所の狩り収支による移住判断へ置換する。
const PREDATOR_POPULATION_EXCHANGE=(first_arrival_rabbits=100,rabbits_per_predator=50,departure_margin=50,
    interval_ticks=PREDATOR_ANIMAL_TRIAL.day_ticks,seed=20261109)
mutable struct PredatorPopulationExchange
    present::BitVector
    events::Vector{Any}
    last_tick::Int
    rng::MersenneTwister
end
PredatorPopulationExchange(n)=PredatorPopulationExchange(trues(n),Any[],-1,
    MersenneTwister(PREDATOR_POPULATION_EXCHANGE.seed))
function configured_predator_population_target(rabbits,residents=0)
    rule=PREDATOR_POPULATION_EXCHANGE
    arrival_target=max(0,1+fld(rabbits-rule.first_arrival_rabbits,rule.rabbits_per_predator))
    # Equality departs: k leaves at N <= first+(k-1)*step-margin. Between thresholds
    # retain existing residents; do not replace a dead resident below arrival N.
    retention_limit=max(0,cld(rabbits-rule.first_arrival_rabbits+rule.departure_margin,rule.rabbits_per_predator))
    max(arrival_target,min(residents,retention_limit))
end
function configured_predator_boundary_position(world,rng)
    # Only the world's edge geometry is used, never prey positions or food density.
    boundary_cells=[k for k in eachindex(world.walkable) if world.walkable[k] &&
        (mod(k-1,world.nx) in (0,world.nx-1) || div(k-1,world.nx) in (0,world.nz-1)) &&
        H.clear(world,H.center(world,k),H.center(world,k))]
    isempty(boundary_cells) && return nothing
    H.center(world,rand(rng,boundary_cells))
end
function configured_predator_population_arrive!(world_state,cohort,migration,t;crossing_enabled=true)
    position=configured_predator_boundary_position(world_state.world,migration.rng)
    position===nothing && return nothing
    actor=length(cohort.predators)+1 # Never reuse IDs: scent owners/capture history remain valid.
    predator=configured_trial_predator(world_state,position,rand(migration.rng,1:typemax(Int32)))
    mind=PredatorMind(actor)
    mind.estimates["crossing_enabled"]=crossing_enabled ? 1. : 0.
    push!(cohort.predators,predator);push!(cohort.minds,mind)
    push!(cohort.local_hunts,LocalHunt(actor;probabilistic_capture=true))
    push!(cohort.pursuits,PredatorPursuit(actor));push!(cohort.physiology,PredatorPhysiology(predator))
    scent_slot=PredatorScentWorld(1)
    for field in (:memory,:observed,:deposits,:own_observations,:foreign_observations)
        append!(getproperty(cohort.scents,field),getproperty(scent_slot,field))
    end
    prey_slot=PreyScentWorld(1;cautious=cohort.prey_scents.cautious)
    for field in (:observed,:caution_ticks,:unconfirmed,:cooldown,:active_target)
        append!(getproperty(cohort.prey_scents,field),getproperty(prey_slot,field))
    end
    push!(migration.present,true)
    push!(migration.events,(event="immigration",tick=t,actor,position,
        rabbits=count(world_state.alive),memory="fresh",food=predator.food))
    actor
end
function configured_predator_population_update!(world_state,cohort,migration,t;crossing_enabled=true)
    t%PREDATOR_POPULATION_EXCHANGE.interval_ticks == 0 || return
    t==migration.last_tick && return # Idempotent at checkpoint/resume boundaries.
    migration.last_tick=t
    residents=[i for i in eachindex(cohort.predators) if migration.present[i] && cohort.predators[i].alive]
    target=configured_predator_population_target(count(world_state.alive),length(residents))
    # Excess residents closest to an edge leave first. This is a world shortcut,
    # not learned migration; original bodies/MB/capture totals remain archived.
    edge_distance(i)=begin
        body=cohort.predators[i].visual.body;world=world_state.world
        min(body.x-world.xmin,world.xmax-body.x,body.z-world.zmin,world.zmax-body.z)
    end
    sort!(residents;by=i->(edge_distance(i),i))
    for actor in Iterators.take(residents,max(0,length(residents)-target))
        predator=cohort.predators[actor];migration.present[actor]=false
        # End the local episode without claiming capture/death or adding failure H.
        mind=cohort.minds[actor]
        mind.trial!==nothing && LW.action_trial_close!(mind.trial,"interrupted",LW.D("reason"=>"emigration"))
        configured_local_wait_close!(cohort.local_hunts[actor],"interrupted","emigration")
        configured_pursuit_close!(cohort.pursuits[actor],t,"emigration")
        push!(migration.events,(event="emigration",tick=t,actor,
            position=(predator.visual.body.x,predator.visual.body.z),
            rabbits=count(world_state.alive),food=predator.food))
    end
    for _ in 1:max(0,target-length(residents))
        configured_predator_population_arrive!(world_state,cohort,migration,t;crossing_enabled)===nothing && break
    end
end
function configured_predator_population_report(cohort,migration,rabbits)
    residents=count(i->migration.present[i] && cohort.predators[i].alive,eachindex(cohort.predators))
    (target=configured_predator_population_target(rabbits,residents),residents,
     deaths=count(i->migration.present[i] && !cohort.predators[i].alive,eachindex(cohort.predators)),
     arrivals=count(e->e.event=="immigration",migration.events),
     departures=count(!,migration.present),
     status=[!migration.present[i] ? "outside" : p.alive ? "resident" : "dead" for (i,p) in enumerate(cohort.predators)])
end

# 暫定固定・replace実験専用: 死亡後、次の日次境界で外部個体を補充。
# 生存個体数は指定数に維持し、兎数を条件にしない。既存の新規ID・境界配置を共用。
# 学習済み個体の復活ではない。将来は外部個体群・移住判断へ置換。
function configured_predator_replacement_update!(world_state,cohort,migration,t;crossing_enabled=true,target=1)
    t%PREDATOR_POPULATION_EXCHANGE.interval_ticks==0 && t!=migration.last_tick || return
    migration.last_tick=t
    for actor in eachindex(cohort.predators)
        p=cohort.predators[actor]
        migration.present[actor] && !p.alive || continue
        any(e->e.event=="replacement_death" && e.actor==actor,migration.events) && continue
        push!(migration.events,(event="replacement_death",tick=t,actor=actor,
            position=(p.visual.body.x,p.visual.body.z),food=p.food,captures=p.visual.body.captures,
            mode=string(p.mode),body=predator_physiology_report(cohort.physiology[actor])))
    end
    residents=count(i->migration.present[i] && cohort.predators[i].alive,eachindex(cohort.predators))
    for _ in 1:max(0,target-residents)
        configured_predator_population_arrive!(world_state,cohort,migration,t;crossing_enabled)===nothing && break
    end
end
