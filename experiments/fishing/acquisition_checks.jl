using Test, Serialization
include("../../src/lw/LW.jl")
@testset "hierarchical acquisition residual and contextual pressure" begin
 m=LW.mb_map_state(first(LW.IDS));method="fishing"
 LW.acquisition_result!(m,method,1,100.,99.,false)
 @test m["acquisition"]["sites"]["fishing:1"]["H"]==0
 LW.acquisition_result!(m,method,1,10000.,51.,false)
 @test m["acquisition"]["sites"]["fishing:1"]["forecast"]==100
 @test m["acquisition"]["sites"]["fishing:1"]["H"]==.5
 v=LW.acquisition_value(m,method,1,100.,1.,0.)
 other=LW.acquisition_value(m,method,2,100.,1.,0.)
 @test v.local_repulsion>other.local_repulsion
 @test v.method_repulsion==0
 urgent=LW.acquisition_value(m,method,2,100.,1.,5.)
 @test urgent.method_repulsion>0 && urgent.urgency>0
 @test urgent.score<other.score
 @test LW.acquisition_value(m,method,2,100.,1.,0.)==other # no permanent need penalty
 LW.acquisition_result!(m,method,2,100.,50.,true)
 @test m["acquisition"]["methods"][method]["H"]==0
 @test m["acquisition"]["sites"]["fishing:1"]["H"]==.5 # other site history intact
 LW.acquisition_result!(m,"hunting",3,100.,150.,false)
 @test m["acquisition"]["sites"]["hunting:3"]["H"]==.5
 @test m["acquisition"]["methods"]["fishing"]["H"]==0
 # Serializing forecasts preserves unresolved pressure.
 io=IOBuffer();serialize(io,m);seekstart(io);copy=deserialize(io)
 @test copy["acquisition"]["sites"]==m["acquisition"]["sites"]
end
@testset "uncertain acquisition reaches food security" begin
 m=LW.mb_map_state(first(LW.IDS));s=LW.acquisition_state();m["acquisition"]=s
 s["choice"]=LW.D("seconds"=>100.,"uncertainty"=>0.,"technique"=>"pickup")
 a=LW.food_security_state();b=LW.food_security_state();body=LW.RDLBody.Body(10.,0.,80.,0.)
 LW.food_security_update!(a,m,body,nothing,zeros(Int,7),Int[],0.,0,17280000000)
 s["choice"]=LW.D("seconds"=>10000.,"uncertainty"=>.99,"technique"=>"fishing")
 LW.food_security_update!(b,m,body,nothing,zeros(Int,7),Int[],0.,0,17280000000)
 @test b["estimate"]["horizon_seconds"]>a["estimate"]["horizon_seconds"]
 @test b["H"]>a["H"]
end
@testset "method comparison and atomic trial continuation" begin
 m=LW.mb_map_state(first(LW.IDS));m["daily_plan"]=LW.mb_daily_plan_state(first(LW.IDS),1)
 loop=LW.BasicLoop("acquisition-test";probabilistic=true,seed=1)
 visible=Any[LW.D("ref"=>1,"distance"=>1.,"appearance"=>"river_water","acquisition"=>"fishing","acquisition_seconds"=>3600.,"acquisition_uncertainty"=>.95),LW.D("ref"=>2,"distance"=>5.,"appearance"=>"red_round_fruit")]
 LW.acquisition_targets!(m,visible,loop,0;home=LW.D("distance"=>3.),anxiety=3.)
 rows=last(m["acquisition"]["records"])["candidates"]
 fish=only(filter(v->v["technique"]=="fishing",rows));fruit=only(filter(v->v["technique"]=="pickup",rows))
 @test fish["seconds"]==3732.
 @test fruit["priority"]>fish["priority"]
 @test visible[1]["ref"]==1 # observation never rewritten
 m["acquisition"]["choice"]=fish
 @test only(LW.acquisition_targets!(m,visible,loop,100000000;committed_ref=1))["ref"]==1
 evidence=LW.mb_daily_evidence(m,LW.D("visible"=>visible),80.,0.,0)
 @test evidence["seconds"]==fish["acquire_seconds"]==3601.
end
@testset "stalled approach does not scale another trip or an exploration" begin
 m=LW.mb_map_state(first(LW.IDS))
 m["goal_arrival"]=LW.D("food"=>LW.D("mode"=>"approach","estimate"=>LW.D("forward"=>13.5,"right"=>0.)))
 model=LW.mb_parent_model!(m,"food","approach")
 push!(model["observations"],LW.D("actions"=>1129,"baseline"=>1.,"completed"=>false))
 estimate=LW.mb_parent_estimate!(m,LW.D(),"food",nothing)
 @test estimate["expected_actions"]==40 && estimate["upper_actions"]==80
 search=LW.mb_parent_estimate!(m,LW.D(),"food",nothing;use_arrival=false)
 @test search["model"]=="food:search" && search["upper_actions"]==256
end
@testset "parent learns a delay on the observed route only" begin
 m=LW.mb_map_state(first(LW.IDS))
 short=LW.D("mb_path"=>["one"]); longer=LW.D("mb_path"=>["one","two","three"])
 first_est=LW.mb_parent_estimate!(m,short,"home",nothing)
 model=m["parent_mb"]["models"][first_est["model"]]
 push!(model["observations"],LW.D("baseline"=>1,"actions"=>1129,"completed"=>false))
 stalled=LW.mb_parent_estimate!(m,short,"home",nothing)
 other=LW.mb_parent_estimate!(m,longer,"home",nothing)
 @test stalled["upper_actions"]==1411
 @test other["model"]!=stalled["model"] && other["expected_actions"]==3
 LW.acquisition_result!(m,"pickup",1,10.,10.,true)
 LW.acquisition_result!(m,"pickup",1,100.,50.,false)
 @test m["acquisition"]["sites"]["pickup:1"]["forecast"]==100
 @test m["acquisition"]["methods"]["pickup"]["H"]==0
end
