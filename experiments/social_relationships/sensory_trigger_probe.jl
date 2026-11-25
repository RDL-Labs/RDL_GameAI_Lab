# Isolated sensory-trigger probe. No normal LW connection or biological calibration.
using Test, JSON3, LinearAlgebra
const CUE_RULE=(smell_scale=4.,vision_scale=8.,similarity_scale=.25,temperature=.3,approach_cost=.2,curiosity=.15)
mutable struct FoodMemory
 label::String
 aroma::Vector{Float64}
 appearance::Vector{Float64}
 liking::Float64
 meals::Int
end
# Only own eating supplies liking. Context association is an explicit trial assumption.
function eat!(memories,label,aroma,appearance,liking)
 i=findfirst(m->m.label==label,memories)
 if i===nothing
  push!(memories,FoodMemory(label,copy(aroma),copy(appearance),liking,1))
 else
  m=memories[i];m.meals+=1;m.liking+=(liking-m.liking)/m.meals
 end
end
function perceive(;cooking=false,eating=false,distance=0.,visible=true,aroma=[1.,0.],appearance=[1.,0.])
 cues=Any[]
 cooking && push!(cues,(channel=:aroma,features=copy(aroma),strength=1/(1+(distance/CUE_RULE.smell_scale)^2)))
 eating && visible && push!(cues,(channel=:appearance,features=copy(appearance),strength=1/(1+(distance/CUE_RULE.vision_scale)^2)))
 cues
end
similarity(x,y)=exp(-sum(abs2,x.-y)/CUE_RULE.similarity_scale)
function recall(memories,cues;current_value=.6,appetite=1.)
 recalled=Any[]
 for m in memories
  activation=maximum((c.strength*similarity(c.features,c.channel==:aroma ? m.aroma : m.appearance) for c in cues);init=0.)
  activation>0 || continue
  push!(recalled,(label=m.label,activation,liking=m.liking,meals=m.meals,
    expected=activation*m.liking*appetite-CUE_RULE.approach_cost))
 end
 candidates=Any[(action="continue",score=current_value)]
 for r in recalled;push!(candidates,(action="seek:"*r.label,score=r.expected));end
 if isempty(recalled)&&!isempty(cues)
  push!(candidates,(action="inspect_unknown",score=CUE_RULE.curiosity*maximum(c.strength for c in cues)-CUE_RULE.approach_cost))
 end
 scores=[c.score for c in candidates];weights=exp.((scores.-maximum(scores))./CUE_RULE.temperature);weights./=sum(weights)
 (recalled=recalled,candidates=candidates,probabilities=weights,preferred=candidates[argmax(weights)].action)
end
if abspath(PROGRAM_FILE)==abspath(@__FILE__)
memories=FoodMemory[]
eat!(memories,"meal_A",[1.,0.],[1.,0.],1.5)
eat!(memories,"meal_B",[0.,1.],[0.,1.],-.5)
original=deepcopy(memories)
near=perceive(cooking=true,distance=1.)
results=Dict(
 "familiar_near_aroma"=>recall(memories,near),
 "familiar_far_aroma"=>recall(memories,perceive(cooking=true,distance=20.)),
 "familiar_visible_meal"=>recall(memories,perceive(eating=true,distance=2.)),
 "occluded_meal"=>recall(memories,perceive(eating=true,distance=2.,visible=false)),
 "unknown_meal"=>recall(FoodMemory[],perceive(eating=true,distance=2.)),
 "urgent_current_goal"=>recall(memories,near;current_value=3.),
 "low_appetite"=>recall(memories,near;appetite=.1),
 "disliked_aroma"=>recall(memories,perceive(cooking=true,distance=1.,aroma=[0.,1.])),
 "both_cues"=>recall(memories,perceive(cooking=true,eating=true,distance=1.)))
@testset "observation recalls but does not invent taste" begin
 @test results["familiar_near_aroma"].preferred=="seek:meal_A"
 @test results["familiar_visible_meal"].preferred=="seek:meal_A"
 for name in ["familiar_far_aroma","occluded_meal","urgent_current_goal","low_appetite","disliked_aroma"]
  @test results[name].preferred=="continue"
 end
 @test isempty(results["unknown_meal"].recalled)
 @test any(c->c.action=="inspect_unknown",results["unknown_meal"].candidates)
 @test isempty(results["occluded_meal"].recalled)
 @test results["familiar_near_aroma"].probabilities[1]>0 # recall does not force switching
 @test results["both_cues"].recalled[1].activation<=1 # no duplicated full reward
 @test all(a.meals==b.meals && a.liking==b.liking for (a,b) in zip(memories,original))
 learner=FoodMemory[];recall(learner,near);@test isempty(learner)
 eat!(learner,"meal_A",[1.,0.],[1.,0.],1.5)
 @test recall(learner,near).preferred=="seek:meal_A"
 eat!(learner,"meal_A",[1.,0.],[1.,0.],-1.5)
 @test recall(learner,near).preferred=="continue"
end
write(joinpath(@__DIR__,"sensory_trigger_result.json"),JSON3.write(results))
for name in sort(collect(keys(results)))
 r=results[name];println(name," ",r.preferred," ",JSON3.write(r.probabilities))
end

end

