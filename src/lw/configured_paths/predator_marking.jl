# 暫定固定・動物単独実験 --marking のみ（既定OFF）。
# 地面の匂いは世界状態、memoryは各個体が実際に近距離で嗅いだ記憶。
# 自他の匂い識別、定期間隔、勾配選択は仮仕様。将来は観測/経験MBへ置換。
const PREDATOR_MARKING=(cell_size=4.,smell_radius=4.,lifetime_ticks=3*17280,
    mark_interval_ticks=600,sniff_interval_ticks=30,deposit=1.,capacity=4.,
    memory_limit=128,arrival_radius=3.,return_min_strength=.2,
    avoidance_margin=.1,local_familiarity=.5,speed=.22)
const ScentKey=Tuple{Int,Int,Int}
const ScentRecord=NamedTuple{(:strength,:tick,:x,:z),Tuple{Float64,Int,Float64,Float64}}
mutable struct PredatorScentWorld
    marks::Dict{ScentKey,ScentRecord}
    memory::Vector{Dict{ScentKey,ScentRecord}}
    observed::Vector{NamedTuple{(:own,:foreign,:away_x,:away_z),NTuple{4,Float64}}}
    deposits::Vector{Int}
    own_observations::Vector{Int}
    foreign_observations::Vector{Int}
end
PredatorScentWorld(n)=PredatorScentWorld(Dict{ScentKey,ScentRecord}(),
    [Dict{ScentKey,ScentRecord}() for _ in 1:n],
    [(own=0.,foreign=0.,away_x=0.,away_z=0.) for _ in 1:n],zeros(Int,n),zeros(Int,n),zeros(Int,n))
scent_strength(record,t)=record.strength*max(0.,1-(t-record.tick)/PREDATOR_MARKING.lifetime_ticks)
scent_cell(x,z)=(floor(Int,x/PREDATOR_MARKING.cell_size),floor(Int,z/PREDATOR_MARKING.cell_size))
function configured_scent_deposit!(scents,p,i,t)
    p.alive || return
    p.mode in (:rest,:hunt,:scent_return) || return
    body=p.visual.body
    body.state in (P.ATTACK,P.CHASE) && return
    cell=scent_cell(body.x,body.z);key=(cell...,i)
    previous=get(scents.marks,key,nothing)
    strength=previous===nothing ? 0. : scent_strength(previous,t)
    scents.marks[key]=(strength=min(PREDATOR_MARKING.capacity,strength+PREDATOR_MARKING.deposit),
        tick=t,x=body.x,z=body.z)
    scents.deposits[i]+=1
end
function configured_scent_observe!(scents,p,i,t)
    p.alive || return
    rule=PREDATOR_MARKING;body=p.visual.body;cx,cz=scent_cell(body.x,body.z)
    own=0.;foreign=0.;away_x=0.;away_z=0.
    # Only nearby cells are read, never a scan of the world's mark table.
    radius=ceil(Int,rule.smell_radius/rule.cell_size)
    for x in cx-radius:cx+radius,z in cz-radius:cz+radius,owner in eachindex(scents.memory)
        key=(x,z,owner);record=get(scents.marks,key,nothing)
        record===nothing && continue
        distance=hypot(body.x-record.x,body.z-record.z)
        distance<=rule.smell_radius || continue
        strength=scent_strength(record,t)
        if strength<=0
            delete!(scents.marks,key);delete!(scents.memory[i],key);continue
        end
        # Copy perceived strength: later unseen marking cannot update this memory.
        scents.memory[i][key]=(strength=strength,tick=t,x=record.x,z=record.z)
        signal=strength/(1+distance)
        if owner==i
            own=max(own,signal);scents.own_observations[i]+=1
        else
            foreign=max(foreign,signal);scents.foreign_observations[i]+=1
            away_x+=signal*(body.x-record.x)/max(distance,eps())
            away_z+=signal*(body.z-record.z)/max(distance,eps())
        end
    end
    while length(scents.memory[i])>rule.memory_limit
        oldest=first(sort!(collect(keys(scents.memory[i]));by=k->(scents.memory[i][k].tick,k)))
        delete!(scents.memory[i],oldest)
    end
    scents.observed[i]=(own=own,foreign=foreign,away_x=away_x,away_z=away_z)
end
function configured_scent_choice!(scents,p,i,t)
    p.alive || return
    body=p.visual.body;rule=PREDATOR_MARKING;observation=scents.observed[i]
    p.mode in (:rest,:hunt) || return
    # Never replace pursuit of an actually observed rabbit or an ongoing attack.
    body.state in (P.ATTACK,P.CHASE,P.RECOVER) && return
    if observation.foreign>observation.own+rule.avoidance_margin &&
        hypot(observation.away_x,observation.away_z)>0
        body.heading=atan(observation.away_z,observation.away_x);p.mode=:scent_avoid
        return
    end
    # Only fed animals return; hunger retains prey search.
    p.mode==:rest && observation.own<rule.local_familiarity || return
    target=nothing;best=0.
    for key in sort!(collect(keys(scents.memory[i])))
        key[3]==i || continue
        record=scents.memory[i][key];strength=scent_strength(record,t)
        distance=hypot(record.x-body.x,record.z-body.z)
        strength>=rule.return_min_strength && distance>rule.arrival_radius || continue
        score=strength/(1+distance)
        if score>best;best=score;target=record;end
    end
    target===nothing && return
    body.heading=atan(target.z-body.z,target.x-body.x);p.mode=:scent_return
end
function configured_scent_tick!(scents,predators,t)
    rule=PREDATOR_MARKING
    if t%rule.mark_interval_ticks==0
        # World maintenance only; this does not disclose far-away marks to actors.
        filter!(pair->scent_strength(last(pair),t)>0,scents.marks)
        for (i,p) in enumerate(predators);configured_scent_deposit!(scents,p,i,t);end
    end
    if t%rule.sniff_interval_ticks==0
        for (i,p) in enumerate(predators);configured_scent_observe!(scents,p,i,t);end
    end
end
scent_report(scents)=scents===nothing ? nothing :
    (world_records=length(scents.marks),memory_records=length.(scents.memory),
     deposits=copy(scents.deposits),own_observations=copy(scents.own_observations),
     foreign_observations=copy(scents.foreign_observations))
