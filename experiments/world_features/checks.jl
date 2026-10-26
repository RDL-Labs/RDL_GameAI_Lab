using Test, JSON3
include("../../src/lw/LW.jl")
include("../../src/ecology/herbivore/Herbivores.jl")
include("../../src/ecology/directional-vision-cpu/DirectionalVision.jl")
const H=Herbivores
@testset "stable tree and rock traits" begin
 old=LW.native_landscape_scene(20261005)
 scene=LW.rich_landscape_scene(20261005)
 @test scene==LW.rich_landscape_scene(20261005)
 @test scene!=LW.rich_landscape_scene(20261006)
 objects=vcat(scene.obstacles,scene.low_obstacles)
 @test length(unique(o.world_id for o in objects))==length(objects)
 @test any(o.kind==1 for o in objects) && any(o.kind==2 for o in objects)
 @test length(unique(o.radius for o in objects if o.kind==1))>5
 @test length(unique(o.color for o in objects if o.kind==2))==2
 @test any(o.food_index>0 for o in objects)
 @test length(scene.food)==length(old.food)
 @test all(o.food_index==0 || o.kind==1 for o in objects)
 @test all(o.radius<=p.radius for (o,p) in zip(scene.obstacles,old.obstacles))
end
spec=JSON3.read(read("experiments/numeric_ecology/herbivore-cpu/map-spec.json",String))
@testset "patch food and concealment share state" begin
 w,a=H.build(spec;rich=true);w2,a2=H.build(spec;rich=true)
 @test w.traits.color==w2.traits.color && w.traits.height==w2.traits.height
 @test length(unique(w.traits.patch))<length(w.grass)/8
 k=H.cell(w,a.x[1],a.z[1])
 full=H.observe_grass!(w,k,0)
 @test full.food>0 && full.cover>0
 @test !hasproperty(full,:world_id) && !hasproperty(full,:patch)
 @test H.grass_cover!(w,k,0;body_height=.2)>=H.grass_cover!(w,k,0;body_height=1.2)
 w.grass[k]*=.5
 half=H.observe_grass!(w,k,0)
 @test half.food≈full.food/2 && half.cover≈full.cover/2
 @test half.color==full.color && half.height==full.height
 recovered=H.observe_grass!(w,k,17280)
 @test recovered.food>half.food && recovered.cover>half.cover
 # A real grazing step removes both edible mass and concealment, with proportional sharing.
 w,a=H.build(spec;rich=true);k=H.cell(w,a.x[1],a.z[1]);a.x.=a.x[1];a.z.=a.z[1]
 before=H.grass_cover!(w,k,0)
 H.step!(w,a,0,zeros(length(w.grass)),zeros(length(w.grass)),zeros(length(a.x)),Int[])
 @test w.eaten>0 && H.grass_cover!(w,k,0)<before
 @test w.eaten≈sum(a.consumed)
 @test w.initial+w.grown≈sum(w.grass)+w.eaten
end
@testset "predator uses patch height and depletion" begin
 P=DirectionalVision.P;H2=P.H
 w,a=H2.build(spec;rich=true);p=P.spawn(w)
 # Empty obstacles isolate the cover effect from rock occlusion.
 empty!(w.obstacles)
 a.x[1]=0.;a.z[1]=0.;p.x=-13.;p.z=0.
 k=H2.cell(w,0.,0.);w.capacity[k]=10.;w.grass[k]=10.
 w.traits.height[k]=1.;w.traits.density[k]=1.
 @test !P.visible(w,p,a,1,0)
 w.grass[k]=0.
 @test P.visible(w,p,a,1,0)
end

@testset "observable features omit world identity" begin
 w,a=H.build(spec;rich=true)
 @test !isempty(w.features)
 o=first(w.features)
 visible=H.observe_objects(w,o.x,o.z;range=1.)
 @test !isempty(visible)
 @test all(!hasproperty(v,:world_id) && !hasproperty(v,:food_index) && !hasproperty(v,:kind) for v in visible)
 @test any(v.width≈2o.radius && v.height==o.height for v in visible)
 @test H.observe_objects(w,o.x,o.z;range=1.)==visible
 @test isempty(H.observe_objects(w,1000.,1000.;range=1.))
end

@testset "enrichment retains nonvegetation properties" begin
 scene=LW.native_landscape_scene(20261005)
 light=(x=0.,z=8.,radius=.3,height=2.,color="orange",solid=true,light_source=1.)
 changed=LW.WorldFeatures.enrich_scene(merge(scene,(obstacles=[light],));seed=1)
 @test changed.obstacles[1].light_source==1.
 @test changed.obstacles[1].radius==light.radius && changed.obstacles[1].color=="orange"
end
