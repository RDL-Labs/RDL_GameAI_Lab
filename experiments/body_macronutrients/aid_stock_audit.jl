using JSON3, Serialization, SHA
base=ARGS[1];out=ARGS[2];mkpath(out);cp(joinpath(base,"source"),joinpath(out,"source"))
x=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any});x["config"]["days"]=37
write(joinpath(out,"input.json"),JSON3.write(x));ident=deepcopy(x);delete!(ident["config"],"days")
root=joinpath(out,"source/src");files=sort([joinpath(d,f) for(d,_,fs)in walkdir(root) for f in fs if endswith(f,".jl")]);old=bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
p=joinpath(root,"lw/simulation/day.jl");code=read(p,String);anchor="        # Ordered action resolution: receipts are stamped at the end of this second."
hook="""
        if any(t->abs(now-t)<=2000000,(609345000000,611123000000,632029000000,633498000000))
            open($(repr(joinpath(out,"trace.jsonl"))),"a") do io
                println(io,JSON3.write(D("us"=>now,"actors"=>D(a=>D("position"=>w.positions[a],"inventory"=>foods.inventory[a],"stock"=>foods.personal[a],"plan"=>get(plans,a,nothing)) for a in IDS))))
            end
        end
"""
@assert occursin(anchor,code);write(p,replace(code,anchor=>hook*anchor;count=1))
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
c=checkpoint_load(joinpath(base,"checkpoints/day-035.jls"),ident,old,37)
serialize(joinpath(out,"resume.jls"),merge(c,(code=checkpoint_code_hash(),)))
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--resume-from",joinpath(out,"resume.jls")])

