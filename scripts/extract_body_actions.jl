# One-time, guarded source migration. Refuses to run after extraction.
root = normpath(joinpath(@__DIR__, ".."))
loop_path = joinpath(root, "experiments/julia_migration/all_loop/loop.jl")
food_path = joinpath(root, "experiments/julia_migration/lw_day/food_body.jl")
source = replace(read(loop_path, String), "\r\n" => "\n")
food = replace(read(food_path, String), "\r\n" => "\n")
delta_start = findfirst("\"Immutable four-component", source)
delta_end = findfirst("mutable struct Agent", source)
action_start = findfirst("# A0 ports", source)
action_end = findfirst("function simulate", source)
metabolism_start = findfirst("function metabolize", food)
metabolism_end = findfirst("hunger_state", food)
all(x -> x !== nothing, (delta_start, delta_end, action_start, action_end, metabolism_start, metabolism_end)) || error("Source layout changed or already extracted")
delta = source[first(delta_start):prevind(source, first(delta_end))]
actions = source[first(action_start):prevind(source, first(action_end))]
metabolism = food[first(metabolism_start):prevind(food, first(metabolism_end))]
write(joinpath(root, "src/body/actions.jl"), "const RS=64_000_000/17_280_000_000\nconst SS=1/60\n\n" * delta * actions * metabolism)
source = replace(source, delta => "", actions => "", "const RS=64_000_000/17_280_000_000\nconst SS=1/60\n" => "")
food = replace(food, metabolism => "")
write(loop_path, source)
write(food_path, "include(joinpath(@__DIR__, \"../../../src/body/load.jl\"))\n" * food)
