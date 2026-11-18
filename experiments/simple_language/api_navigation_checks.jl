using JSON3,Test
const OUTPUT=mktempdir()
const ANGLES=(-90,-45,0,45,90)
include("../../src/lw/configured_paths/api_trade_agent.jl")
include("../../src/lw/configured_paths/api_navigation.jl")
choose_method!(loop,candidates,source)=deepcopy(first(candidates))
@testset "API navigation continuation and boundary" begin
    candidates=[Dict{String,Any}("method"=>"step_$angle","action"=>"walk","direction"=>i-1) for (i,angle) in enumerate(ANGLES)]
    @test configured_api_nav_projection(candidates[4],0.).heading_degrees==45.
    CONFIGURED_API_NAV["next_us"]=1000
    CONFIGURED_API_NAV["method"]="step_45"
    CONFIGURED_API_NAV["heading"]=45.
    plan=configured_api_navigation!("npc_e",nothing,candidates,"s",nothing,nothing,1,45.,nothing)
    @test plan["direction"]==2 # no repeated 45-degree turn on each tick
    @test !haskey(candidates[1],"api_movement")
    @test configured_api_navigation!("npc_e",nothing,Any[],"s",nothing,nothing,2,45.,nothing)["action"]=="rest"
    @test configured_api_navigation!("npc_a",nothing,candidates,"s",nothing,nothing,2,45.,nothing)==first(candidates)
    configured_api_nav_result!("npc_e","walk","blocked",1)
    @test CONFIGURED_API_HISTORY[end].ticks["walk:blocked"]==1
end
