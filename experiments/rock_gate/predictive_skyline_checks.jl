using Test
D(args...)=Dict{String,Any}(args...)
include("../../src/lw/perception/skyline.jl")
@testset "predictive skyline" begin
 sample()=D("coverage"=>"complete","source"=>"ob:0:a","features"=>Any[D("color"=>"red","azimuth"=>[-7.5,7.5],"range_band"=>"far","elevation"=>15)])
 receipt(t;step=.1,turn=0.)=D("forward"=>step,"right"=>0.,"yaw"=>turn,"after_us"=>t)
 s=skyline_state()
 @test predicted_skyline!(sample,s,nothing,0,"ob:0:a";enabled=true)["coverage"]=="complete"
 v=predicted_skyline!(sample,s,receipt(1_000_000),1_000_000,"ob:1:a";enabled=true)
 @test v["coverage"]=="predicted"
 @test v["source"]=="ob:1:a"
 record_skyline!(s,v);@test s["observations"]==0
 @test s["prediction"]["reused"]==1
 @test predicted_skyline!(sample,s,receipt(2_000_000),2_000_000,"ob:2:a";enabled=true,fine=true)["coverage"]=="complete"
 @test predicted_skyline!(sample,s,receipt(3_000_000;step=0.),3_000_000,"ob:3:a";enabled=true)["coverage"]=="complete"
 @test predicted_skyline!(sample,s,receipt(4_000_000;turn=10.),4_000_000,"ob:4:a";enabled=true)["coverage"]=="complete"
 @test predicted_skyline!(sample,s,receipt(8_000_000),8_000_000,"ob:8:a";enabled=true)["coverage"]=="complete"
 @test s["prediction"]["reason"]=="gap"
 @test predicted_skyline!(sample,s,receipt(9_000_000),9_000_000,"ob:9:a")["coverage"]=="complete"
 near()=D("coverage"=>"complete","source"=>"near","features"=>Any[D("color"=>"red","azimuth"=>[-7.5,7.5],"range_band"=>"near","elevation"=>15)])
 n=skyline_state();predicted_skyline!(near,n,nothing,0,"0";enabled=true)
 @test predicted_skyline!(near,n,receipt(1_000_000),1_000_000,"1";enabled=true)["coverage"]=="complete"
 q=skyline_state();predicted_skyline!(sample,q,nothing,0,"0";enabled=true)
 for t in 1:3
  @test predicted_skyline!(sample,q,receipt(t*1_000_000),t*1_000_000,string(t);enabled=true)["coverage"]=="predicted"
 end
 @test predicted_skyline!(sample,q,receipt(4_000_000),4_000_000,"4";enabled=true)["coverage"]=="complete"
 @test q["prediction"]["reason"]=="age"
end
