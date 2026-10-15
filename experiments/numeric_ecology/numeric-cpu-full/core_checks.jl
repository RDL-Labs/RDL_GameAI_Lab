using Test, SHA, JSON3
include("NumericCore.jl")
using .NumericCore
include("registry.jl")
@testset "numeric identity and exact boundary behavior" begin
    @test isbitstype(NID)
    @test sizeof(NID)==8
    @test nid("grass")==nid("grass")
    @test nid("grass")!=nid("water")
    @test decode(nid("草・兎"))=="草・兎"
    @test decode.(sort(nid.(["2","10","a","A"])))==sort(["2","10","a","A"])
    for x in (0,1,-1,17280000000,typemin(Int),typemax(Int))
        @test decode(nid(x))==string(x)
    end
    @test parse(Int,nid("17280"))==17280
    @test parse(Int,nid(string(typemin(Int))))==typemin(Int)
    @test_throws ArgumentError parse(Int,nid("1x"))
    @test_throws OverflowError parse(Int8,nid("999"))
    @test decode(ncat(nid("op:"),123,nid(":npc_a")))=="op:123:npc_a"
    @test startswith(nid("ground_123"),nid("ground_"))
    @test !startswith(nid("ground"),nid("ground_"))
    @test endswith(nid("abc123"),nid("123"))
    @test occursin('/',nid("inherited/npc_a"))
    @test decode.(split(nid("1,-2"),','))==["1","-2"]
    @test decode(njoin(nid.(["a","b"]),nid(",")))=="a,b"
    @test sha256(nid("request:123:npc_a:npc_b"))==sha256("request:123:npc_a:npc_b")
    @test decode(nhex(sha256(nid("seed")))[1:16])==bytes2hex(sha256("seed"))[1:16]
    plain=Any["npc_a:food-sufficiency",Any["x",false,1],"return","step_2",Any["walk",2,nothing]]
    @test decode(njson(encode(plain)))==JSON3.write(plain)
    @test JSON3.read(decode(njson(nid("quote\" slash\\ newline\n"))))=="quote\" slash\\ newline\n"
    @test decode(njson(nid("\b\t\n\f\r\u0001")))==JSON3.write("\b\t\n\f\r\u0001")
    obj=encode(JSON3.read("{\"name\":\"grass\",\"samples\":[\"a\",2]}"))
    @test audit(obj)==0
    @test audit((Dict(nid("x")=>"accidental string"),))==1
    @test audit(NumericCore.BYTES)==0
end
