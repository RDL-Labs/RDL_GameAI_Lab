# Isolated actor-carried scent lifecycle, no spatial diffusion or normal LW wiring.
include("sensory_trigger_probe.jl")
const AROMA_RULE=(cooking=1.,ready=.7,eating=.6,tail_seconds=60.) # trial calibration, simulation seconds
mutable struct AromaCarrier
 features::Vector{Float64}
 strength::Float64
 last_time::Float64
 tail_start::Union{Nothing,Float64}
 tail_initial::Float64
 phase::Symbol
end
AromaCarrier()=AromaCarrier(Float64[],0.,0.,nothing,0.,:idle)
function scent_step!(s,phase,now;features=nothing)
 now>=s.last_time || error("scent time rewind")
 phase in (:idle,:cooking,:ready,:eating) || error("unknown phase")
 if phase in (:cooking,:ready,:eating)
  features===nothing && error("active scent requires observed food features")
  s.features=copy(features);s.strength=getproperty(AROMA_RULE,phase)
  s.tail_start=nothing;s.tail_initial=0.
 else
  if s.phase!=:idle
   s.tail_start=now;s.tail_initial=s.strength
  end
  s.strength=s.tail_start===nothing ? 0. : s.tail_initial*max(0.,1-(now-s.tail_start)/AROMA_RULE.tail_seconds)
 end
 s.phase=phase;s.last_time=now;s
end
function carrier_cues(s,source_position,observer_position)
 s.strength<=0 && return Any[]
 distance=sqrt(sum(abs2,source_position.-observer_position))
 Any[(channel=:aroma,features=copy(s.features),strength=s.strength/(1+(distance/CUE_RULE.smell_scale)^2))]
end
memories=FoodMemory[];eat!(memories,"meal_A",[1.,0.],[1.,0.],1.5)
carrier=AromaCarrier();rows=Any[]
for (phase,time) in [(:cooking,0.),(:cooking,120.),(:ready,180.),(:eating,240.),(:idle,300.),(:idle,330.),(:idle,360.),(:idle,420.)]
 scent_step!(carrier,phase,time;features=phase==:idle ? nothing : [1.,0.])
 near=carrier_cues(carrier,[0.,0.],[1.,0.]);far=carrier_cues(carrier,[0.,0.],[20.,0.])
 decision=recall(memories,near)
 push!(rows,(time,phase,strength=carrier.strength,near=isempty(near) ? 0. : near[1].strength,
  far=isempty(far) ? 0. : far[1].strength,preferred=decision.preferred,probabilities=decision.probabilities))
end
@testset "actor scent lifecycle" begin
 @test rows[1].strength==rows[2].strength==1.
 @test rows[3].strength==.7
 @test rows[4].strength==rows[5].strength==.6
 @test rows[6].strength≈.3
 @test rows[7].strength==rows[8].strength==0
 @test all(r->r.near>=r.far>=0,rows)
 @test rows[1].preferred=="seek:meal_A"
 @test rows[end].preferred=="continue"
 @test memories[1].meals==1 # smelling never counts as eating
 @test isempty(recall(FoodMemory[],[(channel=:aroma,features=[1.,0.],strength=1.)]).recalled)
 other=AromaCarrier();@test isempty(carrier_cues(other,[0.,0.],[0.,0.]))
 scent_step!(other,:cooking,0.;features=[1.,0.])
 @test carrier_cues(other,[10.,0.],[11.,0.])[1].strength≈rows[1].near
 scent_step!(other,:idle,5.);scent_step!(other,:idle,100.)
 @test other.strength==0 # interrupted activity also expires
 scent_step!(other,:cooking,101.;features=[0.,1.]);@test other.features==[0.,1.]
 @test other.strength==1
 @test_throws ErrorException scent_step!(other,:idle,100.)
end
write(joinpath(@__DIR__,"carried_aroma_result.json"),JSON3.write(rows))
for r in rows;println(JSON3.write(r));end
