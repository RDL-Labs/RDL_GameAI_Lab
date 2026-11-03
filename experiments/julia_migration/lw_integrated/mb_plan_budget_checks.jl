include(joinpath(@__DIR__,"mb_parent_checks.jl"))
@testset "forecast and available resources are separate" begin
 s=mb_map_state("budget")
 mb_plan_context!(s,10_000_000,100_000_000,10.,1.)
 short=D("expected_actions"=>10.,"expected_energy"=>1.)
 long=D("expected_actions"=>1000.,"expected_energy"=>20.)
 b=mb_plan_budget(s,short,"home");bad=mb_plan_budget(s,long,"home")
 @test b["penalty"]==0
 @test bad["penalty"]>0 && bad["deadline_us"]==b["deadline_us"]
 @test long["expected_actions"]==1000. # no falsified optimistic forecast
 @test b["predicted_energy_with_metabolism"]==2.
 p=D("method"=>"rest","action"=>"rest","priority"=>1.)
 mb_parent_candidates!(s,[p],"home",nothing)
 @test p["mb_parent_estimate"]["planning"]["time_gap"]>0
 mb_parent_begin!(s,p,"home",nothing,10_000_000)
 a=s["parent_mb"]["active"]["home"];frozen=deepcopy(a["estimate"])
 mb_parent_record!(s,p,.001,10_000_000)
 @test mb_parent_H_increment!(s,"home","op:10000000:budget",false,11_000_000)>0
 @test last(s["parent_mb"]["records"])["delay"]==0 # still inside statistical estimate
 @test last(s["parent_mb"]["records"])["planning_pressure"]>0
 mb_plan_context!(s,101_000_000,100_000_000,5.,10.)
 @test mb_plan_budget(s,long,"home")["deadline_us"]==100_000_000
 @test a["estimate"]==frozen
 @test mb_plan_pressure(s,a,101_000_000)>0
 # Approach inherits the suspended parent's resource deadline.
 delete!(s["parent_mb"]["active"],"home")
 s["parent_mb"]["modes"]=D("home"=>D("suspended"=>a))
 @test mb_plan_budget(s,short,"home")["deadline_us"]==100_000_000
 # Body depletion is separate from operation cost and time overrun.
 mb_plan_context!(s,20_000_000,100_000_000,.1,2.)
 @test mb_plan_budget(s,short,"food")["energy_gap"]>0
 @test mb_plan_pressure(s,a,20_000_000)>0
end
