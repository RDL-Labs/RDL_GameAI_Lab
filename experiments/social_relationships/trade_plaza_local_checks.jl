include("camp_trade_calls_checks.jl")
Base.include(LW,joinpath(@__DIR__,"../../src/lw/configured_paths/trade_plaza_local.jl"))
# Local fixture: known plaza, ordinary sight/contact/body step and negotiation.
# No autonomous food/processing scheduler is run here.
@testset "plaza resolves opposite-edge meeting" begin
 for seed in 1:8
    f=camp_fixture(seed);a,b,c=f.ids;camp_event(f);camp_tick(f,1_000_000)
    f.w.positions[a]=(0.,1.1);f.w.positions[b]=(0.,-1.1)
    headings=Dict(a=>180.,b=>0.);steps=0
    @test !LW.item_trade_contact(f.w,(0.,0.),a,b)
    for actor in (a,b)
        rows=LW.movement_observation(f.w,actor,headings,Any[],Int[])["energy"]["rows"]
        @test LW.configured_camp_trade_approach(f.states[actor],(0.,0.),f.w.positions[actor],headings[actor],rows)===nothing
    end
    for tick in 1:12
        LW.item_trade_contact(f.w,(0.,0.),a,b) && break
        for actor in (a,b)
            rows=LW.movement_observation(f.w,actor,headings,Any[],Int[])["energy"]["rows"]
            sight=LW.social_sight(f.w,actor,headings,tick*1_000_000)
            visible=LW.item_visible(f.items,f.w,(0.,0.),actor,headings[actor],tick*1_000_000;foods=f.foods)
            plan=LW.configured_trade_plaza_local(f.states[actor],(0.,0.),f.w.positions[actor],headings[actor],rows,sight,visible["trade_partners"])
            plan===nothing && continue
            @test plan["action"]=="walk"
            headings[actor]+=LW.ANGLES[plan["direction"]+1]
            row=only(filter(r->parse(Int,r["ref"])==plan["direction"],rows))
            f.w.bodies[actor],status,distance,_=LW.step(f.w.bodies[actor],"walk",0,row["resistance"],row["clear"])
            @test status=="performed"
            origin=f.w.positions[actor];sn,cs=sincosd(headings[actor])
            f.w.positions[actor]=(origin[1]+sn*distance,origin[2]+cs*distance);steps+=1
        end
    end
    @test LW.item_trade_contact(f.w,(0.,0.),a,b)
    visible=LW.configured_camp_trade_view(f.states[a],LW.item_visible(f.items,f.w,(0.,0.),a,headings[a],20_000_000;foods=f.foods),20_000_000)
    before=deepcopy(f.foods.personal)
    LW.configured_camp_trade_plan!(f.states[a],visible,f.w.bodies[a],nothing,f.foods.personal[a],20_000_000;map=f.maps[a])
    @test f.states[a]["camp_trade"]["negotiated"]==1
    @test f.foods.personal==before # Meeting/evaluation does not transfer ownership.
    # At the plaza, an unseen partner produces observation, not omniscient motion.
    rows=LW.movement_observation(f.w,a,headings,Any[],Int[])["energy"]["rows"]
    unseen=LW.configured_trade_plaza_local(f.states[a],(0.,0.),(0.,0.),0.,rows,D("peers"=>Any[]),String[])
    @test unseen["action"]=="scan"
    peer_sight=D("peers"=>[D("ref"=>b,"angle"=>90.)])
    approach=LW.configured_trade_plaza_local(f.states[a],(0.,0.),(0.,0.),0.,rows,peer_sight,String[])
    @test approach["method"]=="trade_plaza_peer"
    blocked=LW.configured_trade_plaza_local(f.states[a],(0.,0.),(0.,0.),0.,Any[],peer_sight,String[])
    @test blocked["action"]=="scan"
    println(JSON3.write((plaza_seed=seed,walk_steps=steps,negotiated=1)))
 end
end
