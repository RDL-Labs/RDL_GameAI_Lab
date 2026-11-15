include("identity_checks.jl")
include("../../src/lw/configured_paths/identity_call.jl")
@testset "name call turns, then visual recognition" begin
    roster=JSON3.read(read(joinpath(@__DIR__,"call_input.json"),String)).scene.peer_identity_roster
    relations=Dict(a=>D("identity_observation"=>configured_peer_identity_memory(a,roster),
        "test_weights"=>D("npc_b"=>.7)) for a in ("npc_a","npc_b","npc_c","npc_d"))
    world=(positions=Dict("npc_a"=>(0.,0.),"npc_b"=>(1.,0.),"npc_c"=>(20.,0.),"npc_d"=>(30.,0.)),
        hearing=Dict(a=>true for a in keys(relations)))
    yaw=Dict("npc_a"=>90.,"npc_b"=>90.,"npc_c"=>0.,"npc_d"=>0.)
    sight=D("peers"=>[D("ref"=>"npc_b","angle"=>0.)])
    peer_identity_observe!(relations["npc_a"],sight,world,"npc_a",yaw,roster,0)
    @test only(relations["npc_a"]["identity_observation"]["current"])["status"]=="insufficient_observation"
    plan=configured_identity_call_plan!(relations["npc_a"],yaw["npc_a"],0,17280000000)
    @test plan["identity_call_name"]=="ハル"
    configured_identity_call_execute!(relations,world,"npc_a",plan,roster,0)
    cue=relations["npc_b"]["identity_observation"]["calls"]["pending"]
    @test !haskey(cue,"sender") && !haskey(cue,"peer")
    @test configured_identity_call_notice!(relations["npc_b"],0)===nothing
    @test configured_identity_call_notice!(relations["npc_b"],1000000)=="identity_name_call"
    reply=configured_identity_call_plan!(relations["npc_b"],yaw["npc_b"],1000000,17280000000)
    @test reply["action"]=="scan"
    yaw["npc_b"]=mod(yaw["npc_b"]+reply["scan_angle"]+180,360)-180
    configured_identity_call_execute!(relations,world,"npc_b",reply,roster,1000000)
    @test configured_identity_call_notice!(relations["npc_b"],2000000)===nothing
    peer_identity_observe!(relations["npc_a"],sight,world,"npc_a",yaw,roster,2000000)
    identified=only(relations["npc_a"]["identity_observation"]["current"])
    @test identified["name"]=="ハル"
    @test identified["relation_weight"]==.7
    @test relations["npc_b"]["identity_observation"]["calls"]["turned"]==1
    @test configured_identity_call_plan!(relations["npc_a"],90.,2000000,17280000000)===nothing
    # Name knowledge alone neither delivers sound outside range nor identifies anyone.
    distant=D("identity_call_name"=>"ナツ")
    configured_identity_call_execute!(relations,world,"npc_a",distant,roster,3000000)
    @test !haskey(relations["npc_c"]["identity_observation"],"calls")
    world.hearing["npc_b"]=false
    configured_identity_call_execute!(relations,world,"npc_a",plan,roster,4000000)
    @test relations["npc_b"]["identity_observation"]["calls"]["pending"]===nothing
    world.hearing["npc_b"]=true
    configured_identity_call_execute!(relations,world,"npc_a",plan,roster,5000000)
    io=IOBuffer();serialize(io,relations);seekstart(io);restored=deserialize(io)
    @test configured_identity_call_notice!(restored["npc_b"],6000000)=="identity_name_call"
    @test configured_identity_call_notice!(restored["npc_b"],69000000)===nothing
    @test restored["npc_b"]["identity_observation"]["calls"]["expired"]==1
end
