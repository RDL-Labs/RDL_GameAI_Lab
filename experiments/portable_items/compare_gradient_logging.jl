using JSON3, SHA, Test
length(ARGS)==1 || error("usage: compare_gradient_logging.jl COMPARISON_ROOT")
root=abspath(ARGS[1])
loadjson(path)=JSON3.read(read(path),Dict{String,Any})
# Diagnostic evidence and its switch are excluded; learned MBs remain compared.
const EXCLUDED=Set(["gradient_maps","gradient_logging","measurement","elapsed_seconds_including_compilation"])
function differences(a,b,path="",out=String[])
    length(out)>=50 && return out
    if a isa AbstractDict && b isa AbstractDict
        ak=setdiff(Set(keys(a)),EXCLUDED);bk=setdiff(Set(keys(b)),EXCLUDED)
        ak==bk || push!(out,path*": keys differ")
        for k in sort(collect(intersect(ak,bk)));differences(a[k],b[k],path*"/"*k,out);end
    elseif a isa AbstractVector && b isa AbstractVector
        length(a)==length(b) || push!(out,path*": lengths differ")
        for i in 1:min(length(a),length(b));differences(a[i],b[i],path*"/"*string(i),out);end
    elseif !isequal(a,b)
        push!(out,path*": values differ")
    end
    out
end
function source_hashes(dir)
    Dict(relpath(joinpath(d,f),dir)=>bytes2hex(sha256(read(joinpath(d,f))))
        for (d,_,fs) in walkdir(dir) for f in fs if endswith(f,".jl"))
end
inputs=[loadjson(joinpath(root,m*".input.json")) for m in ("on","off")]
results=[loadjson(joinpath(root,m,"run/result.json")) for m in ("on","off")]
summaries=[loadjson(joinpath(root,m,"run/summary.json")) for m in ("on","off")]
input_diffs=differences(inputs...)
result_diffs=differences(results...)
summary_diffs=differences(summaries...)
sources_equal=source_hashes(joinpath(root,"on/source"))==source_hashes(joinpath(root,"off/source"))
metrics=Dict(m=>Dict("measurement"=>s["measurement"],
    "process_timing"=>loadjson(joinpath(root,m*".timing.json")),
    "result_json_bytes"=>filesize(joinpath(root,m,"run/result.json")),
    "summary_json_bytes"=>filesize(joinpath(root,m,"run/summary.json")),
    "last_checkpoint_bytes"=>filesize(joinpath(root,m,"checkpoints/day-003.jls")),
    "checkpoint_total_bytes"=>sum(filesize(joinpath(root,m,"checkpoints",f)) for f in readdir(joinpath(root,m,"checkpoints"))),
    "gradient_records"=>Dict(a=>haskey(r,"gradient_maps") ?
        Dict("captured"=>r["gradient_maps"]["captured"],"retained"=>length(r["gradient_maps"]["records"])) :
        Dict("captured"=>0,"retained"=>0) for (a,r) in s["social_relationships"]),
    "agents"=>Dict(a=>Dict("body"=>r["body"],"stock"=>r["stock"],"operations"=>r["operations"]) for (a,r) in s["agents"]),
    "item_counts"=>s["portable_items"]["counts"],"food_counts"=>s["food_exchange"]["world"]["counts"])
    for (m,s) in zip(("on","off"),summaries))
evidence=Dict("input_differences_excluding_log_flag"=>input_diffs,"sources_equal"=>sources_equal,
    "result_differences_excluding_diagnostics"=>result_diffs,"summary_differences_excluding_diagnostics"=>summary_diffs,
    "excluded_keys"=>sort(collect(EXCLUDED)),"metrics"=>metrics)
write(joinpath(root,"comparison.json"),JSON3.write(evidence))
@testset "gradient logging ON/OFF three-day parity" begin
    @test inputs[1]["scene"]["gradient_logging"]===true
    @test inputs[2]["scene"]["gradient_logging"]===false
    @test inputs[1]["config"]["days"]==inputs[2]["config"]["days"]==3
    @test isempty(input_diffs)
    @test sources_equal
    @test isempty(result_diffs)
    @test isempty(summary_diffs)
end
println(JSON3.write(evidence))
