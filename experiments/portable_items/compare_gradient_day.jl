using JSON3, Test
length(ARGS)==2 || error("usage: compare_gradient_day.jl COMPARISON_ROOT ORIGINAL_RUN")
root,original=abspath.(ARGS)
loadjson(path)=JSON3.read(read(path),Dict{String,Any})
const OMIT=Set(["gradient_logging","gradient_maps","measurement","elapsed_seconds_including_compilation"])
clean(x::AbstractDict)=Dict(k=>clean(v) for (k,v) in x if !(k in OMIT))
clean(x::AbstractVector)=clean.(x)
clean(x)=x
on=loadjson(joinpath(root,"on/result.json"));off=loadjson(joinpath(root,"off/result.json"))
os=loadjson(joinpath(root,"on/summary.json"));fs=loadjson(joinpath(root,"off/summary.json"))
op=loadjson(joinpath(root,"on/provenance.json"));fp=loadjson(joinpath(root,"off/provenance.json"))
day=op["day"]
ReferenceDay=NamedTuple{(:physical,:counts),Tuple{Dict{String,Any},Dict{String,Any}}}
reference=JSON3.read(read(joinpath(original,"run/result.json")),NamedTuple{(:daily,),Tuple{Vector{ReferenceDay}}})
result_equal=isequal(clean(on),clean(off));summary_equal=isequal(clean(os),clean(fs))
reference_physical=isequal(on["daily"][1]["physical"],reference.daily[day].physical)
reference_counts=isequal(on["daily"][1]["counts"],reference.daily[day].counts)
@testset "same-checkpoint logging toggle parity" begin
    @test op["logging"]===true && fp["logging"]===false
    @test op["checkpoint_sha256"]==fp["checkpoint_sha256"]
    @test op["source_code_hash"]==fp["source_code_hash"]
    @test op["instrumentation_sha256"]==fp["instrumentation_sha256"]
    @test loadjson(joinpath(root,"on/input.json"))==loadjson(joinpath(root,"off/input.json"))
    @test length(on["daily"])==length(off["daily"])==1
    @test result_equal
    @test summary_equal
    @test reference_physical
    @test reference_counts
end
metrics=Dict(m=>merge(loadjson(joinpath(root,m,"metrics.json")),Dict(
    "process_timing"=>loadjson(joinpath(root,m*".timing.json")),
    "result_json_bytes"=>filesize(joinpath(root,m,"result.json")),
    "summary_json_bytes"=>filesize(joinpath(root,m,"summary.json")),
    "checkpoint_bytes"=>filesize(joinpath(root,m,"checkpoints","day-"*lpad(day,3,'0')*".jls")))) for m in ("on","off"))
evidence=Dict("day"=>day,"metrics"=>metrics,"provenance"=>Dict("on"=>op,"off"=>fp),
    "result_equal_excluding_diagnostics"=>result_equal,"summary_equal_excluding_diagnostics"=>summary_equal,
    "matches_original_physical"=>reference_physical,"matches_original_action_counts"=>reference_counts,
    "excluded_keys"=>sort(collect(OMIT)),"checks_passed"=>10)
write(joinpath(root,"comparison.json"),JSON3.write(evidence))
println(JSON3.write(evidence))
