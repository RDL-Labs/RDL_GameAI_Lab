using JSON3
length(ARGS)==2 || error("usage: sugar_forecast_compare.jl ORIGINAL REPLAY")
rows=Any[]
for (label,root) in zip(("before","after"),ARGS)
 result=JSON3.read(read(joinpath(root,"run/result.json"),String))
 prior=result.daily[19];current=result.daily[20]
 for actor in (:npc_a,:npc_b,:npc_c,:npc_d)
  f=current.food_resources.game_proficiency.fishing[actor]
  f0=prior.food_resources.game_proficiency.fishing[actor]
  counts=current.counts[actor];oldcounts=prior.counts[actor]
  push!(rows,(condition=label,actor=actor,attempts=f.attempts-f0.attempts,caught=f.caught-f0.caught,
   interrupted=f.interrupted-f0.interrupted,eaten=current.digestion[actor].eaten-prior.digestion[actor].eaten,
   pickup=get(counts,:pickup,0)-get(oldcounts,:pickup,0),fish_ticks=get(counts,:fish,0)-get(oldcounts,:fish,0),
   body=current.physical[actor].body,home=current.home_activity.actors[actor]))
 end
end
write(joinpath(ARGS[2],"comparison.json"),JSON3.write(rows))
for row in rows;println(JSON3.write(row));end
