# 暫定固定: 人あり専用runner第6引数trueで有効（既定false）。
# 人臭への負の価値は未学習の初期設定。世界の残留臭だけを局所観測し移動へ合成する。
# 暫定固定: camp指定時はその座標を減衰しない濃い世界匂い源にする（人の滞在不要）。
# 通過跡は弱く短命。将来は居住/施設の蓄積へ置換。立入禁止や強制逃走ではない。
const HUMAN_SCENT=(cell_size=4.,radius=8.,lifetime_ticks=600,deposit_interval=60,
    deposit=.05,capacity=.2,trail_gradient_cap=.2,camp_strength=4.,
    predator_repulsion=3.,rabbit_repulsion=2.,epsilon=1e-9)
mutable struct HumanScentField
    marks::Dict{Tuple{Int,Int},NamedTuple{(:strength,:tick),Tuple{Float64,Int}}}
    deposits::Int
    samples::Dict{Symbol,Int}
    signals::Dict{Symbol,Int}
    turns::Dict{Symbol,Int}
    camp::Union{Nothing,Tuple{Float64,Float64}}
end
function HumanScentField(;camp=nothing)
    camp===nothing || (length(camp)==2 && all(isfinite,camp)) || error("finite 2D camp position required")
    HumanScentField(Dict{Tuple{Int,Int},NamedTuple{(:strength,:tick),Tuple{Float64,Int}}}(),0,
        Dict(:predator=>0,:rabbit=>0),Dict(:predator=>0,:rabbit=>0),Dict(:predator=>0,:rabbit=>0),
        camp===nothing ? nothing : (Float64(camp[1]),Float64(camp[2])))
end
human_scent_strength(record,t)=record.strength*clamp(1-(t-record.tick)/HUMAN_SCENT.lifetime_ticks,0.,1.)
human_scent_cell(x,z)=(floor(Int,x/HUMAN_SCENT.cell_size),floor(Int,z/HUMAN_SCENT.cell_size))
function configured_human_scent_deposit!(field,humans,t)
    t%HUMAN_SCENT.deposit_interval==0 || return
    filter!(pair->human_scent_strength(last(pair),t)>0,field.marks)
    for position in humans
        key=human_scent_cell(position...);prior=get(field.marks,key,nothing)
        strength=prior===nothing ? 0. : human_scent_strength(prior,t)
        field.marks[key]=(strength=min(HUMAN_SCENT.capacity,strength+HUMAN_SCENT.deposit),tick=t)
        field.deposits+=1
    end
end
function human_scent_gradient(field,x,z,t)
    rule=HUMAN_SCENT;cx,cz=human_scent_cell(x,z);span=ceil(Int,rule.radius/rule.cell_size)
    gx=0.;gz=0.;signal=0.
    for ix in cx-span:cx+span,iz in cz-span:cz+span
        record=get(field.marks,(ix,iz),nothing);record===nothing && continue
        dx=x-(ix+.5)*rule.cell_size;dz=z-(iz+.5)*rule.cell_size;distance=hypot(dx,dz)
        distance<rule.radius || continue
        local_signal=human_scent_strength(record,t)*(1-distance/rule.radius)^2
        signal+=local_signal
        gx+=local_signal*dx/max(distance,rule.epsilon);gz+=local_signal*dz/max(distance,rule.epsilon)
    end
    # Many overlapping footprints must not become a second permanent camp.
    trail_signal=signal;trail_magnitude=hypot(gx,gz)
    if trail_magnitude>rule.trail_gradient_cap
        factor=rule.trail_gradient_cap/trail_magnitude;gx*=factor;gz*=factor
    end
    camp_signal=0.
    if field.camp!==nothing
        dx=x-field.camp[1];dz=z-field.camp[2];distance=hypot(dx,dz)
        if distance<rule.radius
            camp_signal=rule.camp_strength*(1-distance/rule.radius)^2
            gx+=camp_signal*dx/max(distance,rule.epsilon)
            gz+=camp_signal*dz/max(distance,rule.epsilon)
        end
    end
    (x=gx,z=gz,signal=trail_signal+camp_signal,trail_signal=trail_signal,camp_signal=camp_signal)
end
function configured_human_scent_heading(field,x,z,heading,t,species)
    rule=HUMAN_SCENT;g=human_scent_gradient(field,x,z,t)
    field.samples[species]+=1
    g.signal>0 && (field.signals[species]+=1)
    magnitude=hypot(g.x,g.z);magnitude>rule.epsilon || return heading
    weight=species==:predator ? rule.predator_repulsion : rule.rabbit_repulsion
    scale=weight/max(1.,magnitude)
    fx=cos(heading)+scale*g.x;fz=sin(heading)+scale*g.z
    hypot(fx,fz)>rule.epsilon || return heading
    result=atan(fz,fx)
    abs(sin(result-heading))>rule.epsilon || cos(result-heading)<0 ? (field.turns[species]+=1) : nothing
    result
end
human_scent_report(field)=field===nothing ? nothing : (rule=HUMAN_SCENT,camp=field.camp,marks=length(field.marks),deposits=field.deposits,
    samples=copy(field.samples),signals=copy(field.signals),turns=copy(field.turns))
