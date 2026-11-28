using JSON3, Serialization, SHA
length(ARGS)==3 || error("BASE OUTPUT DAY")
base=abspath(ARGS[1]); out=abspath(ARGS[2]); audit_day=parse(Int,ARGS[3])
ispath(out) && error("fresh output required")
mkpath(out); cp(joinpath(base,"source"),joinpath(out,"source"))
input=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any})
input["config"]["days"]=audit_day
write(joinpath(out,"input.json"),JSON3.write(input))
audit_identity=deepcopy(input);delete!(audit_identity["config"],"days")
root=joinpath(out,"source/src")
files=sort([joinpath(d,f) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl")])
oldcode=bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
path=joinpath(root,"lw/decision/item_social.jl");code=read(path,String)
tracepath=repr(joinpath(out,"trace.jsonl"))
anchor="    function candidate(other,give,want,gf,wf;offer_id=nothing,counter=false)"
hook="""
    function refusal_audit(stage, fields)
        state["actor"]=="npc_d" && now in (94033000000,141753000000) || return
        open($tracepath,"a") do io
            println(io,JSON3.write(D("us"=>now,"stage"=>stage,"fields"=>fields)))
        end
    end
    refusal_audit("context",D("available"=>available,"weights"=>weights,"security"=>security,"view"=>view,"use_model"=>use_model,"pending"=>mind["pending"]))
"""
@assert occursin(anchor,code)
code=replace(code,anchor=>hook*anchor*"\n        refusal_audit(\"candidate\",D(\"other\"=>other,\"give\"=>give,\"want\"=>want,\"gf\"=>gf,\"wf\"=>wf,\"counter\"=>counter))";count=1)
anchor="        gain===nothing && return"
code=replace(code,anchor=>"        refusal_audit(\"gain\",D(\"gain\"=>gain))\n"*anchor;count=1)
anchor="        subjective=gradient[\"total\"]"
code=replace(code,anchor=>anchor*"\n        refusal_audit(\"gradient\",D(\"gradient\"=>gradient,\"valuation\"=>valuation,\"trace\"=>trace,\"use_transition\"=>use_transition))";count=1)
write(path,code)
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
saved=checkpoint_load(joinpath(base,"checkpoints/day-"*lpad(string(audit_day-1),3,'0')*".jls"),audit_identity,oldcode,audit_day)
serialize(joinpath(out,"resume.jls"),merge(saved,(code=checkpoint_code_hash(),)))
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--resume-from",joinpath(out,"resume.jls")])

