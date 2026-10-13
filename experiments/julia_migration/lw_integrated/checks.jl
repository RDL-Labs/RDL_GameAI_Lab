using Test
@testset "finite safety selection" begin
    m=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
    seen=D("coverage"=>"complete","features"=>[D("forward"=>2.,"right"=>2.,"distance"=>sqrt(8.))])
    clear=D("coverage"=>"complete","features"=>Any[])
    s=safety_state()
    @test safety_plan!(s,clear,m)===nothing
    @test safety_plan!(s,seen,m)["action"]=="walk"
    @test s["active"] && s["entries"]==1
    blocked=D("energy"=>D("rows"=>[D("ref"=>"0","cost"=>nothing)]))
    @test safety_plan!(s,seen,blocked)["action"]=="scan"
    for i in 1:3
        @test safety_plan!(s,clear,m)["action"]=="scan"
    end
    @test safety_plan!(s,clear,m)===nothing
    @test s["releases"]==1 && !s["active"]
    @test safety_plan!(s,seen,m)!==nothing && s["entries"]==2
    safety_plan!(s,clear,m)
    safety_plan!(s,seen,m)
    @test s["H"]==0
    w=(positions=Dict("a"=>(0.,0.)),obstacles=Any[])
    yaw=Dict("a"=>0.)
    hs=[(x=0.,z=2.,vx=1.,vz=0.,start=0,stop=10)]
    ob=hazard_observation(w,"a",yaw,hs,1)
    @test length(ob["features"])==1
    @test ob["features"][1]["right"]==1.
    @test Set(keys(ob["features"][1]))==Set(["forward","right","distance"])
    @test isempty(hazard_observation(w,"a",yaw,hs,10)["features"])
    yaw["a"]=180.
    @test isempty(hazard_observation(w,"a",yaw,hs,1)["features"])
end

function validate_integrated(r,input)
    cfg=input.config
@testset "LW-Julia integrated invariants" begin
    @test r["ended_us"]==cfg.days*input.clock.day_us
    @test all(sum(values(r["counts"][a]))==cfg.days*17_280 for a in IDS)
    @test r["initial_food"]+r["replenished_food"]==r["ground"]+r["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(r["final_agents"]))
    @test all(isfinite(v) for s in values(r["final_agents"]) for v in values(s["body"]) if v isa Number)
end

end

@testset "Sleep uses current dynamic hazard observation" begin
    w=(positions=Dict("a"=>(0.,0.)),obstacles=Any[])
    yaw=Dict("a"=>0.)
    state=dynamic_hazards()
    state["territory"]["position"]=(0.,2.)
    movement=D("food_coverage"=>"complete","visible"=>Any[],"energy"=>D("rows"=>Any[]))
    view=hazard_observation(w,"a",yaw,dynamic_hazard_sources(state,20;patrol=false),20)
    @test sleep_context(movement,view)[2]===true
    state["territory"]["position"]=(0.,20.)
    nextview=hazard_observation(w,"a",yaw,dynamic_hazard_sources(state,21;patrol=false),21)
    @test sleep_context(movement,nextview)[2]===false
    @test sleep_context(movement,view)[2]===true
    @test sleep_context(movement,D("coverage"=>"partial","features"=>Any[]))===nothing
end
