# Simplified rabbit-like world physiology, not a fitted demographic model.
# Days are LW days (17280 ticks); gestation/weaning approximate rabbits.
const RABBIT_LIFE=(day_ticks=17280, gestation_days=31, wean_days=28,
    maturity_days=150, initial_age_days=180, year_days=365, season_days=240,
    receptive_days=14, receptivity_period=16, mate_radius=6., conception_chance=.2,
    breeding_energy=70., recovery_days=7, litter_min=3, litter_max=6,
    pregnancy_energy_per_day=1., infant_energy_per_day=4., milk_target=8.,
    milk_efficiency=.75, maternal_reserve=35., nurse_distance=1.5,
    infant_height=.1, adult_height=.4, allocation_limit=10000)

mutable struct RabbitLife
    rng::MersenneTwister
    sex::Vector{UInt8}
    born::Vector{Int}
    mother::Vector{Int}
    due::Vector{Int}
    litter::Vector{Int}
    invested::Vector{Float64}
    next_mate::Vector{Int}
    receptive_phase::Vector{Int}
    nursed_day::Vector{Int}
    nest::Vector{Tuple{Float64,Float64}}
    moving::BitVector
    initial_count::Int
    conceptions::Int
    births::Int
    litters::Int
    lost_pregnancies::Int
    milk_out::Float64
    milk_in::Float64
    gestation_out::Float64
    newborn_energy::Float64
    lost_investment::Float64
    nursing_visits::Int
    nest_return_ticks::Int
end
function rabbit_life(n,seed,positions;initial_pregnancy_days=Int[])
    rng=MersenneTwister(seed)
    # Balanced founding cohort is a world fixture, not a promise of offspring.
    sexes=UInt8[isodd(i) ? 1 : 2 for i in 1:n];shuffle!(rng,sexes)
    life=RabbitLife(rng,sexes,fill(-RABBIT_LIFE.initial_age_days*RABBIT_LIFE.day_ticks,n),
        zeros(Int,n),zeros(Int,n),zeros(Int,n),zeros(n),zeros(Int,n),
        rand(rng,0:RABBIT_LIFE.receptivity_period-1,n),fill(-1,n),copy(positions),trues(n),
        n,0,0,0,0,0.,0.,0.,0.,0.,0,0)
    females=findall(==(1),sexes)
    length(initial_pregnancy_days)<=length(females) || error("too many initial rabbit pregnancies")
    for (slot,elapsed) in enumerate(initial_pregnancy_days)
        elapsed isa Integer && !(elapsed isa Bool) && 0<elapsed<RABBIT_LIFE.gestation_days || error("initial pregnancy age must be integer days in 1..30")
        mother=females[slot]
        life.due[mother]=(RABBIT_LIFE.gestation_days-elapsed)*RABBIT_LIFE.day_ticks
        life.litter[mother]=rand(rng,RABBIT_LIFE.litter_min:RABBIT_LIFE.litter_max)
        # World initial condition: paid before tick zero, not free energy generated
        # during this run. Existing gestation ledger includes this explicit history.
        life.invested[mother]=elapsed*RABBIT_LIFE.pregnancy_energy_per_day
        life.gestation_out+=life.invested[mother]
        life.conceptions+=1
    end
    life
end
dependent(life,i,t)=t-life.born[i]<RABBIT_LIFE.wean_days*RABBIT_LIFE.day_ticks
rabbit_height(s,i)=s.life===nothing ? RABBIT_LIFE.adult_height :
    RABBIT_LIFE.infant_height+(RABBIT_LIFE.adult_height-RABBIT_LIFE.infant_height)*
    clamp((s.ticks-s.life.born[i])/(RABBIT_LIFE.maturity_days*RABBIT_LIFE.day_ticks),0.,1.)
function rabbit_visibility(s,i)
    configured_rabbit_in_burrow(s,i,s.ticks) && return 0.
    s.life===nothing && return 1.
    height=rabbit_height(s,i)
    cover=H.grass_cover!(s.world,H.cell(s.world,s.animals.x[i],s.animals.z[i]),s.ticks;body_height=height)
    (height/RABBIT_LIFE.adult_height)/(1+cover)
end

