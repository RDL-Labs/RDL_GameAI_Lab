using Test, Serialization
include("../../src/lw/LW.jl")
const A=LW
@testset "LW food aroma connection" begin
 m=A.D(); state=A.D()
 A.food_aroma_update!(state,m,"process_food","processing",7,Int[],0)
 @test A.food_aroma_strength(state["world_food_aroma"],0)==1
 @test A.food_aroma_strength(state["world_food_aroma"],60_000_000)==0
 cue=[(actor="other",position=(0.,0.),features=A.food_aroma_feature(7),strength=1.)]
 A.food_aroma_observe!(m,"self",(0.,0.),cue,0)
 @test isempty(m["food_aroma"]["active"])
 A.food_remember_taste!(m,7,2,1.5,0); A.food_aroma_learn!(m,7,2)
 A.food_aroma_observe!(m,"self",(0.,0.),cue,1)
 @test A.food_aroma_bonus(m,7,2,1.5)≈.525
 @test m["food_taste_experiences"][A.food_taste_key(7,2)]["samples"]==1
 A.food_aroma_observe!(m,"self",(4.,0.),cue,2)
 @test A.food_aroma_bonus(m,7,2,1.5)≈.2625
 A.food_aroma_observe!(m,"other",(0.,0.),cue,3)
 @test A.food_aroma_bonus(m,7,2,1.5)==0
 A.food_aroma_update!(state,m,"process_food","processed",7,[7],0)
 @test A.food_aroma_strength(state["world_food_aroma"],120_000_000)==.7
 states=Dict(a=>deepcopy(state) for a in A.IDS)
 positions=Dict(a=>(0.,0.) for a in A.IDS); inventory=Dict(a=>Int[] for a in A.IDS)
 rows=A.food_aroma_snapshot(states,positions,inventory,120_000_000)
 @test length(rows)==length(A.IDS)
 @test isempty(A.food_aroma_snapshot(states,positions,inventory,180_000_000))
 io=IOBuffer();serialize(io,(states,m));seekstart(io);restored=deserialize(io)
 @test restored==(states,m)
 A.food_aroma_observe!(m,"self",(0.,0.),cue,4)
 A.food_aroma_observe!(m,"self",(0.,0.),Any[],5)
 @test isempty(m["food_aroma"]["active"])
end
@testset "aroma changes existing meal score only" begin
 m=A.D(); actor="npc_a"; foods=(inventory=Dict(actor=>UInt8[7]),)
 stores=zeros(Int,8)
 A.food_remember_taste!(m,7,2,1.5,0); A.food_aroma_learn!(m,7,2)
 choices()=A.food_desire_candidates(m,foods,actor,nothing,60.,true,stores,[],(0.,0.))
 before=choices()
 cue=[(actor="other",position=(0.,0.),features=A.food_aroma_feature(7),strength=1.)]
 A.food_aroma_observe!(m,actor,(0.,0.),cue,1)
 after=choices()
 @test getindex.(before,"method")==getindex.(after,"method")
 meal(rows)=only(c for c in rows if get(c,"food_kind",0)==7)
 @test meal(after)["priority"]-meal(before)["priority"]≈.525
 @test meal(after)["expected_liking"]==meal(before)["expected_liking"]
 A.food_aroma_observe!(m,actor,(0.,0.),Any[],2)
 @test choices()==before
end
