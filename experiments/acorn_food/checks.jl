using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
const B=LW.RDLBody
const A="npc_a";const C="npc_c";const OTHER="npc_b"

"Small authoritative resource fixture; no navigation or simulated days."
function fixture(;kinds=[[3,1],Int[],Int[]],shared_counts=[0,0,0,0])
    w=LW.world(true)
    for (i,a) in enumerate(LW.IDS)
        w.inventory[a]=length(kinds[i]);w.bodies[a]=B.Body(10.,0.,50.,0.)
    end
    food=Any[(x=0.,z=0.,stock=4,food_kind=3),(x=2.,z=0.,stock=2,food_kind=1)]
    stock=[4,2];stores=Dict(a=>0 for a in LW.IDS);shared=Ref(sum(shared_counts))
    spec=(typed_food=true,initial_inventory_kinds=kinds,initial_shared_food_counts=shared_counts)
    r=LW.food_resources(spec,w,food,stock,shared[],stores)
    cargo=Dict(a=>Any["initial:$a:$i" for i in 1:w.inventory[a]] for a in LW.IDS)
    (w=w,r=r,food=food,stock=stock,stores=stores,shared=shared,cargo=cargo)
end
audit(f)=LW.food_audit!(f.r,f.w,f.stock,f.shared[],f.stores)
function saved_copy(x)
    io=IOBuffer();serialize(io,x);seekstart(io);deserialize(io)
end

@testset "taste and delayed acorn nutrition" begin
    g=B.Digestion();body=B.Body(10.,0.,50.,0.)
    @test B.taste(g,B.ORDINARY_FOOD,50.)==.75
    @test B.taste(g,B.MEAT_FOOD,50.)==1.125
    @test B.taste(g,B.ACORN_MEAL,50.)≈.3375
    @test B.taste(g,B.ACORN_MEAL,50.)<B.taste(g,B.ORDINARY_FOOD,50.)
    before=B.digestion_snapshot(g)
    @test_throws ErrorException B.ingest!(g,B.RAW_ACORN,50.,0)
    @test B.digestion_snapshot(g)==before
    liking=B.ingest!(g,B.ACORN_MEAL,50.,0)
    @test liking≈.3375 && body.reserve==50.
    @test g.recent==[0.,0.,0.,.6]
    @test B.taste(g,B.ACORN_MEAL,50.)<liking
    body=B.digest!(g,body,900.)
    @test body.reserve≈60. && g.gut≈.5
    body=B.digest!(g,body,900.)
    @test body.reserve≈70. && g.gut≈0.
    @test B.digestion_snapshot(g)["absorbed"]≈20.
    legacy=B.Digestion();B.ingest!(legacy,B.MEAT_FOOD,50.,0)
    @test legacy.recent==[0.,.6] # legacy representation stays two entries
    @test B.FOOD_STORAGE[B.RAW_ACORN]=="long" && B.FOOD_STORAGE[B.ACORN_MEAL]=="long"
end

@testset "strict numeric food contracts" begin
    @test LW.checked_food_kind(3)===UInt8(3)
    for invalid in (0,5,-1,true,1.0,"raw_acorn")
        @test_throws ErrorException LW.checked_food_kind(invalid)
    end
    @test LW.food_count_vector(nothing,3)==[3,0,0,0]
    @test_throws ErrorException LW.food_count_vector([0,-1,2,0],1)
    @test_throws ErrorException LW.food_count_vector([0,0,1],1)
    @test_throws ErrorException LW.food_count_vector([0,0,2,0],1)
    @test_throws ErrorException LW.food_count_vector(Any[true,0,0,0],1)
    @test_throws ErrorException LW.food_count_vector([1.0,0,0,0],1)
    f=fixture()
    @test_throws ErrorException LW.food_resources((typed_food=false,),f.w,f.food,f.stock,0,f.stores)
    @test_throws ErrorException fixture(kinds=[[5],Int[],Int[]])
    @test audit(f)===nothing
    f.r.inventory[A][1]=UInt8(B.MEAT_FOOD) # same total but wrong species of resource
    @test_throws ErrorException audit(f)
end

@testset "processing work and interruption preserve mass" begin
    f=fixture(kinds=[[3],Int[],Int[]]);r=f.r
    @test !LW.food_has_edible(r,A) && LW.food_has_raw(r,A)
    @test LW.food_best_edible(r,A,nothing,50.)==0
    statuses=[LW.food_process!(r,A) for _ in 1:119]
    @test all(==("processing"),statuses)
    @test r.inventory[A]==[3] && r.processed[B.RAW_ACORN]==0
    @test r.progress[A]==(UInt8(3),119)
    before=LW.food_snapshot(r)
    @test LW.food_snapshot(r)==before # observation does not finish work
    resumed=saved_copy(r)
    @test LW.food_process!(r,A)=="processed"
    @test LW.food_process!(resumed,A)=="processed"
    @test LW.food_snapshot(r)==LW.food_snapshot(resumed)
    @test r.inventory[A]==[4] && r.processed==[0,0,1,0] && r.work_ticks[A]==120
    @test audit(f)===nothing
    @test LW.food_process!(r,A)=="no_ingredient"
    @test r.work_ticks[A]==120
    broken=fixture(kinds=[[3],Int[],Int[]])
    for _ in 1:20;LW.food_process!(broken.r,A);end
    removed=LW.food_remove!(broken.r,A,1)
    broken.w.inventory[A]-=1
    push!(broken.r.inventory[C],removed);broken.w.inventory[C]+=1
    @test broken.r.progress[A]==(UInt8(0),0) && broken.r.progress[C]==(UInt8(0),0)
    @test LW.food_process!(broken.r,C)=="processing"
    @test broken.r.progress[C]==(UInt8(3),1)
    @test audit(broken)===nothing
