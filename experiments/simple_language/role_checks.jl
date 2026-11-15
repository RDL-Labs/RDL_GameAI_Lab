using Test,JSON3,Serialization
include("../../src/lw/LW.jl")
include("trade_observation.jl")
include("role_probe.jl")
const ROLE_SPEAKER,ROLE_PARTNER,ROLE_OBSERVER=LW.IDS[1:3]
w=LW.world(true);empty!(w.obstacles)
w.positions[ROLE_OBSERVER]=(0.,0.);w.positions[ROLE_SPEAKER]=(-.5,2.);w.positions[ROLE_PARTNER]=(.5,2.)
memory=RoleExperience()
# 暫定固定教材。Only this test produces scripted scenes/utterances. Normal LW
# never includes this file. Replace with actual observed action transitions later.
lessons=[
 (:attention,"ナ","g1","peer-facing-away","peer-facing-speaker"),
 (:initiative,"モ","g2","object-held","peer-reaching"),
 (:response,"ユ","g3","peer-reaching","object-received"),
 (:response,"ケ","g4","peer-reaching","object-retained")]
rows=Any[]
@testset "role-organized communication without role labels" begin
 @test role_predict(memory,"object-held","モ").status=="unknown"
 for (role,word,gesture,before,after) in lessons
  for i in 1:2
   event=(id="$word:$i",actor=ROLE_SPEAKER,role=role,text=word,motion=gesture,appearances=String[])
   observation=role_public_observation(w,ROLE_OBSERVER,0.,event)
   @test !hasproperty(observation,:role)
   before_seen=role_visible_scene(w,ROLE_OBSERVER,0.,ROLE_PARTNER,before)
   after_seen=role_visible_scene(w,ROLE_OBSERVER,0.,ROLE_PARTNER,after)
   @test role_learn!(memory,observation,before_seen,after_seen)
   @test !role_learn!(memory,observation,before_seen,after_seen)
  end
  prediction=role_predict(memory,before,word)
  @test prediction.predicted==after
  @test role_predict(memory,before,"gesture:"*gesture).predicted==after
  push!(rows,(sender_role=role,context=before,token=word,prediction=prediction))
 end
 # Same signal, different contexts: receiver does not look up a universal role.
 for i in 1:2
  event=(id="context:$i",actor=ROLE_SPEAKER,role=:attention,text="モ",motion=nothing,appearances=String[])
  role_learn!(memory,role_public_observation(w,ROLE_OBSERVER,0.,event),"peer-facing-away","peer-facing-speaker")
 end
 @test role_predict(memory,"peer-facing-away","モ").predicted=="peer-facing-speaker"
 @test role_predict(memory,"object-held","モ").predicted=="peer-reaching"
 @test role_predict(memory,"unseen-context","モ").status=="unknown"
 event=(id="hidden",actor=ROLE_SPEAKER,role=:response,text="ユ",motion="g3",appearances=String[])
 snapshot=deepcopy(memory.associations)
 @test !role_learn!(memory,role_public_observation(w,ROLE_OBSERVER,0.,event),"peer-reaching",role_visible_scene(w,ROLE_OBSERVER,180.,ROLE_PARTNER,"object-received"))
 @test memory.associations==snapshot
 @test role_public_observation(w,ROLE_OBSERVER,0.,event;attending=false)===nothing
 # Contradictory observed outcomes remain ambiguous instead of forcing success.
 uncertain=RoleExperience()
 for (i,after) in enumerate(("object-received","object-retained"))
  role_learn!(uncertain,(id="mixed$i",text="ユ",motion=nothing),"peer-reaching",after)
 end
 @test role_predict(uncertain,"peer-reaching","ユ").status=="ambiguous"
 io=IOBuffer();serialize(io,memory);seekstart(io);restored=deserialize(io)
 @test restored.associations==memory.associations
 @test restored.receipts==memory.receipts
end
write(joinpath(@__DIR__,"role_result.json"),JSON3.write((scope="scripted local observable transitions; no intent labels supplied to learner",cases=rows)))
