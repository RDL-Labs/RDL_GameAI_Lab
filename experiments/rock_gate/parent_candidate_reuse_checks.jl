using Test
include("../../src/lw/LW.jl")
using .LW: D, mb_parent_state, mb_parent_model!, mb_parent_candidates!, mb_parent_estimate!, mb_parent_daily_epoch!, mb_plan_budget
# Original per-candidate evaluation, deliberately kept independent of reuse.
function candidate_reference!(s,candidates,goal,target)
    mb_parent_daily_epoch!(s,goal)
    for p in candidates
        estimate=mb_parent_estimate!(s,p,goal,target)
        p["mb_parent_estimate"]=estimate
        budget=mb_plan_budget(s,estimate,goal)
        if budget!==nothing
            estimate["planning"]=budget
            p["priority"]-=budget["penalty"]
        end
        p["priority"]-=.1log1p(estimate["upper_actions"])
    end
    candidates
end
@testset "candidate reuse preserves forecasts and independent dictionaries" begin
    for goal in ("food","home"), context in (false,true), approach in (false,true), learned in (false,true)
        s=D("parent_mb"=>mb_parent_state(),"goal_arrival"=>D())
        if context
            s["parent_mb"]["resources"]=D("now"=>1000000,"deadline_us"=>20000000,"reserve"=>.1,"metabolic_rate"=>.01)
        end
        if approach
            s["goal_arrival"][goal]=D("mode"=>"approach","estimate"=>D("forward"=>3.,"right"=>4.))
        end
        if learned
            model=mb_parent_model!(s,goal,"search")
            push!(model["observations"],D("actions"=>20.,"energy"=>1.,"completed"=>true,"baseline"=>128.))
        end
        candidates=Any[D("action"=>"scan","priority"=>1.),D("action"=>"walk","priority"=>2.),
            D("action"=>"walk","priority"=>3.,"mb_path"=>["e1","e2"]),D("action"=>"scan","priority"=>4.)]
        for target in (nothing,D("distance"=>12.))
            a=deepcopy(s);b=deepcopy(s);pa=deepcopy(candidates);pb=deepcopy(candidates)
            @test mb_parent_candidates!(a,pa,goal,target)==candidate_reference!(b,pb,goal,target)
            @test a==b
            @test pa[1]["mb_parent_estimate"]!==pa[2]["mb_parent_estimate"]
            pa[1]["mb_parent_estimate"]["probe"]=true
            @test !haskey(pa[2]["mb_parent_estimate"],"probe")
            if context
                pa[1]["mb_parent_estimate"]["planning"]["probe"]=true
                @test !haskey(pa[2]["mb_parent_estimate"]["planning"],"probe")
                a["parent_mb"]["resources"]["reserve"]=30.;b["parent_mb"]["resources"]["reserve"]=30.
            end
            # A later call must see new learned energy estimates/resources.
            for work in (a,b), model in values(work["parent_mb"]["models"])
                model["energy_rate"]=.9
            end
            @test mb_parent_candidates!(a,deepcopy(candidates),goal,target)==candidate_reference!(b,deepcopy(candidates),goal,target)
            @test a==b
        end
    end
end
