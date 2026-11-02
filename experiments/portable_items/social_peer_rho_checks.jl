using Test, Serialization
include("checks.jl")
@testset "social rho resolves peers without erasing weak relations" begin
    peers=["peer_$i" for i in 1:9]
    relation=LW.social_relations_state("owner")
    loop=LW.BasicLoop("owner:offer";probabilistic=true,seed=17)
    before=deepcopy(loop.rng)
    @test LW.social_peer_scope!(relation,peers,loop,0.,0)==peers
    @test rand(loop.rng)==rand(before)
    relation["peer_rho_enabled"]=true
    copyloop=deepcopy(loop)
    a=LW.social_peer_scope!(relation,peers,loop,0.,1)
    @test length(a)==2 && all(in(peers),a) && length(unique(a))==2
    @test a==LW.social_peer_scope!(deepcopy(relation),peers,copyloop,0.,1)
    @test last(relation["peer_resolution"]["records"])["coarse_group_count"]==7
    loop.H=32.
    @test LW.social_peer_scope!(relation,peers,loop,0.,2)==peers
    loop.H=0.
    @test length(LW.social_peer_scope!(relation,peers,loop,4.,3))==9
    @test LW.social_peer_scope!(relation,String[],loop,0.,4)==String[]
    @test LW.social_peer_scope!(relation,peers[1:2],loop,0.,4)==peers[1:2]
    p=LW.social_relation_peer();p["contact_seconds"]=3600.;p["trade_value_samples"]=100
    relation["peers"][peers[1]]=p
    saved=deepcopy(relation["peers"]);hits=Dict(x=>0 for x in peers)
    for seed in 1:200
        l=LW.BasicLoop("owner:offer";probabilistic=true,seed)
        for x in LW.social_peer_scope!(relation,peers,l,0.,seed);hits[x]+=1;end
    end
    @test all(>(0),values(hits))
    @test hits[peers[1]]>maximum(hits[x] for x in peers[2:end])
    @test relation["peers"]==saved
    @test length(relation["peer_resolution"]["records"])==64
    io=IOBuffer();serialize(io,(relation,loop));seekstart(io);r,l=deserialize(io)
    @test LW.social_peer_scope!(r,peers,l,0.,300)==LW.social_peer_scope!(relation,peers,loop,0.,300)
end

@testset "both trade planners scope before candidate expansion" begin
    f=item_fixture(objects=[placed_item(1,1;owner=ITEM_A,location="held")])
    peers=["observed_peer_$i" for i in 1:9] # synthetic observed contacts
    relation=LW.social_relations_state(ITEM_A);relation["peer_rho_enabled"]=true
    state=LW.incidental_item_state(ITEM_A,11)
    v=item_view(f,ITEM_A);v["trade_partners"]=peers
    LW.item_social_plan!(state,v,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],0;relation)
    @test relation["peer_resolution"]["calls"]==1
    @test relation["peer_resolution"]["detailed"]==2
    trade=LW.food_trade_state(11)
    view=LW.D("own_stock"=>[4,0,3,0],"partners"=>peers,"incoming"=>Any[],"outgoing"=>nothing)
    LW.food_trade_plan!(trade,ITEM_A,view,f.w.bodies[ITEM_A],nothing,0;relation)
    @test relation["peer_resolution"]["calls"]==2
    @test relation["peer_resolution"]["detailed"]==4
    @test relation["peer_resolution"]["available"]==18
end
