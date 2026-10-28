# Reuse the resource fixture and the existing 84 food/digestion regressions.
include("../acorn_food/checks.jl")

# The fixture keeps the legacy scalar/cargo fields alongside typed resources,
# just as the simulation adapter does. Resource operations use production code.
function store_personally!(f,actor)
    amount=f.w.inventory[actor]
    LW.food_deposit!(f.r,actor,false)
    f.stores[actor]+=amount;f.w.inventory[actor]=0;empty!(f.cargo[actor])
end
function take_personally!(f,actor)
    kind=LW.food_retrieve!(f.r,actor,false,nothing,f.w.bodies[actor].reserve)
    f.stores[actor]-=1;f.w.inventory[actor]+=1;push!(f.cargo[actor],nothing)
    kind
end

@testset "private stores cannot supply another owner" begin
    f=fixture(kinds=[[B.RAW_ACORN,B.FRUIT_FOOD],Int[],[B.FRUIT_FOOD]])
    store_personally!(f,A);store_personally!(f,C)
    @test f.r.personal[A]==[1,0,1,0] && f.r.personal[C]==[1,0,0,0]
    @test audit(f)===nothing
    before=LW.food_snapshot(f.r)
    @test LW.configured_food_preparation(f.r,OTHER,true,true,true,f.stores[OTHER])===nothing
    @test_throws ErrorException take_personally!(f,OTHER)
    @test LW.food_snapshot(f.r)==before && f.w.inventory[OTHER]==0 && f.stores[OTHER]==0
    @test take_personally!(f,A)==B.FRUIT_FOOD
    @test f.r.personal[A]==[0,0,1,0] && f.r.personal[C]==before["personal"][C]
    @test f.r.shared==before["shared"] && f.r.personal[OTHER]==before["personal"][OTHER]
    @test take_personally!(f,C)==B.FRUIT_FOOD
    @test f.r.personal[A]==[0,0,1,0] && f.r.inventory[C]==[B.FRUIT_FOOD]
    @test audit(f)===nothing
end

@testset "warehouse food changes owner only after an explicit handover" begin
    f=fixture(kinds=[[B.FRUIT_FOOD],Int[],Int[]])
    store_personally!(f,A)
    request=LW.communicate!(f.w,OTHER,"private-request","request",A)
    @test request["status"]=="expressed"
    before=LW.food_snapshot(f.r)
    unavailable=LW.communicate!(f.w,A,"before-retrieval","give",OTHER,OTHER*":private-request")
    @test unavailable["status"]=="unavailable" # give cannot pull straight from a warehouse
    @test LW.food_snapshot(f.r)==before && f.w.inventory[OTHER]==0
    @test take_personally!(f,A)==B.FRUIT_FOOD
    receipt=LW.communicate!(f.w,A,"after-retrieval","give",OTHER,OTHER*":private-request")
    @test receipt["status"]=="transferred"
    push!(f.cargo[OTHER],popfirst!(f.cargo[A]))
    push!(f.r.inventory[OTHER],LW.food_remove!(f.r,A,1))
    @test f.r.inventory[OTHER]==[B.FRUIT_FOOD] && isempty(f.r.inventory[A])
    @test audit(f)===nothing
    store_personally!(f,OTHER)
    @test f.r.personal[OTHER]==[1,0,0,0] && f.stores[OTHER]==1 && f.stores[A]==0
    before=LW.food_snapshot(f.r)
    @test_throws ErrorException take_personally!(f,A)
    @test LW.food_snapshot(f.r)==before && audit(f)===nothing
end

@testset "private raw food and partial processing survive serialization" begin
    f=fixture(kinds=[[B.RAW_ACORN,B.RAW_ACORN],[B.FRUIT_FOOD],Int[]])
    store_personally!(f,A);store_personally!(f,OTHER)
    @test take_personally!(f,A)==B.RAW_ACORN
    @test LW.configured_food_preparation(f.r,A,true,true,true,f.stores[A])=="process_food"
    for _ in 1:37;LW.food_process!(f.r,A);end
    restored=saved_copy(f)
    @test LW.food_snapshot(restored.r)==LW.food_snapshot(f.r)
    @test restored.r.progress[A]==(UInt8(B.RAW_ACORN),37) && restored.stores==f.stores
    @test restored.r.personal[OTHER]==[1,0,0,0] && audit(restored)===nothing
    for _ in 38:119
        LW.food_process!(f.r,A);LW.food_process!(restored.r,A)
    end
    @test LW.food_process!(f.r,A)=="processed" && LW.food_process!(restored.r,A)=="processed"
    store_personally!(f,A);store_personally!(restored,A)
    @test f.r.personal[A]==[0,0,1,1] && f.stores[A]==2
    @test f.r.personal[OTHER]==[1,0,0,0] && f.r.shared==zeros(Int,4)
    @test LW.food_snapshot(restored.r)==LW.food_snapshot(f.r) && restored.stores==f.stores
    @test audit(f)===nothing && audit(restored)===nothing
end
