using JSON3, SHA, Test
length(ARGS)==3 || error("usage: navigation_continue.jl ORIGINAL_RUN NEW_OUTPUT FINAL_DAY")
original=abspath(ARGS[1]);out=abspath(ARGS[2]);days=parse(Int,ARGS[3])
ispath(out) && error("fresh output required")
input=JSON3.read(read(joinpath(original,"input.json"),String),Dict{String,Any})
previous=input["config"]["days"];days>previous || error("must extend run")
checkpoint=joinpath(original,"checkpoints/day-"*lpad(previous,3,'0')*".jls")
input["config"]["days"]=days
mkpath(out);write(joinpath(out,"input.json"),JSON3.write(input))
write(joinpath(out,"conditions.json"),JSON3.write((original=original,resume_day=previous,final_day=days,
    changed=["config.days"],checkpoint_sha256=bytes2hex(sha256(read(checkpoint))),
    supply="unchanged finite large stocks; verify remaining stock at completion")))
include(joinpath(original,"source/integrations/lightweight_julia/native.jl"))
println("START continuation day $(previous+1) through $days; frozen original source and state");flush(stdout)
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--resume-from",checkpoint,"--checkpoint-dir",joinpath(out,"checkpoints")])
r=JSON3.read(read(joinpath(out,"run/result.json"),String))
@testset "continued navigation accounting" begin
    @test length(r.daily)==days
    @test length(r.final_agents)==3
    @test all(>(0),r.world_checkpoint.stock[1:length(input["scene"]["food"])])
    @test r.replenished_food==0
    @test all(!(e.action in ("request","give","trade_offer","item_offer","item_pickup")) for e in r.events)
    for d in r.daily
        @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical))
    end
end
write(joinpath(out,"completed.json"),JSON3.write((days=days,resumed_from=previous)))
