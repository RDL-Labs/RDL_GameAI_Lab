using Test
include("../src/learning/MemoryBlocks.jl")
include("../src/body/RDLBody.jl")
using .MemoryBlocks
using .RDLBody: Body

@testset "parent MB selects concrete body operation" begin
    calls=Int[]
    eat=LeafBlock(UInt32(1),s->s.stock>0 && s.body.reserve<80,s->1.,s->begin
        push!(calls,1)
        b=RDLBody.step(s.body,"eat",0)[1]
        (body=b,stock=s.stock-1)
    end)
    rest=LeafBlock(UInt32(2),s->s.body.strain>0,s->2.,s->begin
        push!(calls,2)
        (body=RDLBody.step(s.body,"rest",0)[1],stock=s.stock)
    end)
    parent=ParentBlock(100,[ParentBlock(10,[eat]),ParentBlock(20,[rest])])
    state=(body=Body(5.,.5,50.,0.),stock=1)
    a=execute(parent,state)
    @test a.path==UInt32[100,10,1]
    @test a.output.stock==0 && a.output.body.reserve==70.
    @test calls==[1] # Unselected children must not change the world.
    b=execute(parent,state;tracking=false)
    @test b.output==a.output && b.cost==a.cost && isempty(b.path)
    c=execute(parent,a.output)
    @test c.path==UInt32[100,20,2] && c.output.body.strain<a.output.body.strain
    @test execute(parent,(body=Body(10.,0.,100.,0.),stock=0)).status==:unavailable
    @test_throws ArgumentError execute(parent,state;maxdepth=2)
    invalid=LeafBlock(UInt32(3),s->true,s->NaN,identity)
    @test_throws ArgumentError execute(invalid,state)
end
