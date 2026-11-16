using Test,JSON3
include("voice_broadcast.jl")
world=(positions=Dict("speaker"=>(0.,0.),"near"=>(2.,0.),"middle"=>(8.,0.),"weak"=>(12.,0.),"far"=>(20.,0.),"beyond"=>(40.,0.)),
 hearing=Dict(a=>true for a in ("speaker","near","middle","weak","far","beyond")))
attention=Dict(a=>true for a in keys(world.positions))
before=deepcopy(world)
normal=broadcast_voice(world,"speaker","魚交換したいです！";volume=1.,attention)
loud=broadcast_voice(world,"speaker","魚交換したいです！";volume=4.,attention)
@testset "voice level distance and independent receivers" begin
 @test received_sound_strength(1.,0.)==1.
 @test received_sound_strength(0.,2.)==0.
 @test received_sound_strength(4.,8.)==4received_sound_strength(1.,8.)
 @test received_sound_strength(1.,2.)>received_sound_strength(1.,8.)>received_sound_strength(1.,20.)
 for pair in ((-1.,0.),(1.,-1.),(Inf,2.),(1.,NaN))
  @test_throws ArgumentError received_sound_strength(pair...)
 end
 @test_throws ArgumentError received_sound_strength(1.,1.;reference_distance=0.)
 @test !haskey(normal,"speaker")
 @test length(normal)==5
 @test normal["near"].words_available && normal["middle"].words_available
 @test normal["weak"].text=="" && !normal["weak"].words_available
 @test normal["far"]===nothing && normal["beyond"]===nothing
 @test loud["far"].words_available && loud["beyond"]===nothing
 @test all(v===nothing for v in values(broadcast_voice(world,"speaker","test";volume=0.,attention)))
 attention["near"]=false
 inattentive=broadcast_voice(world,"speaker","test";volume=4.,attention)
 @test inattentive["near"].strength>0 && inattentive["near"].text==""
 @test inattentive["middle"].text=="test"
 @test propertynames(normal["near"])==(:strength,:bearing,:text,:words_available)
 @test world==before
 world.hearing["near"]=false
 @test broadcast_voice(world,"speaker","test";volume=4.,attention)["near"]===nothing
 world.hearing["near"]=true
 # Existing language observations need text, but hearing it does not imply meaning.
 @test normal["near"].text=="魚交換したいです！"
end
write(joinpath(@__DIR__,"voice_broadcast_result.json"),JSON3.write((settings=VOICE_BROADCAST,normal=normal,loud=loud)))
println(JSON3.write((normal=normal,loud=loud)))
