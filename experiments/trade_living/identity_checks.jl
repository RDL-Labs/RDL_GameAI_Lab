using Test, JSON3, Serialization
const D=Dict{String,Any}
include("../../src/lw/configured_paths/peer_identity_memory.jl")
include("../../src/lw/perception/peer_identity.jl")
include("../simple_language/appearance_probe.jl")
# Synthetic relation adapter verifies the inferred peer, not transport identity.
social_relation_bias(relation,peer,context)=D("weight"=>relation["test_weights"][peer])
@testset "known names, observed identity" begin
    spec=JSON3.read(read(joinpath(@__DIR__,"identity_input.json"),String)).scene
    state=configured_peer_identity_memory("npc_a",spec.peer_identity_roster)
    @test !haskey(state["features"],"npc_a")
    @test length(state["names"])==3
    @test state["names"]["npc_b"]=="ハル"
    features=state["features"]["npc_b"]
    @test peer_identity_match(state["features"],peer_identity_patch(features,1.,0.,"coarse")).status=="ambiguous"
    @test peer_identity_match(state["features"],peer_identity_patch(features,1.,0.,"fine")).peer=="npc_b"
    @test peer_identity_match(state["features"],peer_identity_patch(features,5.,0.,"fine")).status=="ambiguous"
    rear=peer_identity_patch(features,1.,180.,"fine")
    @test count(isnothing,rear.features)==4
    @test peer_identity_match(state["features"],rear).status=="insufficient_observation"
    io=IOBuffer();serialize(io,state);seekstart(io)
    @test deserialize(io)==state
    local_memory=LocalAppearanceMemory("npc_a",Dict(peer=>Tuple(features) for (peer,features) in state["features"]))
    for distance in (1.,3.,5.), rho in ("coarse","medium","fine"), angle in (0.,90.,180.)
        patch=peer_identity_patch(features,distance,angle,rho)
        @test patch.bins==appearance_resolution(distance,Symbol(rho))
        expected=appearance_identify(local_memory,"npc_a",(patches=[patch],complete=true))
        observed=peer_identity_match(state["features"],patch)
        @test observed.status==String(expected.status)
        @test observed.peer==expected.peer
    end
    state["features"]["npc_b"][1]=0.
    @test spec.peer_identity_roster.npc_b.features[1]==.51
    relation=D("test_weights"=>D("npc_b"=>.7))
    world=(positions=Dict("npc_a"=>(0.,0.),"npc_b"=>(1.,0.)),)
    sight=D("peers"=>[D("ref"=>"npc_b","angle"=>0.)])
    peer_identity_observe!(relation,sight,world,"npc_a",Dict("npc_b"=>-90.),spec.peer_identity_roster,0)
    identified=only(relation["identity_observation"]["current"])
    @test identified["name"]=="ハル"
    @test identified["relation_weight"]==.7
    @test length(identified["samples"])==3
end
