# 暫定固定・局所試験のみ明示的にComposedPredatorPhysiology(p)でON。
# 既存初期備蓄900を150/450/消耗可能タンパク300に分配（追加エネルギーなし）。
# 維持組織300は燃料から除外。生物学的に較正した値ではない。
# 給餌は試験APIによる直接補給。将来は栄養組成・消化・人の給餌行動へ置換。
const PREDATOR_COMPOSITION=(available_fraction=1/6,fat_fraction=1/2,
    default_chase_speed=.5, # mirror directional predator default until shared species speeds
    structural_protein=300.,collapse_fraction=.5,repair_per_tick=.05)
mutable struct ComposedPredatorPhysiology
    body::LW.Body
    limited_ticks::Int
    composition::LW.RDLBody.Composition
end
function ComposedPredatorPhysiology(p)
    r=PREDATOR_COMPOSITION;usable_protein=p.food*(1-r.available_fraction-r.fat_fraction)
    c=LW.RDLBody.Composition(available=p.food*r.available_fraction,fat=p.food*r.fat_fraction,
        protein=r.structural_protein+usable_protein,protein_min=r.structural_protein,
        protein_target=r.structural_protein+usable_protein,
        collapse_protein=r.structural_protein+r.collapse_fraction*usable_protein)
    ComposedPredatorPhysiology(LW.Body(PREDATOR_BODY.burst_capacity,0.,p.food,0.),0,c)
end
predator_composition_factor(s)=s isa ComposedPredatorPhysiology ? LW.RDLBody.composition_mobility(s.composition) : 1.
function configured_predator_composition_sync!(s,p,previous_food,previous_eaten)
    s isa ComposedPredatorPhysiology || return
    gain=p.eaten-previous_eaten
    LW.RDLBody.composition_feed!(s.composition,gain)
    LW.RDLBody.composition_consume!(s.composition,max(0.,previous_food+gain-p.food))
    LW.RDLBody.composition_repair!(s.composition,PREDATOR_COMPOSITION.repair_per_tick)
    p.food=LW.RDLBody.composition_energy(s.composition);p.alive=s.composition.alive
    b=s.body;s.body=LW.Body(b.burst,b.strain,p.food,b.damage)
end
function configured_predator_feed!(s::ComposedPredatorPhysiology,p,amount)
    isfinite(amount) && amount>=0 || throw(ArgumentError("feeding"))
    accepted=LW.RDLBody.composition_feed!(s.composition,min(amount,max(0.,PREDATOR_ANIMAL_TRIAL.capacity-p.food)))
    p.eaten+=accepted;p.food=LW.RDLBody.composition_energy(s.composition)
    b=s.body;s.body=LW.Body(b.burst,b.strain,p.food,b.damage)
    accepted
end
function configured_predator_collapse_hold!(s,p,mind,t)
    s isa ComposedPredatorPhysiology && s.composition.collapsed && p.alive || return false
    # 暫定身体ゲート: voluntary planning off; metabolism and external feed remain.
    if mind.trial!==nothing
        mind.selected["body_end_reason"]="collapsed"
        predator_mind_close!(mind,p,(actor=nothing,distance=Inf),t;physiology=s)
    end
    p.mode=:collapsed;p.visual.body.state=P.REST;p.visual.body.target=0
    true
end
predator_physiology_report(s::ComposedPredatorPhysiology)=merge((burst=s.body.burst,strain=s.body.strain,reserve=s.body.reserve,damage=s.body.damage,need=predator_recovery_need(s.body),limited_ticks=s.limited_ticks),(composition=LW.RDLBody.composition_snapshot(s.composition),))