end

@testset "camp processing yields to exhausted body" begin
    f=fixture(kinds=[[3],Int[],Int[]])
    @test LW.configured_food_preparation(f.r,A,true,true,false,0)===nothing
    @test LW.configured_food_preparation(f.r,A,false,true,true,0)===nothing
    @test LW.configured_food_preparation(f.r,A,true,true,true,0)=="process_food"
    exhausted=B.Body(10.,1.,50.,0.)
    @test B.step(exhausted,"process_food",1)[2]=="body_limited"
    chosen=LW.configured_food_preparation(f.r,A,true,true,true,0;processing_feasible=false)
    @test chosen=="rest"
    rested=B.step(exhausted,chosen,1)[1]
    @test rested.strain<exhausted.strain
    @test B.step(rested,"process_food",1)[2]=="worked"
    @test f.r.progress[A]==(UInt8(0),0) # selection/rest never advances the recipe
end

@testset "full gut rests before taking more camp food" begin
    f=fixture(kinds=[[1],Int[],Int[]],shared_counts=[0,0,2,0])
    g=B.Digestion()
    for _ in 1:2;B.ingest!(g,B.ORDINARY_FOOD,50.,0);end
    @test !B.can_ingest(g)
    food_before=LW.food_snapshot(f.r);gut_before=B.digestion_snapshot(g)
    # A low reserve can still request food while previous meals fill the gut.
    # Carrying an edible portion must block repeated retrieval from nearby stock.
    @test LW.configured_food_preparation(f.r,A,true,B.can_ingest(g),true,f.shared[])=="rest"
    @test LW.food_snapshot(f.r)==food_before && B.digestion_snapshot(g)==gut_before
    empty=fixture(kinds=[Int[],Int[],Int[]],shared_counts=[0,0,2,0])
    @test !LW.food_has_edible(empty.r,A) && !LW.food_has_raw(empty.r,A)
    @test LW.configured_food_preparation(empty.r,A,true,true,true,empty.shared[])=="retrieve"
end

@testset "storage, gifts and drops retain resource kind" begin
    f=fixture();r=f.r;w=f.w
    @test LW.food_best_edible(r,A,nothing,50.)==2 # raw first in bag is not a meal
    LW.communicate!(w,OTHER,"request-1","request",A)
    receipt=LW.communicate!(w,A,"give-1","give",OTHER,OTHER*":request-1")
    @test receipt["status"]=="transferred"
    push!(f.cargo[OTHER],popfirst!(f.cargo[A]))
    push!(r.inventory[OTHER],LW.food_remove!(r,A,1))
    @test r.inventory[OTHER]==[3] && w.bodies[OTHER].reserve==50.
    @test audit(f)===nothing
    ground=LW.cargo_ground()
    status=LW.cargo_transfer!(ground,w,f.cargo,f.food,f.stock,OTHER,"drop-1",1_000_000,"drop")
    LW.food_track_cargo!(r,ground,f.food,OTHER,"drop-1","drop",status,0)
    @test status=="dropped" && f.food[end].food_kind==3 && r.site_kinds[end]==3
    @test audit(f)===nothing
    dropped_index=length(f.food)
    status=LW.cargo_transfer!(ground,w,f.cargo,f.food,f.stock,C,"recover-1",2_000_000,"recover";index=dropped_index)
    LW.food_track_cargo!(r,ground,f.food,C,"recover-1","recover",status,dropped_index)
    @test status=="recovered" && r.inventory[C]==[3]
    @test ground["cross_actor"]==1 && audit(f)===nothing
    for _ in 1:120;LW.food_process!(r,C);end
    amount=w.inventory[C]
    LW.food_deposit!(r,C,true);f.shared[]+=amount;w.inventory[C]=0;empty!(f.cargo[C])
    @test r.shared==[0,0,0,1] && audit(f)===nothing
    # Ordinary food can be deposited into the same shared store without erasing kinds.
    amount=w.inventory[A]
    LW.food_deposit!(r,A,true);f.shared[]+=amount;w.inventory[A]=0;empty!(f.cargo[A])
    @test r.shared==[1,0,0,1]
    @test LW.food_retrieve!(r,OTHER,true,nothing,50.)==B.ORDINARY_FOOD
    f.shared[]-=1;w.inventory[OTHER]+=1;push!(f.cargo[OTHER],nothing)
    @test LW.food_retrieve!(r,C,true,nothing,50.)==B.ACORN_MEAL
    f.shared[]-=1;w.inventory[C]+=1;push!(f.cargo[C],nothing)
    @test audit(f)===nothing
    receipt=LW.communicate!(w,C,"eat-1","eat")
    @test receipt["status"]=="ate"
    kind=LW.food_remove!(r,C,1);popfirst!(f.cargo[C]);LW.food_record_meal!(r,C,kind,.3375,3_000_000)
    @test r.consumed==[0,0,0,1] && r.pleasure[C]==.3375
    @test audit(f)===nothing
    @test !LW.food_snapshot(r)["decay_enabled"]
end

@testset "personal stores and known raw ingredients" begin
    f=fixture(kinds=[[3],Int[],Int[]])
    LW.food_deposit!(f.r,A,false);f.stores[A]+=1;f.w.inventory[A]=0
    @test f.r.personal[A]==[0,0,1,0] && f.r.shared==zeros(Int,4)
    @test audit(f)===nothing
    @test LW.configured_food_preparation(f.r,A,true,true,true,1)=="retrieve"
    @test LW.food_retrieve!(f.r,A,false,nothing,50.)==B.RAW_ACORN
    f.stores[A]-=1;f.w.inventory[A]+=1
    @test LW.configured_food_preparation(f.r,A,true,true,true,0)=="process_food"
    @test audit(f)===nothing
end
