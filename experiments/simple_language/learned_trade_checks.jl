include("../portable_items/checks.jl")
include("trade_observation.jl")
include("role_probe.jl")
include("trade_channels.jl")
include("learned_trade.jl")

# Fixed controlled observations, not a learned speaking policy. Same arbitrary
# expression is paired with different visible outcomes in separate histories.
function controlled_history(successes,failures)
 memory=RoleExperience()
 for i in 1:successes+failures
  role_learn!(memory,(id="history:$i",text="ナモ",motion="g"),"object-presented",
   i<=successes ? "object-transferred" : "object-withdrawn")
 end
 memory
end
const CUE=(id="current",text="ナモ",motion="g")
function decision_case(history;cue=CUE,seed=1,unfair=false,binding=:valid,attending=true,hearing=true)
 f=item_fixture(objects=Any[],food_counts=unfair ? [[1,0,0,0],[0,0,0,20],[0,0,0,0]] : [[20,0,0,0],[0,0,0,20],[0,0,0,0]],scene=(configured_negotiation=true,))
 offered=item_act(f,ITEM_B,"item_offer",0;target=ITEM_A,
  give_food=unfair ? [0,0,0,0] : [0,0,0,1],want_food=[1,0,0,0])
 @assert offered["status"]=="offered"
 # Offer terms have already arrived. Vary hearing of the additional expression,
 # not the legacy offer delivery itself, so the decision inputs remain matched.
 trade_view=item_view(f,ITEM_A;now=1,open_stores=true)
 f.w.hearing[ITEM_A]=hearing
 observation=role_public_observation(f.w,ITEM_A,0.,(id=cue.id,actor=ITEM_B,role=:initiative,text=cue.text,motion=cue.motion,appearances=String[]);attending)
 communication=history===nothing ? nothing : learned_trade_evidence(history,observation,"object-presented",ITEM_B,offered["offer_id"],0,100)
 if communication!==nothing
  binding==:wrong_partner && (communication["partner"]=ITEM_C)
  binding==:wrong_offer && (communication["offer_id"]="another-offer")
  binding==:expired && (communication["expires_us"]=1)
  binding==:future && (communication["observed_us"]=2)
 end
 state=LW.incidental_item_state(ITEM_A,seed)
 relation=LW.social_relations_state(ITEM_A;relational=true)
 plan=LW.item_social_plan!(state,trade_view,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1;
  relation,communication)
 captured=last(relation["gradient_maps"]["records"])
 (fixture=f,state=state,plan=plan,record=captured,communication=communication)
end
acceptance(case)=only(filter(c->c["action"]=="item_accept",case.record["candidates"]))
rows=Any[]
@testset "learned expressions enter existing trade selection" begin
 histories=Dict("unknown"=>RoleExperience(),"positive"=>controlled_history(8,0),"negative"=>controlled_history(0,8),"ambiguous"=>controlled_history(4,4))
 baseline=decision_case(nothing)
 unknown=decision_case(histories["unknown"])
 @test unknown.plan==baseline.plan
 @test LW.loop_snapshot(unknown.state["social"]["response"])==LW.loop_snapshot(baseline.state["social"]["response"])
 evaluations=Dict(name=>decision_case(history) for (name,history) in histories)
 positive=acceptance(evaluations["positive"]);negative=acceptance(evaluations["negative"]);ambiguous=acceptance(evaluations["ambiguous"])
 @test positive["probability"]>ambiguous["probability"]>negative["probability"]
 @test positive["compound_gradient"]==negative["compound_gradient"]==ambiguous["compound_gradient"]
 @test negative["communication_prediction"]["probability"]≈.2
 @test ambiguous["communication_prediction"]["probability"]≈.6
 @test positive["communication_prediction"]["probability"]==1.
 for binding in (:wrong_partner,:wrong_offer,:expired,:future)
  @test decision_case(histories["negative"];binding).plan==baseline.plan
 end
 @test decision_case(histories["negative"];attending=false).plan==baseline.plan
 @test decision_case(histories["negative"];hearing=false,cue=(id="current",text="ナモ",motion=nothing)).plan==baseline.plan
 for cue in ((id="current",text="ナモ",motion=nothing),(id="current",text="",motion="g"))
  single=decision_case(histories["negative"];cue)
  @test single.plan["action"]==evaluations["negative"].plan["action"]
  @test acceptance(single)["probability"]==negative["probability"]
  @test acceptance(single)["communication_prediction"]["failures"]==8 # not 16 for paired channels
 end
 @test learned_trade_evidence(histories["positive"],nothing,"object-presented",ITEM_B,"o",0,100)===nothing
 @test learned_trade_evidence(histories["positive"],CUE,"different-context",ITEM_B,"o",0,100)===nothing
 @test learned_trade_evidence(histories["positive"],(id="current",text="",motion=nothing),"object-presented",ITEM_B,"o",0,100)===nothing
 snapshot=deepcopy(histories["negative"].receipts)
 decision_case(histories["negative"])
 @test histories["negative"].receipts==snapshot # prediction does not learn its own result
 bad=decision_case(histories["positive"];unfair=true)
 @test all(c->c["action"]!="item_accept",bad.record["candidates"])
 @test any(c->c["action"]=="item_counter",bad.record["candidates"])
 @test all(c->!haskey(c,"compound_gradient") || c["compound_gradient"]["total"]>=-.01,bad.record["candidates"])
 # Inspect the full frozen candidate gradient, not only a sampled action.
 for (name,case) in evaluations
  row=acceptance(case)
  push!(rows,(case=name,action=case.plan["action"],accept_probability=row["probability"],
   expected=row["expected"],communication=get(row,"communication_prediction",nothing),gradient=row["compound_gradient"]))
 end
 # Repeated identical seeds across histories, with fresh physical and MB state.
 changes=Int[]
 for seed in 1:64
  base=decision_case(nothing;seed);changed=decision_case(histories["negative"];seed)
  base.plan["action"]!=changed.plan["action"] && push!(changes,seed)
 end
 @test !isempty(changes)
 push!(rows,(case="paired_seed_sweep",seeds=64,changed_actions=length(changes),changed_seeds=changes))
 # Real execution still needs consent and ownership, and records actual outcome.
 executed=evaluations["positive"];plan=executed.plan
 if plan["action"]=="item_accept"
  receipt=item_act(executed.fixture,ITEM_A,"item_accept",1;offer_id=plan["offer_id"])
  LW.item_social_executed!(executed.state,plan,receipt)
  @test receipt["status"]=="exchanged"
  @test item_checks(executed.fixture)===nothing
  @test executed.fixture.foods.personal[ITEM_A][4]==1
 else
  @test plan["action"]=="item_decline" # no forced choice for a favorable signal
 end
 if !isempty(ARGS)
  learned=deserialize(joinpath(abspath(ARGS[1]),"communication_state.bin"))["npc_e"].roles
  for cue in ((id="new-live",text="モ",motion=nothing),(id="new-live",text="",motion="present"),(id="new-live",text="モ",motion="present"))
   case=decision_case(learned;cue)
   row=acceptance(case)
   @test haskey(row,"communication_prediction")
   push!(rows,(case="newcomer_E_learned",cue=cue,action=case.plan["action"],accept_probability=row["probability"],
    expected=row["expected"],communication=row["communication_prediction"]))
  end
 end
end
write(joinpath(@__DIR__,"learned_trade_result.json"),JSON3.write(rows))
