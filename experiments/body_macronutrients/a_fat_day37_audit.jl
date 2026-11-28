using JSON3, Serialization, SHA
base=ARGS[1];out=ARGS[2];mkpath(out);cp(joinpath(base,"source"),joinpath(out,"source"))
x=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any});x["config"]["days"]=37
write(joinpath(out,"input.json"),JSON3.write(x));ident=deepcopy(x);delete!(ident["config"],"days")
root=joinpath(out,"source/src");files=sort([joinpath(d,f) for(d,_,fs)in walkdir(root) for f in fs if endswith(f,".jl")]);old=bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
p=joinpath(root,"lw/simulation/day.jl");code=read(p,String);anchor="        # Ordered action resolution: receipts are stamped at the end of this second."
hook="""
        if now % 60000000 == 0
            audit_body=w.bodies["npc_a"].nutrients
            open($(repr(joinpath(out,"trace.jsonl"))),"a") do io
                println(io,JSON3.write(D("us"=>now,"body"=>RDLBody.Macronutrients.body_snapshot(audit_body,RDLBody.MACRO_PARAMETERS),"position"=>w.positions["npc_a"],"plan"=>D(k=>get(get(plans,"npc_a",D()),k,nothing) for k in ("action","method","configured_rule")))))
            end
        end
"""
@assert occursin(anchor,code);write(p,replace(code,anchor=>hook*anchor;count=1))
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
c=checkpoint_load(joinpath(base,"checkpoints/day-036.jls"),ident,old,37)
serialize(joinpath(out,"resume.jls"),merge(c,(code=checkpoint_code_hash(),)))
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--resume-from",joinpath(out,"resume.jls")])
