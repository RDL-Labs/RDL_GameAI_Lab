using Test
D(args...)=Dict{String,Any}(args...)
check(x,msg)=x || error(msg)
include("../../src/lw/learning/sleep_cycle.jl")
include("../../src/lw/configured_paths/sleep_gate.jl")
@testset "sleep external gate and internal consolidation" begin
 l=sleeper(0);night=11_520_000_000;calls=Ref(0)
 @test !configured_sleep_gate_active(l,night,DAY)
 configured_sleep_gate_enter!(l,night,DAY;at_home=true)
 @test configured_sleep_gate_active(l,night+1_000_000,DAY)
 for i in 0:3000
  receipt!(l,night+i*1_000_000;on_complete=(c,t)->(calls[]+=1))
 end
 @test calls[]==1
 @test l["sleep"]["cycle"]["status"]=="completed"
 @test configured_sleep_gate_active(l,DAY-1_000_000,DAY)
 @test !configured_sleep_gate_active(l,DAY,DAY)
 @test !configured_sleep_gate_active(sleeper(1),DAY,DAY)
 @test l["sleep"]["external_gate"]["at_home"]
end
