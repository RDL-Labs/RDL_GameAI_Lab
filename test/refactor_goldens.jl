using Test, JSON3, SHA
include("canonical_json.jl")
length(ARGS)==2 || error("usage: refactor_goldens.jl LW_OUTPUT HERBIVORE_OUTPUT")
fixture=JSON3.read(read(joinpath(@__DIR__,"fixtures/refactor-goldens.json"),String),Dict{String,Any})
@testset "full-report pre-refactor goldens" begin
    for mode in ("off","ordinary","meat")
        @test report_hash(joinpath(ARGS[1],"$mode-result.json"))==fixture["hashes"]["lw/$mode"]
    end
    @test report_hash(joinpath(ARGS[2],"result.json"))==fixture["hashes"]["herbivore/result"]
    for name in ("trajectory.csv","grass.csv")
        @test bytes2hex(sha256(read(joinpath(ARGS[2],name))))==fixture["hashes"]["herbivore/$name"]
    end
end
