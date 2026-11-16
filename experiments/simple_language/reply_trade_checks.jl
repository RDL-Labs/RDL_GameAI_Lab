include("../portable_items/checks.jl")
include("trade_observation.jl")
include("voice_dialogue.jl")
include("reply_trade.jl")
const REPLY_ROSTER=Dict(ITEM_A=>Dict("name"=>"アキ","features"=>[.1,.2,.3,.4,.1]),
 ITEM_B=>Dict("name"=>"ハル","features"=>[.8,.7,.6,.9,.8]),ITEM_C=>Dict("name"=>"ソラ","features"=>[.6,.8,.9,.6,.7]))
function reply_fixture()
 f=item_fixture(objects=Any[],food_counts=[[0,0,0,0,0,0,0,20],[20,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0]],scene=(configured_negotiation=true,))
 empty!(f.w.obstacles);f.w.positions[ITEM_A]=(0.,0.);f.w.positions[ITEM_B]=(0.,.8);f.w.positions[ITEM_C]=(20.,20.)
 f
end
function reply_taught()
 v=ObservedVocabulary()
 for i in 1:3;learn_observed_words!(v,(id="fixture-$i",text="モ",motion=nothing,appearances=["fish-form"]));end
 v
end
rows=Any[]
@testset "reply perception recognition and existing negotiation" begin
 for seed in 1:32
  f=reply_fixture();headings=Dict(ITEM_A=>0.,ITEM_B=>180.,ITEM_C=>0.)
  minds=Dict(ITEM_B=>VoiceListener(ITEM_B;seed,vocabulary=reply_taught(),interests=Dict("fish-form"=>3.)))
  event=(id="fish-call",source=ITEM_A,text="モ",volume=1.,start_us=0,duration_us=3_000_000)
  heard=voice_dialogue!(f.w,minds,event)
  r=heard.listeners[ITEM_B]
  if !hasproperty(r,:reply) || r.reply===nothing
   push!(rows,(seed=seed,status="no_reply",steps=[]));continue
  end
  cue=heard.reply_reception[ITEM_B][ITEM_A]
  memory=LW.configured_peer_identity_memory(ITEM_A,REPLY_ROSTER)
  identity=reply_visual_identity(f.w,ITEM_A,cue,REPLY_ROSTER,headings,memory)
  @test identity.status=="recognized" && identity.name=="ハル"
  @test identity.handle==ITEM_B
  relations=Dict(a=>LW.social_relations_state(a;relational=true) for a in (ITEM_A,ITEM_B))
  LW.social_relation_event!(relations[ITEM_A],ITEM_B,"aid_received","fixture-aid",0;outcome="given")
  relations[ITEM_A]=reply_relation_projection(relations[ITEM_A],identity)
  states=Dict(a=>LW.incidental_item_state(a,seed) for a in (ITEM_A,ITEM_B))
  actor=ITEM_A;steps=Any[]
  for turn in 1:REPLY_TRADE.max_steps
   now=(3+turn)*REPLY_TRADE.step_us
   if actor==ITEM_B
    # Counterparty also sees/recognizes the caller; visual bearing is observed here.
    backcue=(bearing=180.,)
    identity=reply_visual_identity(f.w,actor,backcue,REPLY_ROSTER,headings,LW.configured_peer_identity_memory(actor,REPLY_ROSTER);now)
   else
    identity=reply_visual_identity(f.w,actor,cue,REPLY_ROSTER,headings,memory;now)
   end
   p=reply_trade_plan!(f,actor,identity,states[actor],relations[actor],now)
   p===nothing && break
   receipt=reply_trade_execute!(f,actor,states[actor],relations[actor],p,now)
   push!(steps,(actor=actor,action=p["action"],status=receipt["status"],target=get(p,"target",nothing)))
   @test item_checks(f)===nothing
   receipt["status"]=="offered" || break
   actor=actor==ITEM_A ? ITEM_B : ITEM_A
  end
  for a in (ITEM_A,ITEM_B)
   LW.item_social_observe!(states[a],item_view(f,a;now=12_000_000,open_stores=true);relation=relations[a])
  end
  @test item_checks(f)===nothing
  push!(rows,(seed=seed,status="recognized",steps=steps))
 end
 @test any(r->any(s->s.status=="exchanged",r.steps),rows)
 @test any(r->any(s->s.action=="item_offer",r.steps),rows)
 f=reply_fixture();headings=Dict(ITEM_A=>0.,ITEM_B=>180.,ITEM_C=>0.)
 cue=(bearing=0.,);memory=LW.configured_peer_identity_memory(ITEM_A,REPLY_ROSTER)
 push!(f.w.obstacles,LW.RDLMigrationProbe.Circle(0.,.4,.15))
 blocked=reply_visual_identity(f.w,ITEM_A,cue,REPLY_ROSTER,headings,memory)
 @test blocked.status=="unseen"
 before=deepcopy(f.foods.personal)
 @test reply_trade_plan!(f,ITEM_A,blocked,LW.incidental_item_state(ITEM_A,1),LW.social_relations_state(ITEM_A),4_000_000)===nothing
 @test isempty(f.s["offers"]) && f.foods.personal==before
 empty!(f.w.obstacles);f.w.positions[ITEM_C]=(0.,1.)
 @test reply_visual_identity(f.w,ITEM_A,cue,REPLY_ROSTER,headings,memory).status=="ambiguous_direction"
 f.w.positions[ITEM_C]=(20.,20.);headings[ITEM_B]=0.
 @test reply_visual_identity(f.w,ITEM_A,cue,REPLY_ROSTER,headings,memory).status=="insufficient_observation"
 headings[ITEM_B]=180.;memory["features"][ITEM_C]=copy(memory["features"][ITEM_B])
 @test reply_visual_identity(f.w,ITEM_A,cue,REPLY_ROSTER,headings,memory).status=="ambiguous"
 delete!(memory["features"],ITEM_B)
 mistaken=reply_visual_identity(f.w,ITEM_A,cue,REPLY_ROSTER,headings,memory)
 @test mistaken.inferred_peer==ITEM_C && mistaken.handle==ITEM_B
 relation=LW.social_relations_state(ITEM_A;relational=true)
 LW.social_relation_event!(relation,ITEM_C,"aid_received","known-c",0;outcome="given")
 projected=reply_relation_projection(relation,mistaken)
 @test LW.social_relation_bias(projected,ITEM_B,"give")["weight"]==LW.social_relation_bias(relation,ITEM_C,"give")["weight"]
 @test !haskey(relation["peers"],ITEM_B)
 mistaken_plan=reply_trade_plan!(f,ITEM_A,mistaken,LW.incidental_item_state(ITEM_A,1),projected,4_000_000)
 @test mistaken_plan!==nothing && mistaken_plan["target"]==ITEM_B
 @test reply_visual_identity(f.w,ITEM_A,nothing,REPLY_ROSTER,headings,memory).status=="not_heard"
end
summary=Dict("trials"=>length(rows),"replied"=>count(r->r.status=="recognized",rows),
 "offered"=>count(r->any(s->s.action=="item_offer",r.steps),rows),"countered"=>count(r->any(s->s.action=="item_counter",r.steps),rows),
 "exchanged"=>count(r->any(s->s.status=="exchanged",r.steps),rows),"declined"=>count(r->any(s->s.status=="declined",r.steps),rows))
write(joinpath(@__DIR__,"reply_trade_result.json"),JSON3.write((summary=summary,trials=rows)))
println(JSON3.write(summary))
