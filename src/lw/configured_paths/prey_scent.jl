include("predator_scat_cue.jl")
# 暫定固定・動物単独実験のみ、既定OFF。種別を区別しない獲物臭の地表痕跡。
# 風・拡散なし。世界の付着セルと近傍で嗅いだコピーを分離し、遠方の現在位置は渡さない。
# 探索中だけ濃い近傍セルへ向きを補助する固定設定。視認追跡/攻撃を上書きしない。
# 将来は人を含む感覚入力とMB候補評価へ置換。以下の数値は生物学的測定値ではない。
const PREY_SCENT=(cell_size=4.,radius=6.,deposit_interval=30,sniff_interval=30,
    lifetime=17280,deposit=1.,capacity=4.,minimum_signal=.05,arrival_radius=1.)
const PreyScentRecord=NamedTuple{(:strength,:tick),Tuple{Float64,Int}}
# 暫定固定の慎重探索（既定OFF）。強い匂いを近さの仮説として扱い、
# 視覚確認できない同じ場所では見込みを下げる。将来は経験MBの予測更新へ置換。
const PREY_SCENT_CAUTION=(strong_signal=.6,speed=.08,unconfirmed_ticks=120,
    cooldown_ticks=600)
mutable struct PreyScentWorld
    marks::Dict{Tuple{Int,Int},PreyScentRecord}
    observed::Vector{Any}
    deposits::Int
    sniffs::Int
    detections::Int
    steering_ticks::Int
    cautious::Bool
    caution_ticks::Vector{Int}
    unconfirmed::Vector{Int}
    cooldown::Vector{Dict{Tuple{Int,Int},Int}}
    active_target::Vector{Any}
    rejected::Int
end
PreyScentWorld(n;cautious=false)=PreyScentWorld(Dict{Tuple{Int,Int},PreyScentRecord}(),Any[nothing for _ in 1:n],0,0,0,0,
    cautious,zeros(Int,n),zeros(Int,n),[Dict{Tuple{Int,Int},Int}() for _ in 1:n],Any[nothing for _ in 1:n],0)
prey_scent_cell(x,z)=(floor(Int,x/PREY_SCENT.cell_size),floor(Int,z/PREY_SCENT.cell_size))
prey_scent_strength(record,t)=record.strength*max(0.,1-(t-record.tick)/PREY_SCENT.lifetime)
function configured_prey_scent_tick!(scent,s,predators,t;present=nothing,scat_state=nothing)
    rule=PREY_SCENT
    if t%rule.deposit_interval==0
        # One mixed trace per cell, not per animal. Stationary live prey also emit.
        for i in eachindex(s.alive)
            s.alive[i] || continue
            key=prey_scent_cell(s.animals.x[i],s.animals.z[i])
            old=get(scent.marks,key,nothing)
            amount=old===nothing ? 0. : prey_scent_strength(old,t)
            scent.marks[key]=(strength=min(rule.capacity,amount+rule.deposit),tick=t)
            scent.deposits+=1
        end
    end
    # Bounded map has bounded cell count; lazy decay needs no per-tick world sweep.
    t%rule.sniff_interval==0 || return
    for (i,p) in enumerate(predators)
        present!==nothing && !present[i] && continue
        scent.observed[i]=nothing
        p.alive && p.mode==:hunt || continue
        b=p.visual.body;b.state in (P.ATTACK,P.CHASE,P.RECOVER) && continue
        scent.sniffs+=1;cx,cz=prey_scent_cell(b.x,b.z)
        radius=ceil(Int,rule.radius/rule.cell_size);best=rule.minimum_signal
        for x in cx-radius:cx+radius,z in cz-radius:cz+radius
            record=get(scent.marks,(x,z),nothing);record===nothing && continue
            scent.cautious && t<get(scent.cooldown[i],(x,z),0) && continue
            target=((x+.5)*rule.cell_size,(z+.5)*rule.cell_size)
            distance=hypot(target[1]-b.x,target[2]-b.z)
            rule.arrival_radius<distance<=rule.radius || continue
            signal=prey_scent_strength(record,t)/(1+distance)
            if signal>best
                best=signal;scent.observed[i]=(target=target,signal=signal,tick=t)
            end
        end
        if scat_state!==nothing
            cue=configured_predator_scat_cue(scat_state,scent,p,i,t,best)
            cue!==nothing && (scent.observed[i]=cue)
        end
        scent.observed[i]!==nothing && (scent.detections+=1)
    end
end
function configured_prey_scent_steer!(scent,p,i,t)
    observation=scent.observed[i];b=p.visual.body
    scent.active_target[i]=nothing
    b.state in (P.CHASE,P.ATTACK) && (scent.unconfirmed[i]=0)
    p.alive && p.mode==:hunt && b.state==P.SEARCH || return
    observation===nothing && return
    t-observation.tick<PREY_SCENT.sniff_interval || return
    if scent.cautious
        key=prey_scent_cell(observation.target...)
        t<get(scent.cooldown[i],key,0) && return
        if observation.signal>=PREY_SCENT_CAUTION.strong_signal
            scent.unconfirmed[i]+=1
            if scent.unconfirmed[i]>=PREY_SCENT_CAUTION.unconfirmed_ticks
                scent.cooldown[i][key]=t+PREY_SCENT_CAUTION.cooldown_ticks
                scent.unconfirmed[i]=0;scent.rejected+=1;return
            end
            scent.active_target[i]=observation.target;scent.caution_ticks[i]+=1
        end
    end
    dx=observation.target[1]-b.x;dz=observation.target[2]-b.z
    hypot(dx,dz)>PREY_SCENT.arrival_radius || return
    b.heading=atan(dz,dx);scent.steering_ticks+=1
end
prey_scent_report(scent)=scent===nothing ? nothing :
    (cells=length(scent.marks),deposits=scent.deposits,sniffs=scent.sniffs,
     detections=scent.detections,steering_ticks=scent.steering_ticks,
     cautious=scent.cautious,caution_ticks=copy(scent.caution_ticks),rejected=scent.rejected)
