using Test
D(ps...)=Dict{String,Any}(ps...)
check(ok,msg)=ok || error(msg)
include(joinpath(@__DIR__,"../lw_day/basic_loop.jl"))
# Standalone contract tests; no World required.
@testset "parent H controls finite candidate admission" begin
    s=BasicLoop("home")
    cs=[D("method"=>"m$i","priority"=>Float64(10-i),"question"=>"progress","action"=>"walk") for i in 1:8]
    before=deepcopy(cs)
    @test length(parent_candidates(s,cs))==2
    s.H=2;@test length(parent_candidates(s,cs))==4
    s.H=4;@test parent_candidates(s,cs)===cs
    s.H=0
    choose_method!(s,[cs[8]],"used")
    resolve_method!(s,"used",true,nothing)
    @test first(parent_candidates(s,cs))["method"]=="m8"
    snapshot=deepcopy(loop_snapshot(s))
    @test all(c in cs for c in parent_candidates(s,cs))
    @test loop_snapshot(s)==snapshot && cs==before
    @test isempty(parent_candidates(s,Any[]))
    @test parent_candidates(s,[cs[1]])==[cs[1]]
    s.H=32;s.threshold=30;@test parent_candidates(s,cs)===cs
    s.threshold=2;s.H=4
    choose_method!(s,cs,"success");resolve_method!(s,"success",true,true)
    @test length(parent_candidates(s,cs))==2
    s.H=0
    for i in 1:4
        p=choose_method!(s,parent_candidates(s,cs),"failure:$i")
        resolve_method!(s,"failure:$i",false,false)
    end
    @test parent_candidates(s,cs)===cs
end
