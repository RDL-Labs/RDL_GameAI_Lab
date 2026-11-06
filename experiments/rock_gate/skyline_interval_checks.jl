include("predictive_skyline_checks.jl")
@testset "adaptive confirmation interval" begin
 sample()=D("coverage"=>"complete","source"=>"fresh","features"=>Any[D("color"=>"red","azimuth"=>[-7.5,7.5],"range_band"=>"far","elevation"=>15)])
 receipt(t;step=.1,turn=0.)=D("forward"=>step,"right"=>0.,"yaw"=>turn,"after_us"=>t*1_000_000)
 s=skyline_state()
 for t in 0:32
  interval_skyline!(sample,s,t==0 ? nothing : receipt(t),t*1_000_000,string(t);enabled=true,distance=100.,uncertain=false)
 end
 c=s["interval_observation"]
 @test c["interval"]==16.
 @test c["skipped"]>20
 @test c["fresh"]<10
 @test c["max_interval"]==16.
 v=interval_skyline!(sample,s,receipt(33;step=1.),33_000_000,"33";enabled=true,distance=1.,uncertain=false)
 @test v["coverage"]=="complete"
 @test c["reasons"]["due"]>0
 v=interval_skyline!(sample,s,receipt(34),34_000_000,"34";enabled=true,distance=100.,uncertain=false,pressure=1.)
 @test v["coverage"]=="complete"
 @test c["reasons"]["forecast_residual"]==1
 @test c["interval"]==1.
 interval_skyline!(sample,s,receipt(35;step=0.),35_000_000,"35";enabled=true,distance=100.,uncertain=false,pressure=1.)
 @test c["reasons"]["stalled"]==1
 q=skyline_state()
 for t in 0:20
  interval_skyline!(sample,q,t==0 ? nothing : receipt(t),t*1_000_000,string(t);enabled=true,uncertain=true)
 end
 @test q["interval_observation"]["max_interval"]<=2
 @test q["interval_observation"]["skipped"]>0
 v=interval_skyline!(sample,q,receipt(22),22_000_000,"22";enabled=true)
 @test v["coverage"]=="complete"
 @test q["interval_observation"]["reasons"]["gap"]==1
end
@testset "initial plan not yet created" begin
 inputs=skyline_schedule_inputs(D("daily_plan"=>D("active"=>nothing)),nothing,D("visible"=>Any[]),nothing)
 @test inputs.context==""
 @test inputs.uncertain
 @test isinf(inputs.distance)
end
