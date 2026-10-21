using Test, JSON3
length(ARGS) == 2 || error("usage: ecology_refactor_parity.jl BASELINE CANDIDATE")
@testset "herbivore state and trajectories" begin
    @test JSON3.read(read(joinpath(ARGS[1], "result.json"), String)) ==
          JSON3.read(read(joinpath(ARGS[2], "result.json"), String))
    for name in ("trajectory.csv", "grass.csv")
        @test read(joinpath(ARGS[1], name)) == read(joinpath(ARGS[2], name))
    end
end
