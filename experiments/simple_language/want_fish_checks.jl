include("../portable_items/checks.jl")
include("trade_observation.jl")
include("voice_dialogue.jl")
include("reply_trade.jl")
include("want_fish.jl")
const WANT_ROSTER=Dict(ITEM_A=>Dict("name"=>"アキ","features"=>[.1,.2,.3,.4,.1]),
 ITEM_B=>Dict("name"=>"ハル","features"=>[.8,.7,.6,.9,.8]),ITEM_C=>Dict("name"=>"ソラ","features"=>[.6,.8,.9,.6,.7]))
function want_fixture(;fish=WANT_FISH.stock,far=false)
 f=item_fixture(objects=Any[],food_counts=[[20,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,fish],[20,0,0,0,0,0,0,0]],scene=(configured_negotiation=true,))
 empty!(f.w.obstacles);f.w.positions[ITEM_A]=(0.,0.);f.w.positions[ITEM_B]=(0.,far ? 40. : .8);f.w.positions[ITEM_C]=(1.,0.)
 f
end
rows=Any[]
@testset "want fish broadcast to consented exchange" begin
 for scenario in ("stocked","no_fish","unknown_word","out_of_range"),seed in 1:WANT_FISH.trials
  f=want_fixture(fish=scenario=="no_fish" ? 0 : WANT_FISH.stock,far=scenario=="out_of_range")
  event=(id="want-fish",source=ITEM_A,text="魚 欲しい",volume=1.,start_us=0,duration_us=WANT_FISH.utterance_us)
  listeners=Dict(peer=>VoiceListener(peer;seed,vocabulary=scenario=="unknown_word" ? ObservedVocabulary() : want_fish_vocabulary()) for peer in (ITEM_B,ITEM_C))
  replies=Dict(peer=>voice_listener_step!(f.w,peer,listeners[peer],event;
   response_interest=(known,words)->want_fish_interest(f.w.bodies[peer],f.foods.personal[peer],known,words)) for peer in (ITEM_B,ITEM_C))
  @test !(hasproperty(replies[ITEM_C],:response) && replies[ITEM_C].response.method=="interested")
  r=replies[ITEM_B];interested=hasproperty(r,:response) && r.response.method=="interested"
  if scenario!="stocked";@test !interested;end
  steps=Any[];recognized=false
  if interested
   cue=voice_observation(f.w,ITEM_B,ITEM_A,r.reply.text;volume=r.reply.volume,attending=true)
   headings=Dict(ITEM_A=>0.,ITEM_B=>180.,ITEM_C=>270.)
   identity=reply_visual_identity(f.w,ITEM_A,cue,WANT_ROSTER,headings,LW.configured_peer_identity_memory(ITEM_A,WANT_ROSTER);now=3_000_000)
   recognized=identity.status=="recognized";@test recognized
   states=Dict(a=>LW.incidental_item_state(a,seed) for a in (ITEM_A,ITEM_B))
   relations=Dict(a=>LW.social_relations_state(a;relational=true) for a in (ITEM_A,ITEM_B))
   actor=ITEM_A
   for turn in 1:REPLY_TRADE.max_steps
    now=(3+turn)*REPLY_TRADE.step_us
    if actor==ITEM_B
     identity=reply_visual_identity(f.w,actor,(bearing=180.,),WANT_ROSTER,headings,LW.configured_peer_identity_memory(actor,WANT_ROSTER);now)
    else
     identity=reply_visual_identity(f.w,actor,cue,WANT_ROSTER,headings,LW.configured_peer_identity_memory(actor,WANT_ROSTER);now)
    end
    plan=reply_trade_plan!(f,actor,identity,states[actor],relations[actor],now;requested_food=actor==ITEM_A ? WANT_FISH.kind : nothing)
    plan===nothing && break
    if turn==1;@test plan["action"]=="item_offer" && plan["want_food"][WANT_FISH.kind]>0;end
    receipt=reply_trade_execute!(f,actor,states[actor],relations[actor],plan,now)
    push!(steps,(actor=actor,action=plan["action"],status=receipt["status"]))
    receipt["status"]=="offered" || break
    actor=actor==ITEM_A ? ITEM_B : ITEM_A
   end
  end
  @test item_checks(f)===nothing
  push!(rows,(scenario=scenario,seed=seed,interested=interested,recognized=recognized,fish_received=f.foods.personal[ITEM_A][WANT_FISH.kind],steps=steps))
 end
 @test any(r->r.fish_received>0,rows)
 @test all(r->r.scenario=="stocked" || r.fish_received==0,rows)
 # Existing security term lowers response value when the supplier is hungry.
 stock=[0,0,0,0,0,0,0,1];known=[(prediction=(appearance=WANT_FISH.appearance,),)]
 @test want_fish_interest(LW.Body(10,0,10,0),stock,known,(text="魚 欲しい",)) <= want_fish_interest(LW.Body(10,0,90,0),stock,known,(text="魚 欲しい",))
 @test want_fish_interest(LW.Body(10,0,90,0),stock,known,(text="魚 欲しい",);security=Dict("required"=>5.)) < want_fish_interest(LW.Body(10,0,90,0),stock,known,(text="魚 欲しい",))
 @test want_fish_interest(LW.Body(10,0,90,0),stock,known,(text="魚",))===nothing
 @test want_fish_interest(LW.Body(10,0,90,0),stock,known,nothing)===nothing
end
summary=[(scenario=s,interested=count(r->r.scenario==s && r.interested,rows),
 recognized=count(r->r.scenario==s && r.recognized,rows),exchanged=count(r->r.scenario==s && r.fish_received>0,rows)) for s in unique(r.scenario for r in rows)]
write(joinpath(@__DIR__,"want_fish_result.json"),JSON3.write((summary=summary,trials=rows)))
println(JSON3.write(summary))
