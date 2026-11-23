include("compare.jl")
length(ARGS)==1 || error("usage: square_comparison.jl NEW_JSON")
ispath(ARGS[1]) && error("output exists")
function summarize_demand(run)
    rows=filter(x->x.day==10 && x.phase!="end",run.timeline)
    timed=filter(x->x.phase!="before_meal",rows)
    (;mean=sum(x.body_demand for x in timed)/length(timed),peak=maximum(x.body_demand for x in rows))
end
report=Dict{String,Any}()
@testset "square versus equal-weight linear" begin
    for (name,shares) in pairs(DIET_COMPARISON)
        linear=simulate(meal_shares=shares,parameters=MacroParameters(body_demand_squared=false))
        square=simulate(meal_shares=shares)
        @test length(linear.timeline)==length(square.timeline)
        excluded=(:body_demand,:sugar_demand,:fat_demand,:protein_demand)
        physical_keys=filter(k->k ∉ excluded,keys(first(linear.timeline)))
        @test all(all(getproperty(a,k)==getproperty(b,k) for k in physical_keys)
                  for (a,b) in zip(linear.timeline,square.timeline))
        @test all(b.body_demand<=a.body_demand+1e-12 for (a,b) in zip(linear.timeline,square.timeline))
        report[string(name)]=(;linear=summarize_demand(linear),square=summarize_demand(square))
    end
end
write(ARGS[1],JSON3.write(report));println(JSON3.write(report))
