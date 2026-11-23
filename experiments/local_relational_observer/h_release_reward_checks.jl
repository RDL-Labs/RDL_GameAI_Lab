using Test, Serialization, JSON3
include("h_release_reward.jl")
using .HReleaseRewardProbe: Mind, start!, mismatch!, resolve!, residual, abandon!

@testset "trial-scoped H release and conserved credit" begin
    m=Mind();start!(m,"food",Dict("fishing"=>3.,"route"=>1.))
    start!(m,"unrelated-home",Dict("home-route"=>1.))
    mismatch!(m,"food","miss",8.,0.)
    mismatch!(m,"unrelated-home","miss",5.,0.)
    @test residual(m)==13
    first=resolve!(m,"food","catch-1",.5)
    @test first.released==4 && first.H==4 && first.status==:active
    @test first.reward≈4.05
    @test residual(m)==9
    @test m.trials["unrelated-home"].balance["H"]==5
    @test m.strength["fishing"]≈3.0375
    @test m.strength["route"]≈1.0125
    @test sum(values(m.strength))≈first.reward
    @test resolve!(m,"food","catch-1",.5)===nothing
    @test_throws ArgumentError resolve!(m,"food","catch-1",.6)
    @test resolve!(m,"food","unknown",nothing)===nothing
    @test resolve!(m,"food","same-progress",.5).reward==0
    io=IOBuffer();serialize(io,m);seekstart(io);restored=deserialize(io)
    @test resolve!(restored,"food","catch-1",.5)===nothing
    last=resolve!(m,"food","catch-2",1.)
    @test last.H==0 && last.status==:completed
    @test m.trials["food"].reward≈8.1
    @test residual(m)==5
    @test !haskey(m.strength,"home-route")
    @test_throws ArgumentError mismatch!(m,"food","late",1.,0.)
    @test_throws ArgumentError start!(m,"food",Dict("another"=>1.))
    @test resolve!(m,"food","catch-2",1.)===nothing
    println(JSON3.write((case="partial_then_complete",first,last,
        strength=m.strength,unrelated_H=residual(m))))
end
include("../../src/lw/LW.jl")
@testset "local reward feeds existing human selection" begin
    mind=Mind();start!(mind,"food",Dict("successful"=>1.))
    mismatch!(mind,"food","miss",8.,0.);resolve!(mind,"food","resolved",1.)
    loop=LW.BasicLoop("local-food";probabilistic=true,seed=1)
    candidates=[LW.D("method"=>key,"priority"=>0.,"question"=>"local_outcome") for key in ("successful","other")]
    LW.choose_method!(loop,candidates,"setup")
    for (key,reward) in mind.strength
        loop.methods[key].reward+=reward
    end
    # The ordinary selector already uses log1p(reward); no new forced choice.
    parts=LW.method_score_parts(loop,candidates[1])
    @test loop.methods["successful"].reward≈8.1
    @test loop.methods["other"].reward==0
    @test parts.learned≈log1p(8.1)
    probabilities=LW.method_distribution(loop,candidates)
    @test probabilities[1]≈9.1/10.1
    @test 0<probabilities[2]<probabilities[1]<1
    println(JSON3.write((case="equal_candidates_after_success",probabilities)))
end
@testset "low H, parent-child separation and no partition bonus" begin
    m=Mind();start!(m,"parent",Dict("fishing"=>1.))
    start!(m,"child",Dict("approach"=>1.));mismatch!(m,"parent","miss",8.,0.)
    child=resolve!(m,"child","arrived",1.)
    @test child.released==0 && child.reward≈.1
    @test m.trials["parent"].balance["H"]==8
    @test !haskey(m.strength,"fishing")
    once=Mind();split=Mind()
    for mind in (once,split)
        start!(mind,"food",Dict("route"=>1.));mismatch!(mind,"food","miss",8.,0.)
    end
    resolve!(once,"food","all",1.)
    resolve!(split,"food","half",.5);resolve!(split,"food","all",1.)
    @test once.strength==split.strength
    @test once.trials["food"].released==split.trials["food"].released==8
    @test_throws ArgumentError resolve!(m,"parent","bad",1.1)
    @test !mismatch!(m,"parent","unknown",nothing,0.)
    @test !haskey(m.trials["parent"].receipts,"unknown")
    abandon!(m,"parent")
    @test residual(m)==8
    @test !haskey(m.strength,"fishing")
    @test_throws ArgumentError resolve!(m,"parent","late",1.)
end
