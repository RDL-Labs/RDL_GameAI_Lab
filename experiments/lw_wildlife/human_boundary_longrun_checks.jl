using JSON3,Test
const out=mktempdir();const longrun=true;const boundary_trial="boxes"
const completed_day=Ref(0);const daily_measurements=Any[];const final_day=3
const run_days=2
const timer=Dict{String,Float64}();const start_ns=Ref(time_ns());const actual=Ref{Any}()
struct ProfileDone <: Exception end
runner=read(joinpath(@__DIR__,"profile_human_ecology.jl"),String)
definition="function finish_probe!"*split(split(runner,"function finish_probe!";limit=2)[2],"function once";limit=2)[1]
include_string(Main,definition)
function sample_day(i)
    Dict("counts"=>Dict("a"=>Dict("rest"=>17280i)),"physical"=>Dict("a"=>Dict(
        "body"=>Dict("reserve"=>50.),"position"=>[0.,0.],"inventory"=>0,"personal_stock"=>1,
        "return_purpose"=>Dict("completed"=>i,"active"=>false))))
end
@testset "longrun daily accounting and safe finish" begin
    timer["checkpoint_seconds"]=1.
    finish_probe!([sample_day(1),sample_day(2)])
    @test completed_day[]==2
    @test isempty(timer)
    @test daily_measurements[1].humans["a"].actions["rest"]==17280
    @test daily_measurements[1].humans["a"].legacy_return_completed==1
    @test isfile(joinpath(out,"progress.json"))
    @test_throws ProfileDone finish_probe!([sample_day(1),sample_day(2),sample_day(3)])
    @test completed_day[]==3
    @test length(daily_measurements)==2
    write(joinpath(out,"STOP"),"")
    @test_throws ProfileDone finish_probe!([sample_day(1),sample_day(2)])
    @test completed_day[]==2
end
