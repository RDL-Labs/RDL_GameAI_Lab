using Test
include("../src/lw/LW.jl")
include("../src/learning/MemoryBlocks.jl")
using .MemoryBlocks

@testset "memory and memory-free policies share one world" begin
    w=LW.world(true)
    for actor in LW.IDS
        w.inventory[actor]=1
        w.bodies[actor]=LW.Body(10.,0.,50.,0.)
    end
    feed=LeafBlock(UInt32(1),o->o["inventory"]>0 && o["body"]["reserve"]<80,o->0.,o->(action="eat",))
    wait=LeafBlock(UInt32(2),o->true,o->1.,o->(action="wait",))
    hierarchy=ParentBlock(100,[feed,wait])
    memories=UInt32[]
    learned=LW.StatefulPolicy((memory,o)->begin
        result=execute(hierarchy,o)
        append!(memory,result.path)
        result.output
    end,memories)
    simple=LW.StatelessPolicy(o->(action=o["inventory"]>0 && o["body"]["reserve"]<80 ? "eat" : "wait",))
    policies=Dict("npc_a"=>learned,"npc_b"=>simple,"npc_c"=>simple)
    first=LW.step_policies!(w,policies,0)
    @test w.consumed==3 && sum(values(w.inventory))==0
    @test all(b->b.reserve==70.,values(w.bodies))
    @test memories==UInt32[100,1]
    @test !hasproperty(simple,:memory)
    second=LW.step_policies!(w,policies,1)
    @test w.consumed==3 && w.seconds==2
    @test memories==UInt32[100,1,100,2]
    @test all(r->r["status"]=="wait",values(second))
    @test_throws ArgumentError LW.step_policies!(w,policies,0)
end
