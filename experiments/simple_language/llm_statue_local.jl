# 暫定固定: manually consult a statue with D's recorded day18 decision.
# No autonomous consultation, no returned advice injected into the simulation.
# Input is extracted predecision evidence, not the person's entire end-of-day MB.
using JSON3,Downloads
length(ARGS)==2 || error("usage: llm_statue_local.jl SAVED_DIALOGUE NEW_OUTPUT")
input_path,out=abspath.(ARGS)
ispath(out) && error("fresh output required")
haskey(ENV,"OPENAI_API_KEY") || error("API key missing")
rows=JSON3.read(read(input_path,String),Vector{Dict{String,Any}})
context=only(r["context"] for r in rows if r["context"]["source"]=="items:response:npc_d:293823000000")
# Never send the earlier generated dialogue, future outcome or another's MB.
instructions="あなたはゲーム世界の神の像です。訪れた個体の、その瞬間に想起されたMB関係と勾配だけが届きます。世界の真相や他者の内心、取引の未来は知りません。これは本人の発話を代行する仕事ではなく、像から本人へ応える仕事です。speaker_givesは相談者が渡す物、speaker_receivesは相談者が受け取る物。actionは本人が現在選んだ行動で、成功は未確定。勾配はgradient_axes順、前6項目がtotalを構成し、正は支持、負は抵抗、needは食料の予測不足。Hは未解消の予測差であり恐怖などの感情と同一視しない。recalled_MBのsamplesは参照経験数、fitは今回との照合度、probabilityは本人の予測で客観的成功率ではない。owner_forecastは本人の見積もり。未観測/nullは不明。根拠のない過去の出来事、性格、味、安全性、相手の意図を足さない。数値から別の見方や問いを一つ返し、必要なら慎重な助言を添える。命令や予言を避ける。MBや数値をそのまま読み上げず、落ち着いた像の口調で日本語150～250字程度。返答本文のみ。"
payload=(model="gpt-4.1-mini",store=false,max_output_tokens=600,instructions,input=JSON3.write(context))
mkpath(out)
write(joinpath(out,"request.json"),JSON3.write(payload))
buffer=IOBuffer();started=time()
response=Downloads.request("https://api.openai.com/v1/responses";method="POST",
 headers=["Authorization"=>"Bearer "*ENV["OPENAI_API_KEY"],"Content-Type"=>"application/json"],
 input=IOBuffer(JSON3.write(payload)),output=buffer,timeout=90)
response.status==200 || error("API HTTP $(response.status); no retry")
result=JSON3.read(String(take!(buffer)));result.status=="completed" || error("incomplete response")
reply=join([String(c.text) for o in result.output if o.type=="message" for c in o.content if c.type=="output_text"],"\n")
report=(source=context["source"],model=result.model,reply,usage=result.usage,elapsed_seconds=time()-started,simulation_modified=false)
write(joinpath(out,"completed.json"),JSON3.write(report))
println(JSON3.write(report))
