include("inheritance_paired_compare.jl")
@testset "paired experiment diagnostics" begin
    s,ps=animal_trial_world();digest=initial_digest(s,ps)
    @test digest==initial_digest(s,ps)
    io=IOBuffer();serialize(io,(s,ps));seekstart(io);s2,ps2=deserialize(io)
    @test digest==initial_digest(s2,ps2)
    ps2[1].food-=1
    @test digest!=initial_digest(s2,ps2)
    ps2[1].food+=1
    @test digest==initial_digest(s2,ps2)
    rand(ps2[1].visual.rng)
    @test digest!=initial_digest(s2,ps2)
    row(code,inherited,days)=(seed_code=code,inherited=inherited,lifetimes_days=[days,days])
    equal=paired_summary([row(1,false,2.),row(1,true,2.),row(2,false,3.),row(2,true,3.)])
    @test equal.mean_difference==0 && equal.sign_flip_two_sided==1
    @test equal.bootstrap_95==(0.,0.)
    positive=paired_summary([row(1,false,2.),row(1,true,3.),row(2,false,3.),row(2,true,4.)])
    @test positive.mean_difference==1 && positive.positive_pairs==2
    @test positive.sign_flip_two_sided==.5 && positive.bootstrap_95==(1.,1.)
    @test paired_summary([row(1,false,2.)])===nothing
end
