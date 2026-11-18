# Read-only actual decision replay. No simulation mutations or automatic API retries.
# Usage: ROOT_CONTINUE20 NEW_OUTPUT. Explicit API opt-in via environment key.
using JSON3,Serialization,Downloads
length(ARGS)==2 || error("usage: llm_saved_trade.jl ROOT_CONTINUE20 NEW_OUTPUT")
root,out=abspath.(ARGS)
ispath(out) && error("fresh output required")
haskey(ENV,"OPENAI_API_KEY") || error("API key missing")
include(joinpath(root,"source/integrations/lightweight_julia/native.jl"))
saved=deserialize(joinpath(root,"checkpoints/day-018.jls")).state
mkpath(out)
names=("果実","肉","生ドングリ","加工ドングリ","生魚","腐敗食料","焼き魚","塩焼き魚")
terms(xs)=Dict(names[k]=>n for (k,n) in enumerate(xs) if n>0)
axes=["material","security","aid","relationship","waste_relief","cost","total","need_before","need_after"]
function compact_candidate(c)
 g=get(c,"compound_gradient",D())
 D("action"=>c["action"],"gradient"=>[get(g,k,nothing) for k in axes],
   "selection_probability"=>c["probability"],"expected"=>get(c,"expected",nothing),
   "selection_axes"=>["base","learned","repulsion","method_penalty","temperature","prior","log_weight"],
   "selection_vector"=>[get(c,k,nothing) for k in ("base","learned","repulsion","method_penalty","temperature","prior","log_weight")],
   "recalled_MB"=>get(c,"MB",nothing),"communication_prediction"=>get(c,"communication_prediction",nothing))
end
history=Any[];records=Any[]
for (actor,now) in (("npc_a",293822000000),("npc_d",293823000000),("npc_a",293824000000))
 row=only(filter(r->r["us"]==now,saved[:relations][actor]["gradient_maps"]["records"]))
 chosen=only(filter(c->c["method"]==row["selected"],row["candidates"]))
 t=chosen["terms"]
 context=D("speaker"=>actor,"partner"=>chosen["partner"],"action"=>chosen["action"],
  "speaker_gives"=>terms(t["give_food"]),"speaker_receives"=>terms(t["want_food"]),
  "gradient_axes"=>axes,"selected"=>compact_candidate(chosen),"H"=>row["H"],
  "owner_forecast"=>row["owner_forecast"],"observed_context"=>get(chosen,"observed_context",nothing),
  "alternatives"=>[compact_candidate(c) for c in row["candidates"] if c["method"]!=row["selected"]][1:min(2,length(row["candidates"])-1)],
  "candidate_count"=>row["candidate_count"],"source"=>row["source"])
 # Do not include outcomes, end-of-day MB updates, peer body/stock or future decisions.
 instructions="あなたは実際のゲーム個体のMB記録を解釈する発話翻訳器です。今回のspeaker本人として短い日本語1～2文を出力。speaker_givesは自分が相手へ渡す物、speaker_receivesは自分が受け取る物。履歴の話者と現在の話者を混同しない。item_offerは提示、item_counterは逆提案、item_acceptは承諾。数量・方向・行為を厳守。双方に同じ品があっても勝手に相殺しない。勾配の前6軸は合計totalの内訳。正は支持、負は抵抗。needは予測不足。MBのsamplesは過去経験、fitは照合度、probabilityは本人の予測で相手の内心ではない。learnedは選択の学習支持、repulsionは失敗反発、temperatureはHによる選択の拡散。nullは未観測。数値やMBという語は発話しない。数値から文脈を解釈して短い理由を含めてよいが、根拠のない好意・味経験・約束・事実を捏造しない。発話本文のみ。"
 payload=JSON3.write((model="gpt-4.1-mini",store=false,max_output_tokens=300,instructions,input=JSON3.write((context,history))))
 buffer=IOBuffer();started=time()
 response=Downloads.request("https://api.openai.com/v1/responses";method="POST",headers=["Authorization"=>"Bearer "*ENV["OPENAI_API_KEY"],"Content-Type"=>"application/json"],input=IOBuffer(payload),output=buffer,timeout=90)
 response.status==200 || error("API HTTP $(response.status)")
 result=JSON3.read(String(take!(buffer)));result.status=="completed" || error("incomplete response")
 speech=join([String(c.text) for o in result.output if o.type=="message" for c in o.content if c.type=="output_text"],"\n")
 push!(records,(context,speech,usage=result.usage,elapsed_seconds=time()-started))
 push!(history,(speaker=actor,text=speech))
 write(joinpath(out,"dialogue.json"),JSON3.write(records))
 println(actor,": ",speech);flush(stdout)
end
write(joinpath(out,"completed.json"),JSON3.write((calls=length(records),checkpoint=joinpath(root,"checkpoints/day-018.jls"),mode="saved predecision MB interpretation; no new simulation")))
