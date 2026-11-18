using JSON3,Test
const OUTPUT=mktempdir()
include("../../integrations/lightweight_julia/native.jl")
include("../../src/lw/configured_paths/api_trade_agent.jl")
include("../../src/lw/configured_paths/api_navigation.jl")
@testset "Common navigation selection boundary" begin
    calls=Ref(0);received=Ref{Any}(nothing)
    selector=(loop,options,source,state,view,body,stock,now)->begin
        calls[]+=1;received[]=(options=options,view=view)
        choose_method!(loop,[first(options)],source)
    end
    candidates=[Dict{String,Any}("method"=>"step_0","action"=>"walk","direction"=>2,"priority"=>1.,"question"=>"target_nearer",
        "mb_parent_estimate"=>Dict("expected_actions"=>10),"private_world"=>"DO_NOT_PROJECT")]
    for now in (1,2)
        plan=configured_api_navigation!("npc_e",BasicLoop("nav$now"),candidates,"s",nothing,nothing,now,0.,nothing;
            selector,navigation_context=(purpose="home",observed_target=(distance=3.,)))
        @test plan["method"]=="step_0"
    end
    @test calls[]==2 # no E-only timing cache
    @test length(received[].options)==length(candidates) # no extra wait candidate
    projected=configured_api_option(received[].options[1],received[].view,1)
    @test projected.own_MB["mb_parent_estimate"]["expected_actions"]==10
    @test !occursin("DO_NOT_PROJECT",JSON3.write(projected))
    @test received[].view["navigation"].context.purpose=="home"
    @test !haskey(candidates[1],"api_belief")
    @test configured_api_navigation!("npc_e",BasicLoop("empty"),Any[],"s",nothing,nothing,3,0.,nothing;selector)===nothing
    configured_api_navigation!("npc_a",BasicLoop("other"),candidates,"s",nothing,nothing,3,0.,nothing;selector)
    @test calls[]==2
    configured_api_nav_result!("npc_e","walk","blocked",3);configured_api_nav_flush!(3)
    @test CONFIGURED_API_HISTORY[end].ticks["walk:blocked"]==1
    CONFIGURED_API_CALLS[1]=CONFIGURED_API_AGENT.total_calls
    @test_throws ConfiguredAPIBudgetStop configured_api_navigation!("npc_e",BasicLoop("budget"),candidates,"s",nothing,nothing,4,0.,nothing;selector,budget_capture=()->Dict(:sentinel=>1))
    @test deserialize(joinpath(OUTPUT,"api-budget-state.bin")).state[:sentinel]==1
    @test JSON3.read(read(joinpath(OUTPUT,"stopped.json"),String)).reason=="API_budget"
end
