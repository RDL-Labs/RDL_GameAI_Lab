include(joinpath(ARGS[1],"experiments/julia_migration/lw_integrated/native.jl"))
using Test
spec=JSON3.read(read(ARGS[2],String)); raw=spec.scene.obstacles
@testset "landmark prepared input preserves observations" begin
 for p in ((0.,0.),(-2.,4.),(20.,20.)), yaw in 0.:15.:345.
  @test landmark_fan(raw,p,yaw,"same")==landmark_fan(prepare_landmark_objects(raw),p,yaw,"same")
 end
 for objects in ([],[(x=0.,z=5.,radius=1.,height=2.)],[(x=0.,z=5.,radius=1.,height=2.,color="green"),(x=0.,z=5.,radius=1.,height=2.,color="blue")])
  js=JSON3.read(JSON3.write(objects))
  @test landmark_fan(js,(0.,0.),0.,"same")==landmark_fan(prepare_landmark_objects(js),(0.,0.),0.,"same")
 end
end
