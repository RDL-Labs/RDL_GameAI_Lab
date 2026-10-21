using Test, JSON3

length(ARGS) == 2 || error("usage: refactor_parity.jl BASELINE CANDIDATE")
@testset "full LW results unchanged by body extraction" begin
    for mode in ("off", "ordinary", "meat")
        baseline = JSON3.read(read(joinpath(ARGS[1], "$mode-result.json"), String), Dict{String,Any})
        candidate = JSON3.read(read(joinpath(ARGS[2], "$mode-result.json"), String), Dict{String,Any})
        @test baseline == candidate
    end
end
