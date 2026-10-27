include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "cached trail prefix preserves exact serialized identity" begin
 contexts=Any[nothing,Any[],Any["none"],D("nested"=>Any[1,0.1,true,nothing,"岩\n\"\\"]),"入口🍎"]
 candidates=[D("method"=>"walk","action"=>"walk","direction"=>2),
             D("method"=>"scan\"\\","action"=>"scan","scan_angle"=>-0.0),
             D("method"=>"見回し🍎","action"=>"scan","scan_angle"=>15.5)]
 for actor in ("a","個体🍎"),context in contexts,phase in ("exploration","return"),c in candidates
     s=selection_trail_state(actor)
     @test trail_key_from_prefix(trail_key_prefix(s,context,phase),c)==trail_key(s,context,phase,c)
 end
 s=selection_trail_state("a");loop=BasicLoop("food");context=Any["none"]
 plans=[merge(copy(c),D("priority"=>1.,"question"=>"movement_progress")) for c in candidates]
 trace=project_trails!(s,plans,loop,context,"exploration")
 @test all(trace["edges"][c["method"]]==trail_key(s,context,"exploration",c) for c in plans)
 push!(context,"changed")
 next=project_trails!(s,plans,loop,context,"exploration")
 @test next["edges"]!=trace["edges"]
 @test all(next["edges"][c["method"]]==trail_key(s,context,"exploration",c) for c in plans)
 skipped=[D("method"=>"skip","action"=>"walk","priority"=>1.,"record_trial"=>false)]
 @test isempty(project_trails!(s,skipped,loop,context,"exploration")["edges"])
 @test project_trails!(s,plans,loop,context,"safety")===nothing
end
