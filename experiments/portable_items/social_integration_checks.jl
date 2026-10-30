using Test, JSON3
include("../../src/lw/LW.jl")
# A short contact fixture, not an exchange script: actors remain at home in the
# return phase; their choice of proposal, terms and response is autonomous.
clock=merge(LW.native_clock(),(day_us=512_000_000,
    phase_boundaries_us=[0,0,512_000_000,512_000_000],quiet_night_us=512_000_000))
scene=merge(LW.native_scene(19),(positions=[[0.,0.],[.1,0.],[0.,.1]],home=[0.,0.],
    food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
    initial_inventory=[0,0,0],reserve=[95.,95.,95.],incidental_items=true,social_relationships=true,
    loose_items=Any[(id=i,kind=i,owner=LW.IDS[i],location="held",x=0.,z=0.) for i in 1:3]))
@testset "LW autonomous item negotiation and checkpoint continuation" begin
    mktempdir() do dir
        run(;kwargs...)=LW.lw_day(scene,clock;days=2,basic_loop=true,landmark_routes=true,choice_seed=33,kwargs...)
        r=run(checkpoint_dir=dir)
        resumed=run(resume_from=joinpath(dir,"day-001.jls"))
        @test r["portable_items"]==resumed["portable_items"]
        @test r["incidental_items"]==resumed["incidental_items"]
        @test r["social_relationships"]==resumed["social_relationships"]
        @test r["portable_items"]["counts"]["offered"]>0
        # Quantity utility changes which near-equal swaps fall inside the
        # existing -.01 admissibility band. Check valuations, not a fixed count.
        receipts=[e for s in values(r["incidental_items"]) for e in s["social"]["records"] if e["status"]=="exchanged"]
        @test length(receipts)==2*r["portable_items"]["counts"]["exchanged"]
        @test all(e->e["actual"]>=-.01 && e["subjective_gain"]>=-.01,receipts)
        @test sum(m["successes"] for s in values(r["incidental_items"]) for m in s["exchange_relations"])==length(receipts)
        @test r["portable_items"]["counts"]["unavailable"]==0 # no food terms when food subsystem is absent
        @test r["portable_items"]["counts"]["declined"]>0
        @test r["portable_items"]["remaining_counts"]==[1,1,1]
        @test all(x["social"]["decisions"]>0 for x in values(r["incidental_items"]))
        @test r["consumed"]==0
        println(JSON3.write(r["portable_items"]["counts"]))
        println(JSON3.write(receipts))
    end
end
