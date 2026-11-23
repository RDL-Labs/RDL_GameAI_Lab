# Initial expression-emission adapter, not a physiological model or a diagnosis.
# Several bodily causes deliberately produce the same public distress signal.
# Provisional physical-to-visible mapping, not a learned diagnosis or action rule.
# roundness_reference_multiple=2 means reference fat gives roundness=.5.
# These visual proportions never change collision geometry or identity features.
const BODY_APPEARANCE_RULES=(roundness_reference_multiple=2.,near_distance=4.,
    distant_steps=1.,near_steps=4.,attended_steps=8.)
function configured_body_appearance(body)
    body isa HumanBody || return nothing # old scalar bodies have no composition
    physical=body.nutrients;p=RDLBody.MACRO_PARAMETERS
    (roundness=clamp(physical.fat/(BODY_APPEARANCE_RULES.roundness_reference_multiple*p.fat_reference),0.,1.),
     build=clamp(physical.tissue/p.tissue_target,0.,1.),
     weakness=1-body_mobility(body))
end
function configured_expression(body;fear=0.,anxiety=0.)
    appearance=configured_body_appearance(body)
    weakness=appearance===nothing ? 0. : appearance.weakness
    distress=clamp(max(body_demand(body),weakness,body.strain,body.damage,clamp(anxiety,0.,1.)),0.,1.)
    afraid=clamp(Float64(fear),0.,1.)
    (calm=1-max(distress,afraid),distress=distress,fear=afraid)
end
