using Test
include(joinpath(@__DIR__,"source","social_loop","run.jl"))
@testset "numeric storage with 30 agents" begin
    w=world(true)
    @test length(w.inventory.data)==30
    @test isbitstype(eltype(w.bodies.data))
    @test isbitstype(eltype(w.positions.data))
    for (i,a) in enumerate(IDS)
        @test w.inventory[i]==w.inventory[a]
        w.inventory[i]=i
        @test w.inventory[a]==i
        w.positions[i]=(Float64(i),0.)
        @test w.positions[a]==(Float64(i),0.)
    end
    clone=deepcopy(w)
    clone.inventory[1]=999
    @test w.inventory[1]==1
    @test_throws KeyError w.inventory["missing"]
    @test_throws BoundsError w.inventory[31]
    @test Dict(w.inventory)==Dict(a=>i for (i,a) in enumerate(IDS))
    plans=NumericPlans()
    @test_throws KeyError plans[IDS[1]]
    for action in ACTION_LABELS
        original=D("action"=>action,"purpose_family"=>"food","direction"=>2,"target"=>IDS[2])
        plans[IDS[1]]=original
        @test plans.actions[1] isa UInt16
        @test !haskey(plans.payloads[1],"action")
        @test plans[IDS[1]]==original
        @test original["action"]==action
    end
    @test_throws KeyError (plans[IDS[1]]=D("action"=>"unknown"))
end
