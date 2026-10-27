using JSON3, Test
include("../../src/lw/simulation/integrated.jl")
input=JSON3.read(read(ARGS[1],String),Dict{String,Any})
input["config"]["days"]=2
# Short clock exercises day rollover, sleep and replenishment without a long trial.
input["clock"]["day_us"]=120_000_000
input["clock"]["phase_boundaries_us"]=[1_000_000,60_000_000,80_000_000,120_000_000]
input["clock"]["quiet_night_us"]=100_000_000
input["clock"]["sleep_rest_us"]=20_000_000
spec=JSON3.read(JSON3.write(input))
if length(ARGS)>=3
    dir=ARGS[3]
    if ARGS[2]=="save"
        baseline,_=run_integrated(spec;checkpoint_dir=dir)
        serialize(joinpath(dir,"expected.jls"),baseline)
    elseif ARGS[2]=="resume"
        resumed,_=run_integrated(spec;resume_from=joinpath(dir,"day-001.jls"))
        @test resumed==deserialize(joinpath(dir,"expected.jls"))
        println("PASS separate-process checkpoint resume")
    else
        error("unknown mode")
    end
    exit()
end
mktempdir() do dir
    baseline,_=run_integrated(spec)
    saved,_=run_integrated(spec;checkpoint_dir=dir)
    resumed,_=run_integrated(spec;resume_from=joinpath(dir,"day-001.jls"))
    @test baseline==saved
    @test saved==resumed
    @test isfile(joinpath(dir,"day-002.jls"))
    bad=deepcopy(input);bad["config"]["seed"]+=1
    @test_throws ErrorException run_integrated(JSON3.read(JSON3.write(bad));resume_from=joinpath(dir,"day-001.jls"))
    @test_throws ErrorException run_integrated(spec;resume_from=joinpath(dir,"day-002.jls"))
    @test_throws ErrorException run_integrated(spec;checkpoint_dir=dir)
    c=deserialize(joinpath(dir,"day-001.jls"))
    @test_throws ErrorException checkpoint_load(joinpath(dir,"day-001.jls"),c.identity,"changed-source",2)
end
println("PASS daily checkpoint equivalence and rejection checks")
