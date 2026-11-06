include("spoilage_learning_checks.jl")
@testset "shared expiry budget reaches meals, exchanges and acquisition" begin
 D=LW.D;B=LW.RDLBody;day=17_280_000_000
 m=LW.mb_map_state(A);body=B.Body(10.,0.,95.,0.);g=B.Digestion()
 now=day-60_000_000;m["food_clock"]=(now=now,day_us=day)
 f=LW.food_expiry_forecast(m,body,g)
 counts=zeros(Int,8);counts[7]=3;counts[8]=3
 @test LW.food_expected_waste(counts,f)≈.5*(6-f["capacity"])
 @test LW.food_expected_waste(counts,f)>LW.food_expected_waste(counts,LW.food_expiry_forecast(m,body,g;now=0))
 stable=zeros(Int,8);stable[1]=6
 @test LW.food_expected_waste(stable,f)<LW.food_expected_waste(counts,f)
 security=LW.food_security_state();security["expiry"]=f;security["required"]=1.
 v=LW.trade_valuation_context(body,g,security,D(),nothing)
 after=copy(counts);after[7]-=1
 gradient=LW.trade_compound_gradient(counts,after,-.1,v)
 @test gradient["waste_relief"]>0
 @test LW.trade_compound_gradient(after,counts,.1,v)["waste_relief"]<0
 f["capacity"]=100 # frozen prediction is not aliased to the live forecast
 @test v["expiry"]["capacity"]<1
 foods=(inventory=Dict(A=>UInt8[1,7]),)
 rows=LW.food_desire_candidates(m,foods,A,g,95.,true,zeros(Int,8),[],(0.,0.))
 fish=only(c for c in rows if get(c,"food_kind",0)==7)
 fruit=only(c for c in rows if get(c,"food_kind",0)==1)
 @test fish["loss_risk"]>fruit["loss_risk"]>0
 m["food_clock"]=(now=0,day_us=day)
 early=only(c for c in LW.food_desire_candidates(m,foods,A,g,95.,true,zeros(Int,8),[],(0.,0.)) if get(c,"food_kind",0)==7)
 @test early["expiry_relief"]<fish["expiry_relief"]
 m["food_clock"]=(now=now,day_us=day)
 m["daily_plan"]=LW.mb_daily_plan_state(A,1)
 visible=Any[D("ref"=>1,"distance"=>1.,"appearance"=>"river_water","acquisition"=>"fishing","acquisition_seconds"=>180.,"acquisition_uncertainty"=>.5)]
 loop=LW.BasicLoop("expiry-acquisition";probabilistic=true,seed=1)
 LW.acquisition_targets!(m,visible,loop,now;body,gut=g,owned=counts,home=D("distance"=>1.))
 row=only(c for c in last(m["acquisition"]["records"])["candidates"] if c["ref"]==1)
 @test row["expected_extra_waste"]>0
 @test row["priority"]<row["gradient"].score
 @test !haskey(visible[1],"expected_extra_waste")
end