function rabbit_birth!(s,mother,t;initial=false)
    life=s.life;a=s.animals;n=life.litter[mother]
    length(s.alive)+n<=RABBIT_LIFE.allocation_limit || error("rabbit allocation safety stop: population limit; births not silently suppressed")
    position=(a.x[mother],a.z[mother]);energy=initial ? RABBIT_LIFE.milk_target : life.invested[mother]/n
    for _ in 1:n
        for (field,value) in ((:x,position[1]),(:z,position[2]),(:heading,0.),(:energy,energy),
            (:gut,0.),(:sleepy,0.),(:state,H.SLEEP),(:previous_cell,0),(:current_cell,H.cell(s.world,position...)),
            (:target,0),(:next_sense,t),(:distance,0.),(:consumed,0.),(:digested,0.),(:starvation_ticks,0),(:blocked,0))
            push!(getfield(a,field),value)
        end
        for (field,value) in ((:alive,true),(:gaze,0.),(:last_seen,-1000),(:seen_actor,0),(:seen_position,position),
            (:flee_until,-1000),(:calm_since,-1000),(:overrides,0),(:threats,position),(:requests,0.),
            (:seen_ticks,0),(:alert_entries,0),(:flee_entries,0),(:initial_positions,position))
            push!(getfield(s,field),value)
        end
        for (field,value) in ((:sex,rand(life.rng,UInt8[1,2])),(:born,t),(:mother,mother),(:due,0),
            (:litter,0),(:invested,0.),(:next_mate,0),(:receptive_phase,rand(life.rng,0:RABBIT_LIFE.receptivity_period-1)),
            (:nursed_day,div(t,RABBIT_LIFE.day_ticks)),(:nest,position),(:moving,false))
            push!(getfield(life,field),value)
        end
    end
    a.counts=vcat(a.counts,zeros(Int,n,size(a.counts,2)))
    if initial
        life.initial_count+=n # Initial inventory, not births or milk produced in this run.
    else
        life.births+=n;life.litters+=1;life.newborn_energy+=life.invested[mother]
    end
    life.invested[mother]=0.;life.due[mother]=0;life.litter[mother]=0
    life.next_mate[mother]=t+(RABBIT_LIFE.wean_days+RABBIT_LIFE.recovery_days)*RABBIT_LIFE.day_ticks
end

# World initial condition only. Existing nonpregnant mother and dependent offspring
# start at the same nest. No new fixed decision: normal nursing/weaning rules apply.
function rabbit_initial_young!(s,young_count,age_days)
    young_count==0 && return s
    life=s.life
    life===nothing && error("initial young require reproduction")
    age_days isa Integer && !(age_days isa Bool) && 0<age_days<RABBIT_LIFE.wean_days || error("initial young age must be integer days before weaning")
    mother=findfirst(i->life.sex[i]==1 && life.due[i]==0,eachindex(life.sex))
    mother===nothing && error("initial young require a nonpregnant mother")
    life.litter[mother]=young_count
    rabbit_birth!(s,mother,-age_days*RABBIT_LIFE.day_ticks;initial=true)
    s
end

function rabbit_daily!(s,t)
    life=s.life;a=s.animals;day=div(t,RABBIT_LIFE.day_ticks)
    for i in eachindex(life.due)
        life.due[i]>0 || continue
        if !s.alive[i]
            life.lost_investment+=life.invested[i];life.invested[i]=0.;life.due[i]=0;life.litter[i]=0
            life.lost_pregnancies+=1;continue
        end
        paid=min(a.energy[i],RABBIT_LIFE.pregnancy_energy_per_day)
        a.energy[i]-=paid;life.invested[i]+=paid;life.gestation_out+=paid
        if a.energy[i]<=0
            s.alive[i]=false;s.deaths+=1
            life.lost_investment+=life.invested[i];life.invested[i]=0.;life.due[i]=0;life.litter[i]=0
            life.lost_pregnancies+=1
        elseif t>=life.due[i]
            rabbit_birth!(s,i,t)
        end
    end
    mod(day,RABBIT_LIFE.year_days)<RABBIT_LIFE.season_days || return
    radius=RABBIT_LIFE.mate_radius
    bins=Dict{Tuple{Int,Int},Vector{Int}}()
    for i in eachindex(s.alive)
        s.alive[i] && life.sex[i]==2 && t-life.born[i]>=RABBIT_LIFE.maturity_days*RABBIT_LIFE.day_ticks || continue
        push!(get!(()->Int[],bins,(floor(Int,a.x[i]/radius),floor(Int,a.z[i]/radius))),i)
    end
    for i in eachindex(s.alive)
        s.alive[i] && life.sex[i]==1 && life.due[i]==0 && t>=life.next_mate[i] &&
            t-life.born[i]>=RABBIT_LIFE.maturity_days*RABBIT_LIFE.day_ticks &&
            a.energy[i]>=RABBIT_LIFE.breeding_energy || continue
        mod(day+life.receptive_phase[i],RABBIT_LIFE.receptivity_period)<RABBIT_LIFE.receptive_days || continue
        bx,bz=floor(Int,a.x[i]/radius),floor(Int,a.z[i]/radius)
        encountered=any(any(j->hypot(a.x[i]-a.x[j],a.z[i]-a.z[j])<=radius &&
            H.clear(s.world,(a.x[i],a.z[i]),(a.x[j],a.z[j])),get(bins,(bx+dx,bz+dz),Int[])) for dx in -1:1 for dz in -1:1)
        encountered && rand(life.rng)<RABBIT_LIFE.conception_chance || continue
        life.due[i]=t+RABBIT_LIFE.gestation_days*RABBIT_LIFE.day_ticks
        life.litter[i]=rand(life.rng,RABBIT_LIFE.litter_min:RABBIT_LIFE.litter_max)
        life.conceptions+=1
    end
