include(joinpath(@__DIR__,"../lw_integrated/native.jl"))
using Test, Statistics
input=JSON3.read(read(ARGS[1],String));out=ARGS[2];mkpath(out)
objects=input.scene.obstacles;typed=prepare_skyline_objects(objects)
@testset "geometry preparation preserves finite sensory output" begin
    for p in ((0.,0.),(-2.,4.),(20.,20.)), yaw in 0.:15.:345., sub in (false,true)
        @test skyline_fan(objects,p,yaw,"same";subrays=sub)==skyline_fan(typed,p,yaw,"same";subrays=sub)
    end
    cases=[[(x=0.,z=5.,radius=.5,height=2.,color="green"),(x=0.,z=20.,radius=1.,height=20.,color="ochre")],
        [(x=0.,z=0.,radius=1.,height=2.,color="inside")],
        [(x=1.,z=8.,radius=1.,height=20.,color="tangent")],
        [(x=0.,z=49.,radius=1.,height=40.,color="range")],
        [(x=0.,z=5.,radius=1.,height=8.,color="first"),(x=0.,z=5.,radius=1.,height=8.,color="second")]]
    for raw in cases
        js=JSON3.read(JSON3.write(raw));ts=prepare_skyline_objects(js)
        @test skyline_fan(js,(0.,0.),0.,"s";subrays=true)==skyline_fan(ts,(0.,0.),0.,"s";subrays=true)
    end
end
function calls(objects,n)
    count=0
    for _ in 1:n;count+=length(skyline_fan(objects,(-2.,4.),0.,"same";subrays=true)["features"]);end
    count
end
calls(objects,1);calls(typed,1)
samples=Any[]
for i in 1:5
    for (name,x) in (isodd(i) ? (("old",objects),("typed",typed)) : (("typed",typed),("old",objects)))
        GC.gc();m=@timed calls(x,32)
        push!(samples,(variant=name,seconds=m.time,bytes=m.bytes,gc=m.gctime,checksum=m.value))
    end
end
GC.gc();conversion=@timed prepare_skyline_objects(objects)
write(joinpath(out,"comparison.json"),JSON3.write((samples=samples,conversion=(seconds=conversion.time,bytes=conversion.bytes),scope="local sensory comparison, 32 calls/sample, 5 paired alternating samples; not full LW speedup")))
println(JSON3.write(samples))
