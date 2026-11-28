using Test, JSON3
include("../../src/lw/LW.jl")
Base.include(LW,joinpath(@__DIR__,"../../src/lw/configured_paths/meeting_call_local.jl"))
function call_fixture()
    roster=JSON3.read(read(joinpath(@__DIR__,"../trade_living/call_input.json"),String)).scene.peer_identity_roster
    w=LW.world(true);a,b=LW.IDS[1:2]
    w.positions[a]=(0.,1.);w.positions[b]=(0.,-1.)
    yaw=Dict(a=>180.,b=>180.) # A sees B's back; B cannot initially see A.
    states=Dict(id=>LW.incidental_item_state(id,1) for id in LW.IDS)
    relations=Dict(id=>LW.D("identity_observation"=>LW.configured_peer_identity_memory(id,roster)) for id in LW.IDS)
    for (id,peer) in ((a,b),(b,a))
        LW.configured_camp_trade_state!(states[id])["meeting"]=LW.D("peer"=>peer)
    end
    (;w,a,b,yaw,states,relations,roster)
end
@testset "meeting name call, attention and approach" begin
    f=call_fixture();(;w,a,b,yaw,states,relations,roster)=f
    before=deepcopy((w.positions,w.inventory))
    sight=LW.social_sight(w,a,yaw,0)
    @test any(p->p["ref"]==b,sight["peers"])
    @test !any(p->p["ref"]==a,LW.social_sight(w,b,yaw,0)["peers"])
    call=LW.configured_meeting_call_local(states[a],relations[a],sight,yaw[a],0,17_280_000_000)
    @test call["identity_call_name"]==roster[b]["name"]
    LW.configured_identity_call_execute!(relations,w,a,call,roster,0)
    @test (w.positions,w.inventory)==before
    @test LW.configured_meeting_call_local(states[b],relations[b],LW.D("peers"=>Any[]),yaw[b],1_000_000,17_280_000_000;busy=true)===nothing
    reply=LW.configured_meeting_call_local(states[b],relations[b],LW.D("peers"=>Any[]),yaw[b],2_000_000,17_280_000_000)
    @test reply["identity_answer"]
    yaw[b]=mod(yaw[b]+reply["scan_angle"]+180,360)-180
    LW.configured_identity_call_execute!(relations,w,b,reply,roster,2_000_000)
    @test any(p->p["ref"]==a,LW.social_sight(w,b,yaw,3_000_000)["peers"])
    @test LW.configured_meeting_call_local(states[a],relations[a],sight,yaw[a],3_000_000,17_280_000_000)===nothing
    @test states[a]["camp_trade"]["negotiated"]==0
    # Existing observed-peer movement and body step bring the pair into contact.
    rows=LW.movement_observation(w,b,yaw,Any[],Int[])["energy"]["rows"]
    plan=LW.configured_camp_trade_approach(states[b],(0.,0.),w.positions[b],yaw[b],rows;sight=LW.social_sight(w,b,yaw,3_000_000))
    @test plan["method"]=="camp_trade_peer_approach"
    yaw[b]+=LW.ANGLES[plan["direction"]+1]
    row=only(filter(r->parse(Int,r["ref"])==plan["direction"],rows))
    w.bodies[b],status,d,_=LW.step(w.bodies[b],"walk",0,row["resistance"],row["clear"])
    p=w.positions[b];sn,cs=sincosd(yaw[b]);w.positions[b]=(p[1]+sn*d,p[2]+cs*d)
    @test status=="performed"
    @test hypot(w.positions[a][1]-w.positions[b][1],w.positions[a][2]-w.positions[b][2])<2
    rows=LW.movement_observation(w,b,yaw,Any[],Int[])["energy"]["rows"]
    nextplan=LW.configured_camp_trade_approach(states[b],(0.,0.),w.positions[b],yaw[b],rows;sight=LW.social_sight(w,b,yaw,4_000_000))
    yaw[b]+=LW.ANGLES[nextplan["direction"]+1]
    row=only(filter(r->parse(Int,r["ref"])==nextplan["direction"],rows))
    w.bodies[b],status,d2,_=LW.step(w.bodies[b],"walk",0,row["resistance"],row["clear"])
    p=w.positions[b];sn,cs=sincosd(yaw[b]);w.positions[b]=(p[1]+sn*d2,p[2]+cs*d2)
    @test LW.item_trade_contact(w,(0.,0.),a,b)
    @test w.inventory==before[2]
    println(JSON3.write((name=call["identity_call_name"],turned=relations[b]["identity_observation"]["calls"]["turned"],approach_distance=d,negotiated=0)))
end
@testset "unheard, unseen and busy expiration" begin
    f=call_fixture();(;w,a,b,yaw,states,relations,roster)=f
    sight=LW.social_sight(w,a,yaw,0)
    @test LW.configured_meeting_call_local(states[a],relations[a],LW.D("peers"=>Any[]),yaw[a],0,17_280_000_000)===nothing
    call=LW.configured_meeting_call_local(states[a],relations[a],sight,yaw[a],0,17_280_000_000)
    w.hearing[b]=false
    LW.configured_identity_call_execute!(relations,w,a,call,roster,0)
    @test LW.configured_identity_call_notice!(relations[b],1_000_000)===nothing
    w.hearing[b]=true
    LW.configured_identity_call_execute!(relations,w,a,call,roster,64_000_000)
    @test LW.configured_meeting_call_local(states[b],relations[b],LW.D("peers"=>Any[]),yaw[b],65_000_000,17_280_000_000;busy=true)===nothing
    @test LW.configured_meeting_call_local(states[b],relations[b],LW.D("peers"=>Any[]),yaw[b],129_000_000,17_280_000_000)===nothing
    @test relations[b]["identity_observation"]["calls"]["expired"]==1
end
