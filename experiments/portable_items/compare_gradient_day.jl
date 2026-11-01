using JSON3, Test, SHA
length(ARGS) in (2,3,4) || error("usage: compare_gradient_day.jl COMPARISON_ROOT ORIGINAL_RUN [trade-preparation|trade-fit-materials [BASELINE_SOURCE]]")
const preparation=length(ARGS)>=3
preparation && !(ARGS[3] in ("trade-preparation","trade-fit-materials")) && error("invalid comparison mode")
preparation && ARGS[3]=="trade-fit-materials" && length(ARGS)!=4 && error("baseline source required")
root,original=abspath.(ARGS[1:2])
const baseline_source=length(ARGS)==4 ? abspath(ARGS[4]) : joinpath(original,"source")
const modes=preparation ? ("before","after") : ("on","off")
loadjson(path)=JSON3.read(read(path),Dict{String,Any})
const OMIT=Set(preparation ? ["measurement","elapsed_seconds_including_compilation"] :
    ["gradient_logging","gradient_maps","measurement","elapsed_seconds_including_compilation"])
clean(x::AbstractDict)=Dict(k=>clean(v) for (k,v) in x if !(k in OMIT))
clean(x::AbstractVector)=clean.(x)
clean(x)=x
on=loadjson(joinpath(root,modes[1],"result.json"));off=loadjson(joinpath(root,modes[2],"result.json"))
os=loadjson(joinpath(root,modes[1],"summary.json"));fs=loadjson(joinpath(root,modes[2],"summary.json"))
op=loadjson(joinpath(root,modes[1],"provenance.json"));fp=loadjson(joinpath(root,modes[2],"provenance.json"))
day=op["day"]
ReferenceDay=NamedTuple{(:physical,:counts),Tuple{Dict{String,Any},Dict{String,Any}}}
reference=JSON3.read(read(joinpath(original,"run/result.json")),NamedTuple{(:daily,),Tuple{Vector{ReferenceDay}}})
result_equal=isequal(clean(on),clean(off));summary_equal=isequal(clean(os),clean(fs))
reference_physical=isequal(on["daily"][1]["physical"],reference.daily[day].physical)
reference_counts=isequal(on["daily"][1]["counts"],reference.daily[day].counts)
@testset "same-checkpoint replay parity" begin
    @test op["logging"]===true && fp["logging"]===preparation
    @test op["checkpoint_sha256"]==fp["checkpoint_sha256"]
    @test op["source_code_hash"]==fp["source_code_hash"]
    @test op["instrumentation_sha256"]==fp["instrumentation_sha256"]
    @test loadjson(joinpath(root,modes[1],"input.json"))==loadjson(joinpath(root,modes[2],"input.json"))
    @test length(on["daily"])==length(off["daily"])==1
    @test result_equal
    @test summary_equal
    @test reference_physical
    @test reference_counts
    if preparation
        @test op["overlay_sha256"]!=fp["overlay_sha256"]
        @test all(h==bytes2hex(sha256(read(joinpath(baseline_source,p)))) for (p,h) in op["overlay_sha256"])
    end
end
metrics=Dict(m=>merge(loadjson(joinpath(root,m,"metrics.json")),Dict(
    "process_timing"=>loadjson(joinpath(root,m*".timing.json")),
    "result_json_bytes"=>filesize(joinpath(root,m,"result.json")),
    "summary_json_bytes"=>filesize(joinpath(root,m,"summary.json")),
    "checkpoint_bytes"=>filesize(joinpath(root,m,"checkpoints","day-"*lpad(day,3,'0')*".jls")))) for m in modes)
evidence=Dict("day"=>day,"metrics"=>metrics,"provenance"=>Dict(modes[1]=>op,modes[2]=>fp),
    "comparison_mode"=>preparation ? ARGS[3] : "logging-toggle","gradient_logs_compared"=>preparation,
    "result_equal_excluding_diagnostics"=>result_equal,"summary_equal_excluding_diagnostics"=>summary_equal,
    "matches_original_physical"=>reference_physical,"matches_original_action_counts"=>reference_counts,
    "excluded_keys"=>sort(collect(OMIT)),"checks_passed"=>preparation ? 12 : 10)
write(joinpath(root,"comparison.json"),JSON3.write(evidence))
println(JSON3.write(evidence))
