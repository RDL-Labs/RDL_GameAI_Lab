using Test
include("trade_observation.jl")
include("role_probe.jl")
include("trade_channels.jl")
@testset "own outcome resolves observed peer expression only" begin
 for status in ("exchanged","declined")
  memory=TradeChannelObserver()
  observation=(id="peer-presentation",text="モ",motion="present",appearances=String[])
  memory.pending["offer"]=(observation,"object-presented")
  result=Dict("status"=>status,"offer_id"=>"offer")
  @test trade_channel_own_result!(memory,result)
  @test isempty(memory.pending)
  @test length(memory.roles.receipts)==1
  @test memory.roles.receipts[observation.id][3]==(status=="exchanged" ? "object-transferred" : "object-withdrawn")
  @test !trade_channel_own_result!(memory,result)
  @test length(memory.roles.receipts)==1
  @test !haskey(memory.roles.associations,("object-presented","ユ"))
  @test !haskey(memory.roles.associations,("object-presented","ケ"))
 end
 memory=TradeChannelObserver()
 @test !trade_channel_own_result!(memory,Dict("status"=>"exchanged","offer_id"=>"unseen"))
 @test isempty(memory.roles.receipts)
 @test !trade_channel_own_result!(memory,Dict("status"=>"unavailable"))
end
