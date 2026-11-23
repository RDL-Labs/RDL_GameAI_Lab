include("../portable_items/checks.jl")
include("trade_observation.jl")
include("voice_dialogue.jl")
include("want_fish.jl")
const D=LW.D
include("../../src/lw/configured_paths/voice_request.jl")
bundle(kind)=D("items"=>Any[],"food"=>[k==kind ? 1 : 0 for k in 1:8])
function supplier_state(seed)
 s=LW.incidental_item_state(ITEM_A,seed)
 s["exchange_relations"]=Any[]
 s
end
@testset "learned supplier chooses call addressee" begin
 state=supplier_state(1);view=D("trade_partners"=>[ITEM_B,ITEM_C])
 relation=D("identity_observation"=>D("names"=>D(ITEM_B=>"ハル",ITEM_C=>"ソラ")))
 @test configured_want_addressee!(state,view,relation,3,0).peer===nothing
 give=bundle(1);want=bundle(3)
 plan=D("exchange_give"=>give,"exchange_want"=>want,"partner"=>ITEM_B,"action"=>"item_accept","context"=>D("need"=>.5))
 LW.item_exchange_learn!(state,plan,D("status"=>"exchanged","us"=>1))
 first_strength=LW.item_exchange_supplier_support(state,3,[ITEM_B])[ITEM_B]
 for us in 2:8;LW.item_exchange_learn!(state,plan,D("status"=>"exchanged","us"=>us));end
 @test LW.item_exchange_supplier_support(state,3,[ITEM_B])[ITEM_B]>first_strength
 @test isempty(LW.item_exchange_supplier_support(state,1,[ITEM_B]))
 @test isempty(LW.item_exchange_supplier_support(state,3,[ITEM_C]))
 @test !haskey(view,"observed_food_stocks")
 counts=Dict("broadcast"=>0,ITEM_B=>0)
 probability=0.
 for seed in 1:128
  trial=supplier_state(seed);trial["exchange_relations"]=deepcopy(state["exchange_relations"])
  choice=configured_want_addressee!(trial,view,relation,3,seed)
  counts[choice.peer===nothing ? "broadcast" : choice.peer]+=1
  probability=choice.probabilities[ITEM_B]
  @test !haskey(choice.probabilities,ITEM_C)
 end
 @test probability>.5
 @test counts[ITEM_B]>counts["broadcast"]
 @test configured_want_addressee!(state,view,D(),3,200).peer===nothing
 before=LW.item_exchange_supplier_support(state,3,[ITEM_B])[ITEM_B]
 LW.item_exchange_learn!(state,plan,D("status"=>"declined","us"=>201))
 @test LW.item_exchange_supplier_support(state,3,[ITEM_B])[ITEM_B]<before
 println(JSON3.write((calls=counts,supplier_probability=probability)))
end
const item_social_state! = LW.item_social_state!
const food_security=LW.food_security
const CHANNELS=Dict(ITEM_A=>(true,true))
learned_channel_plan!(args...;kwargs...)=nothing
@testset "history becomes actual directed call" begin
 f=item_fixture(objects=Any[]);state=supplier_state(1)
 for us in 1:8
  LW.item_exchange_learn!(state,D("exchange_give"=>bundle(1),"exchange_want"=>bundle(3),"partner"=>ITEM_B,"action"=>"item_accept","context"=>D("need"=>.5)),D("status"=>"exchanged","us"=>us))
 end
 view=item_view(f,ITEM_A)
 relation=D("identity_observation"=>D("names"=>D(ITEM_B=>"ハル")))
 map=D();LW.food_remember_taste!(map,3,2,.5,0)
 voice=configured_want_state((ITEM_A,ITEM_B,ITEM_C))
 plan=configured_want_plan!(voice,17_280_000_000,state,view,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],0;relation,map)
 @test plan["method"]=="voice_request_call"
 pending=voice["pending"][ITEM_A]
 @test pending["requested_food"]==3
 @test pending["addressee"] in (nothing,ITEM_B)
 @test pending["addressee"]===nothing || startswith(pending["event"].text,"ハル ")
 @test voice["records"][end]["supplier_support"][ITEM_B]>0
 @test !haskey(view,"observed_food_stocks")
 println(JSON3.write((text=pending["event"].text,addressee=pending["addressee"])))
end

@testset "author labels do not constrain learned tokens" begin
 vocabulary=configured_want_vocabulary()
 @test configured_want_word(vocabulary,8)=="塩焼き魚"
 labels=collect(CONFIGURED_WANT_WORDS);labels[8]="ポル"
 alternate=configured_want_vocabulary(;words=labels)
 @test configured_want_word(alternate,8)=="ポル"
 @test configured_want_word(ObservedVocabulary(),8)===nothing
 @test configured_want_appearance(8)==observed_word_prediction(alternate,"ポル").appearance
end
