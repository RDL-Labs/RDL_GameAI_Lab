# Resume a frozen API experiment. Reconstruct unsaved external channel state by
# deterministic cached-response replay, then load the ORIGINAL daily checkpoint.
using JSON3,Serialization,SHA,Test
const BASE,OUTPUT=abspath(ARGS[1]),abspath(ARGS[2])
const STARTDAY=parse(Int,ARGS[3]);const END_DAY=parse(Int,ARGS[4])
const HERE=@__DIR__;const MODE="train";const LEARNED_CONTROL=true;const WANT_VOICE=false
ispath(OUTPUT) && error("fresh output required")
ENV["RDL_API_FIELD_TRAINING"]="1";ENV["RDL_API_DAILY_CALLS"]="480";ENV["RDL_API_TOTAL_CALLS"]="480"
ENV["RDL_ALTERNATE_E"]="0";ENV["RDL_NO_GESTURES"]="0"
haskey(ENV,"OPENAI_API_KEY") || (ENV["OPENAI_API_KEY"]=strip(read(`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('OPENAI_API_KEY','User')"`,String)))
mkpath(OUTPUT);cp(joinpath(BASE,"source"),joinpath(OUTPUT,"source"));cp(joinpath(BASE,"communication"),joinpath(OUTPUT,"communication"))
for file in ("api_transport.jl","api_trade_agent.jl")
    cp(joinpath(HERE,"../../src/lw/configured_paths",file),joinpath(OUTPUT,"source/src/lw/configured_paths",file);force=true)
end
include(joinpath(OUTPUT,"source/src/lw/configured_paths/api_trade_agent.jl"))
include(joinpath(OUTPUT,"source/src/lw/configured_paths/api_navigation.jl"))
include(joinpath(OUTPUT,"source/src/lw/configured_paths/api_field_training.jl"))
# Only transport differs in the frozen simulation; no repeated instrumentation.
bootstrap=read(joinpath(HERE,"cohort_run.jl"),String)
firstline=findfirst("include(joinpath(OUTPUT,\"source/integrations/lightweight_julia/native.jl\"))",bootstrap).start
lastline=findfirst("arguments=[joinpath(OUTPUT,\"run\")",bootstrap).start
include_string(Main,bootstrap[firstline:prevind(bootstrap,lastline)],joinpath(HERE,"api_resume_bootstrap.jl"))
const REPLAYING=Ref(true)
function normalize_replay(x)
    x isa AbstractDict && return Dict(String(k)=>normalize_replay(v) for (k,v) in pairs(x) if String(k)!="elapsed_seconds")
    x isa AbstractVector && return normalize_replay.(x)
    x
end
function replay_send(payload,label)
    if !REPLAYING[];return configured_api_http(payload);end
    diary=startswith(label,"diary-")
    number=split(label,"-")[end]
    request=joinpath(BASE,diary ? "diary-request-$number.json" : "api-request-$number.json")
    prior=JSON3.read(read(request,String),Dict{String,Any})
    current=JSON3.read(JSON3.write(payload),Dict{String,Any})
    prior["input"]=normalize_replay(JSON3.read(prior["input"],Dict{String,Any}))
    current["input"]=normalize_replay(JSON3.read(current["input"],Dict{String,Any}))
    @assert prior==current "cached request mismatch: $label"
    raw=if diary
        read(joinpath(BASE,"diary-response-$number.json"),String)
    else
        saved=JSON3.read(read(joinpath(BASE,"api-response-$number.json"),String))
        JSON3.write((status="completed",usage=saved.usage,output=[(type="message",content=[(type="output_text",text=saved.reply)])]))
    end
    (status=200,headers=Pair{String,String}[],body=raw)
end
# Adapter keeps live retry semantics; the reconstruction cannot call the service.
CONFIGURED_API_SEND_OVERRIDE[]=replay_send
input=JSON3.read(read(joinpath(BASE,"input.json"),String),Dict{String,Any})
input["config"]["days"]=STARTDAY
write(joinpath(OUTPUT,"input.json"),JSON3.write(input))
println("RECONSTRUCT through day $STARTDAY using cached responses only");flush(stdout)
native_main([joinpath(OUTPUT,"reconstruction"),"--spec",joinpath(OUTPUT,"input.json"),"--checkpoint-dir",joinpath(OUTPUT,"reconstructed-checkpoints")])
original_path=joinpath(BASE,"checkpoints","day-"*lpad(STARTDAY,3,'0')*".jls")
original=deserialize(original_path)
replayed=deserialize(joinpath(OUTPUT,"reconstructed-checkpoints","day-"*lpad(STARTDAY,3,'0')*".jls"))
for key in (:counts,:events,:daily,:stores,:cargo,:replenishments)
    @assert isequal(original.state[key],replayed.state[key]) "replay state mismatch: $key"
end
# Verify original source identity before explicitly migrating transport-only code.
root=joinpath(BASE,"source/src")
files=sort([joinpath(d,f) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl")])
oldcode=bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
checkpoint_load(original_path,replayed.identity,oldcode,END_DAY)
resume_path=joinpath(OUTPUT,"resume-day-$STARTDAY.jls")
serialize(resume_path,merge(original,(code=checkpoint_code_hash(),)))
serialize(joinpath(OUTPUT,"restored-external-state.bin"),(channels=CHANNEL_MEMORIES,history=CONFIGURED_API_HISTORY,memory=CONFIGURED_API_MEMORY[],calls=CONFIGURED_API_CALLS))
REPLAYING[]=false
input["config"]["days"]=END_DAY;write(joinpath(OUTPUT,"input.json"),JSON3.write(input))
println("RESUME original checkpoint day $STARTDAY through $END_DAY");flush(stdout)
elapsed=@elapsed native_main([joinpath(OUTPUT,"run"),"--spec",joinpath(OUTPUT,"input.json"),"--checkpoint-dir",joinpath(OUTPUT,"checkpoints"),"--resume-from",resume_path])
result=JSON3.read(read(joinpath(OUTPUT,"run/result.json"),String))
@test length(result.daily)==END_DAY
serialize(joinpath(OUTPUT,"communication_state.bin"),CHANNEL_MEMORIES)
write(joinpath(OUTPUT,"api-summary.json"),JSON3.write((calls=CONFIGURED_API_CALLS,memory=CONFIGURED_API_MEMORY[])))
write(joinpath(OUTPUT,"completed.json"),JSON3.write((days=length(result.daily),start_day=STARTDAY,elapsed_seconds=elapsed,trade_counts=result.portable_items.counts)))
println("COMPLETED ",elapsed)

