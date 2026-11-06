include("checks.jl")

@testset "isolated logarithmic game skill MB" begin
    mb=LW.game_skill_mb();skill="acorn_preparation"
    values=[LW.game_skill_forecast(merge(mb,LW.D("experience"=>Float64(n))),skill).effect for n in 0:40]
    @test all(>=(0),diff(values))
    @test values[2]-values[1]>values[21]-values[20]
    @test [LW.game_skill_forecast(merge(mb,LW.D("experience"=>Float64(n))),skill).quality for n in (0,5,14,36)]==[1,2,3,4]
    @test LW.game_skill_forecast(merge(mb,LW.D("experience"=>1e9)),skill).effect==3.0
    f=fixture(kinds=[[3],Int[],Int[]]);r=f.r
    for _ in 1:119;LW.food_process!(r,A);end
    @test isempty(r.game.skills)
    @test LW.food_process!(r,A)=="processed"
    @test r.game.skills[A][skill]["experience"]==1.0
    @test LW.food_quality(r,A,1)==1
    @test LW.food_process!(r,A)=="no_ingredient"
    @test r.game.skills[A][skill]["completed"]==1
    @test audit(f)===nothing
    resumed=saved_copy(r)
    @test LW.food_game_snapshot(resumed)==LW.food_game_snapshot(r)
    off=fixture(kinds=[[3],Int[],Int[]]);off.r.game.enabled=false
    for _ in 1:120;LW.food_process!(off.r,A);end
    @test isempty(off.r.game.skills) && LW.food_quality(off.r,A,1)==2
    @test audit(off)===nothing
end

@testset "quality follows product not eater or owner" begin
    f=fixture(kinds=[[3,1],Int[],Int[]]);r=f.r
    for _ in 1:120;LW.food_process!(r,A);end
    LW.food_give!(r,A,OTHER);f.w.inventory[A]-=1;f.w.inventory[OTHER]+=1
    @test LW.food_quality(r,OTHER,1)==1 && LW.food_quality(r,A,1)==2
    @test !haskey(r.game.skills,OTHER)
    LW.food_deposit!(r,OTHER,false);f.stores[OTHER]+=1;f.w.inventory[OTHER]=0
    @test r.game.stores[OTHER][(4,1)]==1
    LW.food_retrieve!(r,OTHER,false,nothing,50.;kind=4,quality=1)
    f.stores[OTHER]-=1;f.w.inventory[OTHER]+=1
    @test LW.food_quality(r,OTHER,1)==1 && audit(f)===nothing
    g=B.Digestion();ordinary=B.ingest!(deepcopy(g),4,50.,0)
    rough=B.ingest!(deepcopy(g),4,50.,0;quality_bonus=LW.game_food_bonus(4,1))
    excellent=B.ingest!(deepcopy(g),4,50.,0;quality_bonus=LW.game_food_bonus(4,4))
    @test rough<ordinary<excellent
    @test LW.food_expected_taste(LW.D(),4,g,50.;quality=1)≈rough
    @test LW.food_expected_taste(LW.D(),4,g,50.;quality=4)≈excellent
    f=fixture(kinds=[[4,4,4],Int[],Int[]]);r=f.r
    LW.food_quality_set!(r,A,1,1);LW.food_quality_set!(r,A,2,3);LW.food_quality_set!(r,A,3,4)
    LW.food_remove!(r,A,1)
    @test [LW.food_quality(r,A,i) for i in 1:2]==[3,4]
end

