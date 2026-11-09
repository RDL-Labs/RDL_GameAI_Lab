include("food_pressure_rabbit16.jl")
Base.include(H,joinpath(@__DIR__,"../../src/lw/configured_paths/rabbit_exponential_candidates.jl"))
Core.eval(H,:(const EXPONENTIAL_TEST=Ref(false)))
newtarget=replace(target,"chosen=if pressure==0"=>"chosen=if i==16 && EXPONENTIAL_TEST[]\n configured_rabbit_candidate_choice(observations,a,i,m,pressure,RABBIT_APPROACH.temperature_scale)\n elseif pressure==0")
include_string(H,newtarget)
@testset "candidate width" begin
 widths=[H.configured_rabbit_candidate_count(h,8) for h in 0:.1:32]
 @test issorted(widths)
 @test first(widths)==1
 @test last(widths)==8
 @test H.configured_rabbit_candidate_count(4.,8)==1
 @test H.configured_rabbit_candidate_count(8.,8)==2
 @test H.configured_rabbit_candidate_count(20.,3)==3
 @test H.configured_rabbit_candidate_count(20.,0)==0
end
old=trial(true;thresholded=true,intake_cooling=true)
H.EXPONENTIAL_TEST[]=true
new=trial(true;intake_cooling=true)
summary(r)=(alive=r.alive,energy=r.energy,eaten=r.eaten,peakH=r.peakH,
 first_feeding=let p=findfirst(p->p.tick>243838 && p.state=="graze",r.samples);p===nothing ? nothing : r.samples[p] end)
write(output,JSON3.write((old=summary(old),new=summary(new),work=H.RABBIT_CANDIDATE_STATS,settings=H.RABBIT_EXPONENTIAL_CANDIDATES)))
println(read(output,String))
