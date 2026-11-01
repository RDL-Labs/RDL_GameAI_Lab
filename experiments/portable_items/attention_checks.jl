include("checks.jl")
@testset "purpose-directed intermittent item observation" begin
    f=item_fixture(objects=[placed_item(1,1;z=.8),placed_item(2,2;z=5.)])
    f.w.positions[ITEM_A]=(0.,0.);empty!(f.w.obstacles)
    state=LW.incidental_item_state(ITEM_A,19)
    look(t;kwargs...)=LW.item_attention_view!(state,f.s,f.w,ITEM_HOME,ITEM_A,0.,t;kwargs...)
    v=look(0;purpose=:pickup)
    @test [r["ref"] for r in v["visible"]]==[1]
    @test state["attention"]["last_amount"]=="few"
    seq=state["loop"].sequence
    @test look(1_000_000;purpose=:pickup)===nothing
    @test state["loop"].sequence==seq
    @test state["attention"]["details"]==1
    # A fresh look cannot reuse an old reachable object after it moved away.
    f.s["items"][1]["position"]=(0.,30.)
    v=look(40_000_000;purpose=:pickup)
    @test isempty(v["visible"])
    # Coarse cue detection still respects occlusion.
    push!(f.w.obstacles,LW.RDLMigrationProbe.Circle(0.,2.,.5))
    @test look(80_000_000;purpose=:pickup)===nothing
    @test state["attention"]["last_amount"]=="none"
    mind=LW.item_social_state!(state);mind["next_us"]=200_000_000
    @test look(90_000_000;purpose=:trade)===nothing
    @test state["attention"]["trade_details"]==0
    empty!(f.w.obstacles);f.w.positions[ITEM_B]=(0.,.1)
    f.s["offers"]["incoming"]=LW.D("id"=>"incoming","target"=>ITEM_A,"proposer"=>ITEM_B,
        "expires_us"=>110_000_000)
    @test length(look(100_000_000;purpose=:trade)["incoming"])==1
    @test state["attention"]["trade_details"]==1
    @test look(111_000_000;purpose=:trade)===nothing
    restored=item_saved_copy(state)
    @test restored["attention"]==state["attention"]
    @test LW.incidental_item_snapshot(state)["attention"]==state["attention"]
end
