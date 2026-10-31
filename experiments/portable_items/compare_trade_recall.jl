using JSON3, Test
length(ARGS)==2 || error("usage: compare_trade_recall.jl BEFORE_DIR AFTER_DIR")
before,after=ARGS
@testset "planner results, state, relation and RNG parity" begin
    b=JSON3.read(read(joinpath(before,"decisions.json")),Vector{Dict{String,Any}})
    a=JSON3.read(read(joinpath(after,"decisions.json")),Vector{Dict{String,Any}})
    @test length(b)==length(a)==6
    for (x,y) in zip(b,a);@test isequal(x,y);end
    bp=JSON3.read(read(joinpath(before,"parity.json")),Vector{Dict{String,Any}})
    ap=JSON3.read(read(joinpath(after,"parity.json")),Vector{Dict{String,Any}})
    @test length(bp)==length(ap)==24
    for (x,y) in zip(bp,ap);@test isequal(x,y);end
end
b=JSON3.read(read(joinpath(before,"timings.json")));a=JSON3.read(read(joinpath(after,"timings.json")))
println(JSON3.write([(actor=x.actor,mode=x.mode,before_seconds=x.median_seconds,after_seconds=y.median_seconds,
    speedup=x.median_seconds/y.median_seconds,before_bytes=x.median_bytes,after_bytes=y.median_bytes) for (x,y) in zip(b,a)]))
