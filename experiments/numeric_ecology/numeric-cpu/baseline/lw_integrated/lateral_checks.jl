using JSON3, Test
include(joinpath(@__DIR__,"../lw_day/lateral_bias.jl"))
oracle=isempty(ARGS) ? joinpath(@__DIR__,"lateral_oracle.json") : ARGS[1]
cases=JSON3.read(read(oracle,String),Vector{Dict{String,Any}})
@testset "Python composed lateral gate oracle and input isolation" begin
 for c in cases
  before=deepcopy(c["input"])
  @test composed_lateral_bias(c["input"],c["side"])==c["expected"]
  @test c["input"]==before
 end
 @test_throws ErrorException("lateral_side") composed_lateral_bias(first(cases)["input"],"neutral")
end
