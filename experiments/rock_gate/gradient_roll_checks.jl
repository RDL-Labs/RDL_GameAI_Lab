using Test
D(args...)=Dict{String,Any}(args...)
const ANGLES=[-90.,-45.,0.,45.,90.]
include("../../src/lw/decision/gradient_roll.jl")
target(f,r=0.)=D("forward"=>f,"right"=>r,"distance"=>hypot(f,r))
receipt(t;f=.5,r=0.,yaw=0.)=D("after_us"=>t*1_000_000,"forward"=>f,"right"=>r,"yaw"=>yaw)
p=D("action"=>"walk","method"=>"step_2","direction"=>2,"question"=>"target_nearer")
@testset "distance-based continuation" begin
 m=D();gradient_roll_enroll!(m,p,0,0.,"food","exploration",0.,target(20.))
 for t in 1:10
  q=gradient_roll_plan!(m,receipt(t),t*1_000_000,0.,"food","exploration",0.,target(20.0 - .5t))
  @test q!==nothing && q["gradient_roll"]
 end
 @test m["gradient_roll"]["enrolled"]==1
 @test m["gradient_roll"]["confirmed"]>=3
 for (f,r) in ((-.5,0.),(0.,.5))
  n=D();gradient_roll_enroll!(n,p,0,0.,"food","exploration",0.,target(20.))
  @test gradient_roll_plan!(n,receipt(1;f,r),1_000_000,0.,"food","exploration",0.,target(20.0 - f,-r))===nothing
  @test n["gradient_roll"]["reasons"]["distance_shortfall"]==1
 end
 n=D();gradient_roll_enroll!(n,p,0,0.,"food","exploration",0.,nothing)
 @test !n["gradient_roll"]["active"]
 n=D();gradient_roll_enroll!(n,p,0,0.,"food","exploration",0.,target(20.))
 q=gradient_roll_plan!(n,receipt(1;yaw=90.),1_000_000,90.,"food","exploration",0.,nothing)
 @test q!==nothing
 @test n["gradient_roll"]["target_right"]≈-19.5
 @test q["steering_angle"]≈-90.
 for t in 2:9
  gradient_roll_plan!(n,receipt(t;f=0.,r=-.5),t*1_000_000,90.,"food","exploration",0.,nothing)
 end
 @test !n["gradient_roll"]["active"]
 @test n["gradient_roll"]["reasons"]["target_uncertain"]==1
 n=D();gradient_roll_enroll!(n,p,0,0.,"food","exploration",0.,target(1.9))
 @test gradient_roll_plan!(n,receipt(1),1_000_000,0.,"food","exploration",0.,target(1.4))!==nothing
 @test n["gradient_roll"]["interval"]==1.
 @test gradient_roll_plan!(n,receipt(2),2_000_000,0.,"food","exploration",0.,target(.9))===nothing
 n=D();gradient_roll_enroll!(n,p,0,0.,"food","exploration",0.,target(20.))
 @test gradient_roll_plan!(n,receipt(1),1_000_000,0.,"food","exploration",0.,target(5.,10.))===nothing
 @test n["gradient_roll"]["reasons"]["target_mismatch"]==1
end

@testset "fixed 30 distance transition" begin
 m=D();gradient_roll_enroll!(m,p,0,0.,"food","exploration",0.,target(31.);direction_distance=30.)
 q=gradient_roll_plan!(m,receipt(1),1_000_000,0.,"food","exploration",0.,target(30.5))
 @test q["gradient_roll_mode"]=="direction"
 q=gradient_roll_plan!(m,receipt(2),2_000_000,0.,"food","exploration",0.,target(30.))
 @test q["gradient_roll_mode"]=="approach"
 @test m["gradient_roll"]["mode_switches"]==1
 @test m["gradient_roll"]["direction_ticks"]==1
 @test m["gradient_roll"]["approach_ticks"]==1
end
@testset "selected landmark continuation" begin
 cue=merge(p,D("method"=>"cue:shape:ochre:0","question"=>"target_observed","cue_kind"=>"shape","cue_label"=>"ochre","cue_angle"=>0.,"cue_distance"=>40.))
 m=D();gradient_roll_enroll!(m,cue,0,0.,"home","return",0.,nothing;direction_distance=30.)
 @test m["gradient_roll"]["active"]
 @test m["gradient_roll"]["cue_labels"]["ochre"]==1
 q=gradient_roll_plan!(m,receipt(1),1_000_000,0.,"home","return",0.,target(39.5))
 @test q!==nothing && q["gradient_roll_mode"]=="direction"
 @test m["gradient_roll"]["cue_continued"]==1
 n=D();sky=merge(cue,D("cue_kind"=>"sky","cue_distance"=>36.))
 gradient_roll_enroll!(n,sky,0,0.,"home","return",0.,nothing;direction_distance=30.)
 @test gradient_roll_plan!(n,receipt(1),1_000_000,0.,"home","return",0.,target(36.))!==nothing
 @test n["gradient_roll"]["target_forward"]≈35.5
 unknown=merge(cue,D("cue_distance"=>nothing));gradient_roll_enroll!(n,unknown,2_000_000,0.,"home","return",0.,nothing)
 @test !n["gradient_roll"]["active"]
end