end

function rabbit_nurse!(s,t)
    life=s.life;a=s.animals;day=div(t,RABBIT_LIFE.day_ticks)
    # Siblings share the available milk proportionally, without first-child priority.
    mothers=Dict{Int,Vector{Int}}()
    for i in eachindex(s.alive)
        s.alive[i] && dependent(life,i,t) && life.nursed_day[i]<day || continue
        mother=life.mother[i];mother>0 && s.alive[mother] || continue
        hypot(a.x[mother]-a.x[i],a.z[mother]-a.z[i])<=RABBIT_LIFE.nurse_distance || continue
        s.overrides[mother]==H.FLEE && continue
        push!(get!(()->Int[],mothers,mother),i)
    end
    for (mother,children) in mothers
        needs=[max(0.,RABBIT_LIFE.milk_target-a.energy[i]) for i in children]
        requested=sum(needs);requested>0 || continue
        milk=min(requested,max(0.,a.energy[mother]-RABBIT_LIFE.maternal_reserve)*RABBIT_LIFE.milk_efficiency)
        milk>0 || continue
        cost=milk/RABBIT_LIFE.milk_efficiency;a.energy[mother]-=cost
        life.milk_out+=cost;life.milk_in+=milk;life.nursing_visits+=1
        for (j,i) in enumerate(children)
            a.energy[i]+=milk*needs[j]/requested;life.nursed_day[i]=day
        end
    end
end

function rabbit_advance!(s,t)
    life=s.life;a=s.animals
    for i in eachindex(s.alive)
        s.alive[i] && dependent(life,i,t) || continue
        a.state[i]=H.SLEEP;a.counts[i,H.SLEEP]+=1
        a.energy[i]=max(0.,a.energy[i]-RABBIT_LIFE.infant_energy_per_day/RABBIT_LIFE.day_ticks)
    end
    rabbit_nurse!(s,t)
    mod(t+1,RABBIT_LIFE.day_ticks)==0 && rabbit_daily!(s,t+1)
end
function rabbit_reproduction_snapshot(s)
    life=s.life;life===nothing && return nothing
    @assert life.initial_count+life.births==length(s.alive)
    reproduction_balances=(gestation=balance_diagnostic("gestation_energy",life.gestation_out,
        life.newborn_energy+sum(life.invested)+life.lost_investment),
        milk=balance_diagnostic("milk_energy",life.milk_out*RABBIT_LIFE.milk_efficiency,life.milk_in))
    (rule="rabbit-like-reproduction-v1",parameters=RABBIT_LIFE,initial=life.initial_count,
     balances=reproduction_balances,
     initial_young=count(i->life.mother[i]>0 && life.born[i]<0,eachindex(life.born)),
     conceptions=life.conceptions,births=life.births,litters=life.litters,lost_pregnancies=life.lost_pregnancies,
     dependent=count(i->s.alive[i] && dependent(life,i,s.ticks),eachindex(s.alive)),
     pregnant=count(>(0),life.due),milk_out=life.milk_out,milk_in=life.milk_in,
     milk_loss=life.milk_out-life.milk_in,gestation_out=life.gestation_out,newborn_energy=life.newborn_energy,
     gestation_retained=sum(life.invested),gestation_lost=life.lost_investment,
     nursing_visits=life.nursing_visits,nest_return_ticks=life.nest_return_ticks)
end
