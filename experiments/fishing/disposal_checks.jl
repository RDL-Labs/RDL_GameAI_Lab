include("checks.jl")
@testset "camp disposal conserves material and respects access" begin
 f=fixture(;stock=0);D=LW.D
 bin=(id=2,x=0.,z=0.,work_radius=2.1,height=.6,radius=.4,color="grey",processing_kinds=Int[],accepts_waste=true)
 facilities=[bin]
 LW.food_push!(f.r,A,6,3);push!(f.cargo[A],"spoiled");f.w.inventory[A]=1;f.r.initial[6]=3
 f.r.personal[A][6]=2;f.stores[A]=2
 LW.food_quality_store_add!(f.r,A,6,4)
 m=D();loop=LW.BasicLoop("disposal";probabilistic=true,seed=1)
 g=LW.RDLBody.Digestion();g.gut=LW.GUT_CAPACITY
 p=LW.food_desire_plan!(m,loop,f.r,A,g,f.w.bodies[A],true,f.r.personal[A],facilities,(0.,0.),0;requested=false)
 @test p!==nothing && p["action"]=="discard_food"
 @test LW.food_disposal_for(facilities,(10.,0.))===nothing
 f.w.positions[A]=(10.,0.)
 @test LW.food_discard!(f.r,f.w,f.cargo,f.stores,facilities,A,6,3,true,false,"out",0)=="disposal_unavailable"
 @test f.w.inventory[A]==1
 f.w.positions[A]=(0.,0.)
 @test LW.food_discard!(f.r,f.w,f.cargo,f.stores,facilities,A,6,3,true,false,"held",1)=="discarded"
 @test LW.food_discard!(f.r,f.w,f.cargo,f.stores,facilities,A,6,3,true,false,"held",1)=="discarded"
 @test LW.food_waste_total(f.r)==1 && f.w.inventory[A]==0 && isempty(f.cargo[A])
 @test audit(f)===nothing
 @test LW.food_discard!(f.r,f.w,f.cargo,f.stores,facilities,A,6,4,false,false,"noaccess",2)=="disposal_unavailable"
 @test LW.food_discard!(f.r,f.w,f.cargo,f.stores,facilities,A,6,4,true,false,"stored",3)=="discarded"
 @test f.stores[A]==1 && LW.food_waste_total(f.r)==2
 @test audit(f)===nothing
 @test LW.food_discard!(f.r,f.w,f.cargo,f.stores,facilities,A,6,2,true,false,"last",4)=="discarded"
 @test LW.food_discard!(f.r,f.w,f.cargo,f.stores,facilities,A,6,2,true,false,"empty",5)=="disposal_unavailable"
 @test LW.food_waste_total(f.r)==3 && f.w.consumed==0
 @test audit(f)===nothing
 LW.food_desire_result!(m,p,"discarded",0,0.,6)
 @test m["food_desire"]["intent"]===nothing
 @test LW.food_snapshot(f.r)["waste"]["counts"][6]==3
 io=IOBuffer();serialize(io,f.r);seekstart(io)
 @test LW.food_waste_total(deserialize(io))==3
 # Shared storage follows the same physical accounting, without reducing a personal store.
 f.r.shared[6]=1;f.r.initial[6]+=1
 @test LW.food_discard!(f.r,f.w,f.cargo,f.stores,facilities,A,6,2,true,true,"shared",6)=="discarded"
 @test f.r.shared[6]==0 && f.stores[A]==0
 @test audit(f)===nothing
 @test LW.food_desire_plan!(m,loop,f.r,A,g,f.w.bodies[A],true,f.r.personal[A],facilities,(0.,0.),2_000_000;requested=false)===nothing
end
