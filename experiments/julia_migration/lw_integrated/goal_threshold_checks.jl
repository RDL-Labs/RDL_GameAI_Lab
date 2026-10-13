include(joinpath(@__DIR__,"native.jl"))
using Test

@testset "goal threshold bounds and unresolved alternatives" begin
    @test native_options(["out"])[2]["goal-switch-threshold"]=="2"
    @test native_options(["out","--goal-switch-threshold","3"])[2]["goal-switch-threshold"]=="3"
    for bad in (0,31,true,2.5)
        @test_throws ErrorException("goal_switch_threshold") lw_day(nothing,nothing;goal_switch_threshold=bad)
    end
    move=D("energy"=>D("rows"=>[D("ref"=>"0","cost"=>1.)]))
    fast=BasicLoop("food";threshold=1);slow=BasicLoop("food";threshold=3)
    for s in (fast,slow)
        choose_method!(s,search_candidates(move,nothing,s),"failed-scan")
        resolve_method!(s,"failed-scan",false,false)
    end
    @test length(search_candidates(move,nothing,fast))==2
    @test length(search_candidates(move,nothing,slow))==1
    @test fast.H==slow.H==1
end

out=ARGS[1]
native_main([joinpath(out,"threshold3"),"--days","1","--goal-switch-threshold","3"])
r=JSON3.read(read(joinpath(out,"threshold3","result.json"),String))
@testset "living goal threshold binding" begin
    @test all(n.threshold==3 for a in values(r.day_starts[1]) for n in values(a.loops))
end
native_main([joinpath(out,"replay"),"--spec",joinpath(out,"threshold3","spec.json")])
@test read(joinpath(out,"threshold3","result.json"))==read(joinpath(out,"replay","result.json"))


# A pre-option frozen spec must keep the original threshold2 behavior.
native_main([joinpath(out,"default"),"--days","1"])
legacy=JSON3.read(read(joinpath(out,"default","spec.json"),String),Dict{String,Any})
delete!(legacy["config"],"goal_switch_threshold")
legacy_path=joinpath(out,"legacy-spec.json")
write(legacy_path,JSON3.write(legacy))
native_main([joinpath(out,"legacy"),"--spec",legacy_path])
# Rebuilding a legacy config through Dict changes JSON key order, not values.
@test JSON3.read(read(joinpath(out,"default","result.json"),String),Dict{String,Any})==
      JSON3.read(read(joinpath(out,"legacy","result.json"),String),Dict{String,Any})
