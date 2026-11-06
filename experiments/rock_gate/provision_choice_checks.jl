using Test, Serialization
include("../../src/lw/LW.jl")
const D=LW.D
const DAY=17_280_000_000
function fixture(seed=1;stock=60)
    map=D("daily_plan"=>LW.mb_daily_plan_state("actor",seed))
    security=LW.food_security_for!(map,nothing)
    LW.food_security_update!(security,nothing,LW.Body(10.,0.,85.,0.),nothing,[stock,0,0,0],Int[],0.,0,DAY)
    map,security
end
@testset "same food anxiety is shared with trading" begin
    map,security=fixture();relation=D()
    @test LW.food_security_for!(map,relation)===security
    @test LW.food_security(relation)===security
    relation["food_security"]["H"]=2.
    @test map["food_security"]["H"]==2.
    existing=D("food_security"=>LW.food_security_state());other=D()
    @test LW.food_security_for!(other,existing)===existing["food_security"]
    io=IOBuffer();serialize(io,(map,relation));seekstart(io);m,r=deserialize(io)
    @test m["food_security"]===r["food_security"]
end
@testset "stock and future shortage change outing probability" begin
    _,full=fixture();_,empty=fixture(;stock=0)
    loop=LW.BasicLoop("comparison";probabilistic=true)
    pfull=LW.method_distribution(loop,LW.food_provision_candidates(full))
    pempty=LW.method_distribution(loop,LW.food_provision_candidates(empty))
    @test pfull[2]>.9
    @test pempty[1]>pfull[1] && pempty[1]>.5
    @test all(>(0),pfull) && all(>(0),pempty)
    previous=deepcopy(full)
    LW.food_provision_candidates(full)
    @test full==previous # selection does not fabricate replenished stock
end
@testset "staying persists without fabricated success and can be reconsidered" begin
    chosen=nothing
    for seed in 1:64
        map,security=fixture(seed)
        if LW.food_provision_stay!(map,security,true,0,DAY)
            chosen=(map,security);break
        end
    end
    @test chosen!==nothing
    map,security=chosen
    @test map["daily_plan"]["active"]===nothing
    @test isempty(map["daily_plan"]["records"])
    for now in (1,1_000_000,64_000_000,DAY-1)
        @test LW.food_provision_stay!(map,security,true,now,DAY)
    end
    @test length(map["provision_choice"]["records"])==1
    LW.food_provision_stay!(map,security,true,DAY,DAY)
    @test length(map["provision_choice"]["records"])==2
    # Reconsider early when stock unexpectedly disappears, using the same forecast.
    map,security=chosen;map["provision_choice"]["choice"]="provision_stay"
    LW.food_security_update!(security,nothing,LW.Body(10.,0.,85.,0.),nothing,[0,0,0,0],Int[],20.,DAY+64_000_000,DAY)
    LW.food_provision_stay!(map,security,true,DAY+64_000_000,DAY)
    @test length(map["provision_choice"]["records"])==3
    @test last(map["provision_choice"]["records"])["H"]>0
    @test !LW.food_provision_stay!(map,security,false,DAY+65_000_000,DAY)
    map["daily_plan"]["active"]=D("deadline_us"=>3DAY)
    @test !LW.food_provision_stay!(map,security,true,2DAY,DAY)
end
