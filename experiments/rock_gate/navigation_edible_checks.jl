using Test, JSON3
include("../../integrations/lightweight_julia/native.jl")
include("navigation_edible_profile.jl")
@testset "processing-free navigation profile preserves resource quantities" begin
    input=Dict("scene"=>Dict{String,Any}("food"=>[Dict("x"=>2,"z"=>3,"stock"=>9,"food_kind"=>3)],
        "initial_inventory_kinds"=>[[3,1],[4]],"initial_personal_food_counts"=>Dict("a"=>[2,1,3,4]),
        "initial_shared_food_counts"=>[1,2,3,4]))
    navigation_edible_profile!(input);s=input["scene"]
    @test s["food_processing"]===false
    @test s["food"]==[Dict("x"=>2,"z"=>3,"stock"=>9,"food_kind"=>1)]
    @test s["initial_inventory_kinds"]==[[1,1],[4]]
    @test s["initial_personal_food_counts"]["a"]==[5,1,0,4]
    @test s["initial_shared_food_counts"]==[4,2,0,4]
    saved=deepcopy(input);navigation_edible_profile!(input);@test saved==input
end
@testset "edible food integrates without processing" begin
    input=JSON3.read(read(joinpath(@__DIR__,"../julia_migration/lw_integrated/search_review_spec.json"),String),Dict{String,Any})
    input["scene"]["typed_food"]=true
    input["scene"]["initial_inventory"]=fill(1,3)
    input["scene"]["initial_inventory_kinds"]=[[3] for _ in 1:3]
    input["scene"]["reserve"]=fill(60.,3)
    input["config"]["days"]=1;input["config"]["body_purpose"]="on"
    input["clock"]["day_us"]=600_000_000
    input["clock"]["phase_boundaries_us"]=[1_000_000,2_000_000,3_000_000,600_000_000]
    input["clock"]["quiet_night_us"]=4_000_000
    navigation_edible_profile!(input)
    r,_=run_integrated(JSON3.read(JSON3.write(input)))
    @test all(get(c,"process_food",0)==0 for c in values(r["counts"]))
    @test r["consumed"]>=3
    @test all(==(0),values(r["food_resources"]["work_ticks"]))
    @test r["initial_food"]+r["replenished_food"]==r["ground"]+r["shared_stock"]+r["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(r["final_agents"]))
end
