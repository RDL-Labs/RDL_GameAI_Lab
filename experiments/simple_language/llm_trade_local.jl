# Local rendering experiment: MB chooses/actions execute; LLM never authorizes assets.
# 暫定固定: fixture stocks, mutual encounter, seed=1, max 6 utterances.
# Replace encounter setup with normal perception integration later. API opt-in only.
using Downloads
include("../portable_items/checks.jl")
include("reply_trade.jl")
length(ARGS)==1 || error("usage: llm_trade_local.jl NEW_OUTPUT")
const LLM_OUTPUT=abspath(ARGS[1])
ispath(LLM_OUTPUT) && error("fresh output required")
haskey(ENV,"OPENAI_API_KEY") || error("API key missing")
mkpath(LLM_OUTPUT)
const LLM_MODEL="gpt-4.1-mini"
const LLM_FOOD_NAMES=("果実","肉","生ドングリ","加工ドングリ","生魚","腐敗食料","焼き魚","塩焼き魚")
food_terms(xs)=Dict(LLM_FOOD_NAMES[k]=>n for (k,n) in enumerate(xs) if n>0)
function render_utterance(context,history)
 instructions="あなたはゲーム個体の発話翻訳器です。MBが決めた今回の行動と提示条件だけを短い日本語1～2文にしてください。giveは自分が渡す物、wantは相手から受け取る物。数量を変えない。counterは逆提案、acceptは承諾、declineは拒否です。入力にない感情、理由、約束、相手の内心を足さない。過去の会話は参考のみで今回の条件を優先。発話だけを出力。"
 payload=JSON3.write((model=LLM_MODEL,store=false,max_output_tokens=220,instructions,
     input=JSON3.write((context,history))))
 output=IOBuffer();started=time()
 response=Downloads.request("https://api.openai.com/v1/responses";method="POST",
     headers=["Authorization"=>"Bearer "*ENV["OPENAI_API_KEY"],"Content-Type"=>"application/json"],
     input=IOBuffer(payload),output,timeout=90)
 response.status==200 || error("API HTTP $(response.status); no retry")
 result=JSON3.read(String(take!(output)))
 result.status=="completed" || error("incomplete API response")
 utterance=join([String(c.text) for o in result.output if o.type=="message" for c in o.content if c.type=="output_text"],"\n")
 (text=utterance,usage=result.usage,elapsed_seconds=time()-started)
end
function run_local()
 f=item_fixture(objects=Any[],food_counts=[[20,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,20],zeros(Int,8)],scene=(configured_negotiation=true,))
 empty!(f.w.obstacles);f.w.positions[ITEM_A]=(0.,0.);f.w.positions[ITEM_B]=(0.,.8);f.w.positions[ITEM_C]=(20.,20.)
 states=Dict(a=>LW.incidental_item_state(a,1) for a in (ITEM_A,ITEM_B))
 relations=Dict(a=>LW.social_relations_state(a;relational=true) for a in (ITEM_A,ITEM_B))
 initial=deepcopy(f.foods.personal);history=Any[];records=Any[];actor=ITEM_A
 for turn in 1:6
  now=turn*1_000_000;peer=actor==ITEM_A ? ITEM_B : ITEM_A
  # Explicit local encounter; no claim of running voice/person recognition here.
  identity=(status="recognized",handle=peer,bearing=actor==ITEM_A ? 0. : 180.)
  plan=reply_trade_plan!(f,actor,identity,states[actor],relations[actor],now;requested_food=actor==ITEM_A ? 8 : nothing)
  plan===nothing && break
  action=plan["action"]
  intent=action=="item_offer" ? "offer" : action=="item_counter" ? "counter" : action=="item_accept" ? "accept" : "decline"
  context=Dict("speaker"=>actor,"intent"=>intent,
      "give"=>food_terms(get(plan,"give_food",zeros(Int,8))),
      "want"=>food_terms(get(plan,"want_food",zeros(Int,8))))
  # Acceptance/refusal terms refer to the public incoming offer, never peer stock.
  if action in ("item_accept","item_decline") && haskey(plan,"offer_id") && haskey(f.s["offers"],plan["offer_id"])
   offer=f.s["offers"][plan["offer_id"]]
   context["give"]=food_terms(offer["want_food"]);context["want"]=food_terms(offer["give_food"])
  end
  generated=render_utterance(context,history)
  receipt=reply_trade_execute!(f,actor,states[actor],relations[actor],plan,now)
  push!(history,(speaker=actor,text=generated.text))
  push!(records,(turn,context,generated,action,status=receipt["status"],source=plan["source"],gradient=get(plan,"subjective_gain",nothing)))
  write(joinpath(LLM_OUTPUT,"dialogue.json"),JSON3.write(records))
  println(actor,": ",generated.text," [",receipt["status"],"]");flush(stdout)
  receipt["status"]=="offered" || break
  actor=peer
 end
 @test item_checks(f)===nothing
 @test sum(sum(v) for v in values(initial))==sum(sum(v) for v in values(f.foods.personal))
 write(joinpath(LLM_OUTPUT,"completed.json"),JSON3.write((calls=length(records),initial,final=f.foods.personal,counts=f.s["counts"],mode="MB decision with LLM rendering only")))
end
run_local()