@testset "quality survives shared stacks and dropped cargo" begin
    f=fixture(kinds=[[4],Int[],Int[]]);r=f.r
    LW.food_quality_set!(r,A,1,4)
    LW.food_deposit!(r,A,true);f.shared[]+=1;f.w.inventory[A]=0;empty!(f.cargo[A])
    LW.food_retrieve!(r,OTHER,true,nothing,50.;kind=4,quality=4)
    f.shared[]-=1;f.w.inventory[OTHER]+=1;push!(f.cargo[OTHER],nothing)
    @test LW.food_quality(r,OTHER,1)==4 && audit(f)===nothing
    ground=LW.cargo_ground()
    status=LW.cargo_transfer!(ground,f.w,f.cargo,f.food,f.stock,OTHER,"quality-drop",1_000_000,"drop")
    LW.food_track_cargo!(r,ground,f.food,OTHER,"quality-drop","drop",status,0)
    j=length(f.food)
    @test status=="dropped" && r.game.sites[j]==4
    status=LW.cargo_transfer!(ground,f.w,f.cargo,f.food,f.stock,C,"quality-recover",2_000_000,"recover";index=j)
    LW.food_track_cargo!(r,ground,f.food,C,"quality-recover","recover",status,j)
    @test status=="recovered" && LW.food_quality(r,C,1)==4 && audit(f)===nothing
end

@testset "warehouse exchange retains quality and replay is idempotent" begin
    f=fixture(kinds=[[4], [1],Int[]]);r=f.r
    LW.food_quality_set!(r,A,1,4)
    for a in LW.IDS
        f.w.positions[a]=(0.,0.);f.w.hearing[a]=true
        f.stores[a]=f.w.inventory[a];LW.food_deposit!(r,a,false);f.w.inventory[a]=0
    end
    s=LW.food_exchange_state();home=(0.,0.)
    o=LW.food_exchange_execute!(s,r,f.w,f.stores,home,A,"quality-offer","trade_offer",0;
        target=OTHER,give_kind=4,give_count=1,want_kind=1,want_count=1)
    @test o["status"]=="offered"
    receipt=LW.food_exchange_execute!(s,r,f.w,f.stores,home,OTHER,"quality-accept","trade_accept",1_000_000;offer_id=o["offer_id"])
    @test receipt["status"]=="exchanged" && r.game.stores[OTHER][(4,4)]==1
    @test audit(f)===nothing
    before=LW.food_snapshot(r)
    @test LW.food_exchange_execute!(s,r,f.w,f.stores,home,OTHER,"quality-accept","trade_accept",1_000_000;offer_id=o["offer_id"])==receipt
    @test LW.food_snapshot(r)==before
end

@testset "skill forecast changes common candidates without forcing action" begin
    f=fixture(kinds=[[3,1],Int[],Int[]]);r=f.r;map=LW.D()
    facility=(id=1,x=0.,z=0.,work_radius=2.,processing_kinds=[3])
    candidates()=LW.food_desire_candidates(map,r,A,nothing,50.,true,r.personal[A],[facility],(0.,0.))
    novice=only(c for c in candidates() if get(c,"prepare",false))
    r.game.skills[A]=LW.D("acorn_preparation"=>merge(LW.game_skill_mb(),LW.D("experience"=>36.0)))
    expert=only(c for c in candidates() if get(c,"prepare",false))
    @test novice["quality"]==1 && expert["quality"]==4
    @test expert["priority"]>novice["priority"]
    @test any(c->get(c,"defer",false),candidates())
    @test any(c->get(c,"food_kind",0)==1,candidates())
    state=LW.food_desire_state();state["intent"]=expert;map["food_desire"]=state
    loop=LW.BasicLoop("food";probabilistic=true,seed=1)
    @test LW.food_desire_plan!(map,loop,r,A,nothing,f.w.bodies[A],true,r.personal[A],[facility],(0.,0.),0)["action"]=="process_food"
    for _ in 1:120;LW.food_process!(r,A);end
    plan=LW.food_desire_plan!(map,loop,r,A,nothing,f.w.bodies[A],true,r.personal[A],[facility],(0.,0.),1)
    @test plan["action"]=="eat" && plan["food_quality"]==4
    @test LW.food_meal_index(r,A,nothing,50.,4;quality=4)==1
    @test r.game.skills[A]["acorn_preparation"]["experience"]==37.0
end
