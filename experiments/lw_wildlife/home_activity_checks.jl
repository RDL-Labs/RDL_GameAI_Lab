using Test,Serialization
const D=Dict{String,Any}
include("../../src/lw/observation/home_activity.jl")
@testset "observer-only physical return and unloading" begin
    storage=D();home=(0.,0.);positions=Dict("a"=>(0.,0.))
    state=home_activity_attach!(storage,positions,home,0)
    home_activity_position!(state,"a",(0.,0.),home,0,1,10)
    @test state["totals"]["a"]["returns"]==0
    home_activity_position!(state,"a",(2.,0.),home,0,2,10)
    @test state["totals"]["a"]["departures"]==1
    home_activity_position!(state,"a",(1.25,0.),home,1,3,10)
    @test state["totals"]["a"]["returns"]==1
    home_activity_position!(state,"a",(0.,0.),home,1,4,10)
    @test state["totals"]["a"]["returns"]==1
    home_activity_unload!(state,"a",0,(0.,0.),5,10)
    @test state["totals"]["a"]["unload_count"]==0
    home_activity_unload!(state,"a",3,(0.,0.),10,10)
    @test state["day"]==1
    @test state["actors"]["a"]["unloaded_units"]==3
    snapshot=home_activity_snapshot(state)
    home_activity_position!(state,"a",(2.,0.),home,0,11,10)
    @test state["day"]==2
    @test state["actors"]["a"]["unload_count"]==0
    @test snapshot["actors"]["a"]["unloaded_units"]==3
    buffer=IOBuffer();serialize(buffer,storage);seekstart(buffer);restored=deserialize(buffer)
    resumed=home_activity_attach!(restored,Dict("a"=>(2.,0.)),home,11)
    @test resumed["totals"]==state["totals"]
    home_activity_position!(resumed,"a",(0.,0.),home,0,12,10)
    @test resumed["totals"]["a"]["returns"]==2
    @test resumed["actors"]["a"]["returns"]==1
    @test resumed["totals"]["a"]["unload_count"]==1
    @test resumed["recording_started_us"]==0
end
