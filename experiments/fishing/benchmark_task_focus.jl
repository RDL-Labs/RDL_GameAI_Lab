# Same frozen checkpoint; only current task-focus/day functions are overlaid.
record_fishing_day(args...)=nothing
const repo=normpath(joinpath(@__DIR__,"../.."))
runnerpath=joinpath(repo,"experiments/portable_items/benchmark_gradient_day.jl")
s=read(runnerpath,String)
s=replace(s,"file=joinpath(snapshot,\"src/lw/simulation/day.jl\")"=>"Base.include(Main,joinpath(repo,\"src/lw/decision/task_focus.jl\"))\nfile=joinpath(snapshot,\"src/lw/simulation/day.jl\")")
s=replace(s,"read(file,String)"=>"read(joinpath(repo,\"src/lw/simulation/day.jl\"),String)")
Base.include_string(Main,s,runnerpath)
