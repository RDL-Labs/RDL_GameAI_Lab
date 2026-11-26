using Test, Serialization
include("../../integrations/lightweight_julia/native.jl")
# Integration fixture only: shortened daylight, remembered tastes and biased stocks.
# No taste / inventory knowledge is injected by the production call adapter.
scene=merge(native_scene(9),(personal_house_idle=true,typed_food=true,food_desire=false,
    incidental_items=true,item_exchange=true,item_attention=true,portable_items=Any[],open_stores=false,
    initial_inventory=[0,0,0],reserve=[100,100,100],positions=[[0.,4.],[0.,4.],[0.,4.]],
    initial_personal_stock=[8,8,8],initial_personal_food_counts=(npc_a=[0,0,0,8,0,0,0,0],npc_b=[8,0,0,0,0,0,0,0],npc_c=[0,0,0,8,0,0,0,0]),
    food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[]))
clock=merge(native_clock(),(day_us=120_000_000,phase_boundaries_us=[0,0,120_000_000,120_000_000],quiet_night_us=120_000_000))
@testset "normal LW camp call wiring and restart" begin
    mktempdir() do dir
        lw_day(scene,clock;days=1,basic_loop=true,checkpoint_dir=dir)
        path=joinpath(dir,"day-001.jls");saved=deserialize(path);state=saved.state
        houses=personal_houses(scene,IDS)
        for (i,a) in enumerate(IDS)
            for k in (1,4);food_remember_taste!(state[:mb_maps][a],k,2,.5,120_000_000);end
            state[:w].positions[a]= i==1 ? (0.,4.) : (houses[i].x,houses[i].z)
            state[:w].bodies[a]=RDLBody.Body(10.,0.,100.,0.)
            state[:incidental_items][a]=incidental_item_state(a,1)
            state[:pending]=D()
            state[:learning][a]["sleep"]["external_gate"]=D("active"=>false)
            house=configured_house_state!(state[:mb_maps][a]);house["mode"]=i==1 ? "active" : "idle";house["day"]=1;house["demand"]=0.
        end
        # Start A's call at the checkpoint; ordinary tick delivery wakes B.
        configured_camp_trade_call!(state[:incidental_items]["npc_a"],state[:mb_maps]["npc_a"],state[:w].bodies["npc_a"],nothing,state[:foods].personal["npc_a"],119_000_000,clock.day_us)

        serialize(path,saved)
        connected=merge(scene,(camp_trade_calls=true,))
        out=joinpath(dir,"connected")
        result=lw_day(connected,clock;days=2,basic_loop=true,resume_from=path,checkpoint_dir=out)
        channels=result["incidental_items"]

        @test channels["npc_b"]["camp_trade"]["replied"]>=1
        @test any(e->get(e,"method",nothing)=="camp_trade_meeting",result["events"])
        @test any(v->v["camp_trade"]["negotiated"]>0,values(channels))
        @test result["daily"][end]["physical"]["npc_b"]["house_attention"]["wakeups"]["pending_work"]>=1
        full=lw_day(connected,clock;days=3,basic_loop=true,resume_from=path)
        resumed=lw_day(connected,clock;days=3,basic_loop=true,resume_from=joinpath(out,"day-002.jls"))
        @test full["counts"]==resumed["counts"]
        @test full["incidental_items"]==resumed["incidental_items"]
        @test full["daily"]==resumed["daily"]
        @test any(r->r["event"]=="outcome" && r["status"]=="exchanged",channels["npc_a"]["camp_trade"]["records"])
        @test any(r->r["event"]=="call" && r["addressee"]=="npc_a",channels["npc_b"]["camp_trade"]["records"])
        println("LW: house reply -> meeting -> exchange -> learned directed call; restart matches")
    end
end
