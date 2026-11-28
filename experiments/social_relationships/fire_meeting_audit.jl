# Read-only diagnostics via a separate frozen-source/checkpoint copy.
using JSON3, Serialization, SHA
length(ARGS)==2 || error("BASE OUTPUT")
const base=abspath(ARGS[1]);const out=abspath(ARGS[2])
ispath(out) && error("fresh output required");mkpath(out)
cp(joinpath(base,"source"),joinpath(out,"source"))
audit_input=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any})
audit_input["config"]["days"]=7
write(joinpath(out,"input.json"),JSON3.write(audit_input))
audit_identity=deepcopy(audit_input);delete!(audit_identity["config"],"days")
root=joinpath(out,"source/src")
files=sort([joinpath(d,f) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl")])
oldcode=bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
path=joinpath(root,"lw/simulation/day.jl");code=read(path,String)
anchor="        # Ordered action resolution: receipts are stamped at the end of this second."
@assert occursin(anchor,code)
tracepath=repr(joinpath(out,"trace.jsonl"))
hook="""
        if 93964000000<=now<=94094000000 || 107871000000<=now<=108001000000
            open($tracepath,"a") do io
                println(io,JSON3.write(D("us"=>now,"actors"=>D(a=>D(
                    "position"=>w.positions[a],"meeting"=>configured_camp_trade_state!(incidental_items[a])["meeting"],
                    "partners"=>[b for b in IDS if item_trade_contact(w,spec.home,a,b)],
                    "action"=>get(get(plans,a,D()),"action",nothing),"method"=>get(get(plans,a,D()),"method",nothing)) for a in IDS))))
            end
        end
"""
write(path,replace(code,anchor=>hook*anchor;count=1))
path=joinpath(root,"lw/configured_paths/camp_trade_calls.jl");code=read(path,String)
anchor="    channel=configured_camp_trade_state!(state);meeting=channel[\"meeting\"]"
planpath=repr(joinpath(out,"plan.jsonl"))
hook="""
    if meeting!==nothing && (93964000000<=now<=94094000000 || 107871000000<=now<=108001000000)
        open($planpath,"a") do io
            println(io,JSON3.write(D("us"=>now,"actor"=>state["actor"],"meeting"=>meeting,
                "partners"=>view===nothing ? nothing : view["trade_partners"],"allow_start"=>get(kwargs,:allow_start,true))))
        end
    end
"""
@assert occursin(anchor,code)
write(path,replace(code,anchor=>anchor*"\n"*hook;count=1))
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
saved=checkpoint_load(joinpath(base,"checkpoints/day-005.jls"),audit_identity,oldcode,7)
serialize(joinpath(out,"resume.jls"),merge(saved,(code=checkpoint_code_hash(),)))
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--resume-from",joinpath(out,"resume.jls")])
