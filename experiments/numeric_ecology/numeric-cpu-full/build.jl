include("NumericCore.jl")
using .NumericCore
const SOURCE=normpath(joinpath(@__DIR__,"../numeric-cpu/source"))
const DEST=joinpath(@__DIR__,"source")
const FILES=String[]
function discover(path)
    path=normpath(path)
    path in FILES && return
    push!(FILES,path)
    text=read(path,String)
    for m in eachmatch(r"include\(joinpath\(@__DIR__,\s*\"([^\"]+)\"\)\)",text)
        discover(joinpath(dirname(path),m[1]))
    end
end
discover(joinpath(SOURCE,"lw_integrated/run.jl"))
discover(joinpath(SOURCE,"lw_integrated/checks.jl"))
function preregister(x)
    x isa Symbol && register_symbol!(x)
    x isa QuoteNode && x.value isa Symbol && register_symbol!(x.value)
    x isa Expr && foreach(preregister,x.args)
end
function transform(x)
    x isa String && return :(NID($(nid(x).value)))
    x===:String && return :NID
    x===:AbstractString && return :NID
    x===:string && return :ncat
    x===:join && return :njoin
    x===:bytes2hex && return :nhex
    x isa Expr || return x
    if x.head==:const && x.args[1] isa Expr && x.args[1].args[1]===:IDS
        rhs=transform(x.args[1].args[2])
        return :(const IDS=Tuple($rhs[1:NumericCore.AGENT_COUNT[]]))
    end
    # Filesystem calls and CLI blocks belong to the external boundary.
    if x.head==:call && x.args[1]===:include; return x; end
    if x.head==:call && x.args[1]==:(JSON3.write) && length(x.args)==2
        return Expr(:call,:njson,transform(x.args[2]))
    end
    if x.head==:if && occursin("PROGRAM_FILE",sprint(show,x.args[1])); return nothing; end
    if x.head==:macrocall && occursin("@doc",string(x.args[1]))
        return Expr(x.head,x.args[1],x.args[2],x.args[3],transform(x.args[end]))
    end
    if x.head==:macrocall && occursin("@testset",string(x.args[1]))
        return Expr(x.head,x.args[1],x.args[2],x.args[3],map(transform,x.args[4:end])...)
    end
    if x.head==:string; return Expr(:call,:ncat,map(transform,x.args)...); end
    if x.head==:module
        body=transform(x.args[3])
        pushfirst!(body.args,:(using Main.NumericCore))
        return Expr(:module,x.args[1],x.args[2],body)
    end
    Expr(x.head,map(transform,x.args)...)
end
for path in FILES
    src=read(path,String)
    # Instrumentation is outside the simulation; keep no text pathname in state.
    if endswith(replace(path,'\\'=>'/'),"lw_day/run.jl")
        src=replace(src,"progress_path=get(ENV,\"LW_PROGRESS_PATH\",\"\")"=>"progress_path=nothing",
            "progress_io=isempty(progress_path) ? nothing : open(progress_path,\"a\")"=>"progress_io=nothing")
        src=replace(src,"    merge(lateral_side=="=>"    push!(NumericCore.AUDITS,NumericCore.audit(Base.@locals))\n    merge(lateral_side==")
    end
    ex=Meta.parseall(src); preregister(ex)
    generated=transform(ex)
    target=joinpath(DEST,relpath(path,SOURCE)); mkpath(dirname(target))
    open(target,"w") do io
        println(io,"# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.")
        println(io,"using Main.NumericCore")
        for item in generated.args
            item isa LineNumberNode && continue
            Base.show_unquoted(io,item)
            println(io)
        end
    end
end
open(joinpath(@__DIR__,"registry.jl"),"w") do io
    println(io,"# Numeric byte registry and schema-symbol metadata. No String-valued simulation data.")
    for b in NumericCore.BYTES
        println(io,"NumericCore.intern(",repr(b),")")
    end
    for (s,id) in sort(collect(NumericCore.SYMBOLS),by=p->p.second.value)
        println(io,"NumericCore.SYMBOLS[",repr(s),"]=NID(",id.value,")")
        println(io,"NumericCore.REVERSE_SYMBOLS[NID(",id.value,")]=",repr(s))
    end
end
write(joinpath(@__DIR__,"source-files.txt"),join(relpath.(FILES,Ref(SOURCE)),"\n"))
println("Generated ",length(FILES)," files; ",length(NumericCore.BYTES)," numeric labels.")
