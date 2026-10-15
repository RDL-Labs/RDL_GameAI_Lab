include(joinpath(@__DIR__,"native.jl"))
@testset "local descent" begin
 obs=D("coverage"=>"complete","output_limited"=>false,"items"=>Any[])
 t=D("forward"=>10.,"right"=>2.,"distance"=>hypot(10,2))
 v=local_descent(t,obs);@test isapprox(v.angle,rad2deg(atan(2,10)))
 @test !(v.angle in ANGLES)
 @test local_descent(nothing,obs)===nothing
 @test local_descent(t,merge(obs,D("coverage"=>"partial")))===nothing
 push!(obs["items"],D("forward"=>1.,"right"=>.5))
 @test local_descent(t,obs).angle<v.angle
 @test local_descent(D("distance"=>1.),obs)===nothing
end

@testset "native continuous direction adoption" begin
 _,defaults=native_options(["output"])
 @test defaults["continuous-descent"]=="on"
 _,legacy=native_options(["output","--continuous-descent","off"])
 @test legacy["continuous-descent"]=="off"
 @test_throws ErrorException native_main(["output","--continuous-descent","invalid"])
end
