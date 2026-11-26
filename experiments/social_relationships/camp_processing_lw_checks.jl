include("camp_trade_lw_checks.jl")

# Integration fixture: seed an agreed tentative supply plan at a checkpoint.
# Local reply tests separately cover choosing that plan from a cooked-fish call.
@testset "normal LW physically prepares announced fish" begin
    mktempdir() do dir
        work_clock=merge(clock,(day_us=300_000_000,phase_boundaries_us=[0,0,300_000_000,300_000_000],quiet_night_us=300_000_000))
        lw_day(scene,work_clock;days=1,basic_loop=true,checkpoint_dir=dir)
        path=joinpath(dir,"day-001.jls");saved=deserialize(path);state=saved.state
        connected=merge(scene,(camp_trade_calls=true,camp_trade_processing=true,
            food_facilities=[(id=1,x=0.,z=4.,work_radius=2.,height=1.,radius=.5,color="brown",processing_kinds=[5])],
            initial_personal_food_counts=(npc_a=[8,0,0,0,0,0,0,0],npc_b=[0,0,0,0,8,0,0,0],npc_c=[8,0,0,0,0,0,0,0])))
        state[:pending]=D()
        for a in IDS
            state[:w].positions[a]=(0.,4.);state[:w].inventory[a]=0
            state[:w].bodies[a]=RDLBody.Body(10.,0.,100.,0.)
            state[:stores][a]=8
            state[:incidental_items][a]=incidental_item_state(a,1)
            state[:learning][a]["sleep"]["external_gate"]=D("active"=>false)
            configured_house_state!(state[:mb_maps][a])["mode"]="active"
            for k in (1,5,7);food_remember_taste!(state[:mb_maps][a],k,2,k==5 ? -.8 : .5,120_000_000);end
        end
        state[:foods]=food_resources(connected,state[:w],Any[],Int[],state[:shared],state[:stores])
        # Fresh fish is introduced at the resumed day's start, not aged from day 1.
        state[:foods].game.expiry_day=1
        prep=D("input"=>5,"output"=>7,"salt_id"=>nothing,"mode"=>"supplier_processing")
        for (a,peer,initiator) in (("npc_a","npc_b",true),("npc_b","npc_a",false))
            ch=configured_camp_trade_state!(state[:incidental_items][a])
            ch["last_day"]=2
            ch["meeting"]=D("peer"=>peer,"initiator"=>initiator,"kind"=>initiator ? 7 : 1,
                "announced"=>initiator ? Dict{Int,Int}() : Dict(1=>1),"expires_us"=>560_000_000,"evaluated"=>false)
            !initiator && (ch["meeting"]["preparation"]=prep)
        end
        serialize(path,saved)
        result=lw_day(connected,work_clock;days=2,basic_loop=true,resume_from=path)
        @test result["food_resources"]["processed_inputs"][5]>=1
        @test any(r->r["event"]=="prepared_supply_ready",result["incidental_items"]["npc_b"]["camp_trade"]["records"])
        @test any(e->get(e,"method",nothing)=="camp_trade_prepare" && e["action"]=="deposit",result["events"])
    end
end


