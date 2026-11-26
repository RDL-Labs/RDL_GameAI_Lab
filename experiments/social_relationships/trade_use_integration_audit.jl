using JSON3, Test
function read_trade_report(out)
 isfile(joinpath(out,"completed.json")) || error("not complete: $out")
 r=JSON3.read(read(joinpath(out,"run/result.json"),String),Dict{String,Any})
 c=JSON3.read(read(joinpath(out,"completed.json"),String),Dict{String,Any})
 agents=Dict{String,Any}()
 for (a,s) in r["incidental_items"]
  social=s["social"]
  agents[a]=social===nothing ? nothing : Dict(k=>get(social,k,0) for k in ("decisions","proposed","accepted","declined","counterproposed","continued"))
 end
 (report=Dict("seconds"=>c["seconds"],"bytes"=>c["bytes"],"gctime"=>c["gctime"],"counts"=>r["portable_items"]["counts"],"actors"=>agents),result=r)
end
baseline=read_trade_report(ARGS[1]);enabled=read_trade_report(ARGS[2])
@testset "full LW use outlook smoke" begin
 @test length(enabled.result["daily"])==1
 @test all(m["trade_use_outlook"] for m in values(enabled.result["mb_map"]))
 @test length(enabled.result["digestion"])==4
end
report=Dict("baseline"=>baseline.report,"enabled"=>enabled.report)
write(joinpath(ARGS[2],"trade_use_audit.json"),JSON3.write(report));println(JSON3.write(report))
