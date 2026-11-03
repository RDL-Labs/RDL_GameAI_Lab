using Test,Random,Statistics,JSON3
include("../julia_migration/lw_integrated/rho_map_checks.jl")
function reference_descent(angle,map;clearance=2.,span=.5)
 map["coverage"]=="complete" && !map["output_limited"] || return nothing
 offsets=(0.,-11.25,11.25,-22.5,22.5,-33.75,33.75,-45.,45.)
 before=-rho_potential(map,(0.,0.),angle;clearance=clearance).total
 chosen=relational_best(offsets) do offset
  value=rho_potential(map,(span*sind(angle+offset),span*cosd(angle+offset)),angle;clearance=clearance)
  merge(relational_transition(before,-value.total),(potential=value,))
 end
 angle+chosen.candidate,chosen.field.potential
end
@testset "prepared local field preserves fine and coarse potentials" begin
 rng=MersenneTwister(19)
 groups=Any[D("kind"=>kind,"points"=>[(randn(rng)*8,randn(rng)*8) for _ in 1:20]) for kind in ("obstacle","water","worn_ground") for _ in 1:6]
 push!(groups,D("kind"=>"worn_ground","points"=>[(0.,1.),(0.,2.),(0.,30.)]))
 for profile in ("fine","coarse"), clearance in (1.,2.,3.3), span in (.1,.5,1.5)
  map=D("rho"=>profile,"coverage"=>"complete","output_limited"=>false,"groups"=>groups)
  field=rho_local_field(map;clearance,span)
  @test sum(length(p) for (_,p) in field.surfaces;init=0)<240
  for angle in (-170.,-45.,0.,33.,90.), radius in (0.,span)
   point=(radius*sind(angle),radius*cosd(angle))
   @test rho_local_potential(field,point,angle)==rho_potential(map,point,angle;clearance)
  end
  for angle in (-45.,0.,90.)
   ref=reference_descent(angle,map;clearance,span);value=rho_descent(angle,map;clearance,span)
   @test value.angle==ref[1] && value.potential==ref[2]
  end
 end
 # No stale persistent cache after replacing observations / road geometry.
 m=D("rho"=>"coarse","coverage"=>"complete","output_limited"=>false,"groups"=>[D("kind"=>"obstacle","points"=>[(0.,.7)])])
 @test rho_descent(0.,m).potential.repulsion>0
 m["groups"][1]["points"]=[(0.,20.)]
 @test rho_descent(0.,m).potential.repulsion==0
 for d in (prevfloat(2.5),2.5,nextfloat(2.5))
  m["groups"][1]["points"]=[(0.,d)]
  @test rho_local_potential(rho_local_field(m),(0.,.5),0.)==rho_potential(m,(0.,.5),0.)
 end
end
