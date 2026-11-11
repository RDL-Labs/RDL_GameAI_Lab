using Test, Serialization, JSON3
include("../../src/lw/LW.jl")
const checkpoint=ARGS[1]
const saved=deserialize(checkpoint).state
const saved_body=saved[:w].bodies["npc_b"]
# Controlled local counterfactual: identical B memory/body except fatigue=.85.
# This does not claim B naturally reached .85 at this checkpoint.
const body=LW.Body(saved_body.burst,.85,saved_body.reserve,saved_body.damage)
@testset "fatigue relief forecasts" begin
 near=LW.fatigue_forecast(body,0,4.,.8)
 far=LW.fatigue_forecast(body,0,800.,.8)
 @test near["continue_probability"]>far["continue_probability"]
 @test near["predicted_strain"]<1<far["predicted_strain"]
 @test LW.fatigue_forecast(body,0,4.,.8)["continue_probability"]>LW.fatigue_forecast(body,0,4.,0.)["continue_probability"]
 @test LW.fatigue_forecast(body,20,800.,.8)["continue_probability"]<far["continue_probability"]
 @test LW.fatigue_forecast(LW.Body(1.,1.,80.,0.),0,4.,1.)["continue_probability"]==0
 @test LW.fatigue_forecast(LW.Body(1.,.85,0.,0.),0,4.,1.)["continue_probability"]==0
 @test !LW.configured_legacy_fatigue_continue(body)
 map=deepcopy(saved[:mb_maps]["npc_b"]);loop=LW.BasicLoop("fatigue-check";probabilistic=true,seed=13)
 low=LW.Body(1.,.79,80.,0.);prior=deepcopy(loop.rng)
 @test LW.fatigue_navigation_continue!(map,low,0,nothing,true,loop,0)
 @test rand(prior)==rand(deepcopy(loop.rng))
end

function local_trial(seed,distance;legacy=false)
 map=deepcopy(saved[:mb_maps]["npc_b"])
 # Same initial learned home-rest value; the two arms share a seed and body.
 loop=LW.BasicLoop("fatigue-local";probabilistic=true,seed)
 current=body;remaining=Float64(distance);rest_ticks=0;walk_ticks=0
 first_continue=false
 for tick in 0:1999
  target=LW.D("distance"=>remaining)
  go=legacy ? LW.configured_legacy_fatigue_continue(current) : LW.fatigue_navigation_continue!(map,current,0,target,true,loop,tick*1_000_000)
  tick==0 && (first_continue=go)
  action=go ? "walk" : "rest"
  current,status,moved,_=LW.step(current,action,0)
  @assert status in ("performed","rested")
  current=LW.metabolize(current,1.)
  remaining-=moved;walk_ticks+=Int(go);rest_ticks+=Int(!go)
  remaining<=1.25 && return (arrived=true,ticks=tick+1,rest_ticks,walk_ticks,first_continue,reserve=current.reserve,strain=current.strain)
 end
 (arrived=false,ticks=2000,rest_ticks,walk_ticks,first_continue,reserve=current.reserve,strain=current.strain)
end
rows=Any[]
@testset "paired local walking and rest" begin
 for distance in (3.,200.)
  baseline=local_trial(1,distance;legacy=true)
  trials=[local_trial(seed,distance) for seed in 1:100]
  @test all(t->t.arrived,trials)
  @test all(t->0<=t.strain<=1 && t.reserve>0,trials)
  push!(rows,(distance,baseline,first_continue=count(t->t.first_continue,trials),
      mean_ticks=sum(t.ticks for t in trials)/length(trials),mean_rest_ticks=sum(t.rest_ticks for t in trials)/length(trials)))
 end
end
output=(checkpoint,controlled_strain=.85,saved_strain=saved_body.strain,rows)
write(ARGS[2],JSON3.write(output));println(JSON3.write(output))
