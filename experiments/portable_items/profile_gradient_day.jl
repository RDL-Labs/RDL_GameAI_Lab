# Same trusted-checkpoint runner, with sampling around the measured call only.
# Warmup and JSON export are excluded. Restore/final assembly and daily save are included.
using Profile
const runner_path=joinpath(@__DIR__,"benchmark_gradient_day.jl")
runner=read(runner_path,String)
anchor="measured=@timed run_integrated(input;resume_from=checkpoint,checkpoint_dir=joinpath(out,\"checkpoints\"))"
count(anchor,runner)==1 || error("profile anchor mismatch")
replacement="""
Profile.init(n=20_000_000,delay=.002)
Profile.clear()
measured=@timed Profile.@profile run_integrated(input;resume_from=checkpoint,checkpoint_dir=joinpath(out,"checkpoints"))
open(joinpath(out,"cpu-flat.txt"),"w") do io
    Profile.print(io;format=:flat,sortedby=:count,mincount=10)
end
open(joinpath(out,"cpu-tree.txt"),"w") do io
    Profile.print(io;format=:tree,mincount=20)
end
serialize(joinpath(out,"cpu-profile.jls"),Profile.retrieve())
"""
Base.include_string(Main,replace(runner,anchor=>replacement),runner_path)
