include(joinpath(@__DIR__,"../lw_day/run.jl"))
plain(x)=JSON3.read(JSON3.write(x))
obs(color="green";near=false,angle=0.)=D("coverage"=>"complete","source"=>"seen",
    "features"=>[D("color"=>color,"azimuth"=>[angle-7.5,angle+7.5],"range_band"=>near ? "near" : "mid")])
input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D())
@testset "Observed landmark route boundaries" begin
    for sample in input.sensor_cases
        actual=landmark_fan(sample.objects,Tuple(Float64.(sample.position)),sample.yaw,"sample")
        @test plain(actual["features"])==plain(sample.expected)
        @test all(Set(keys(f))==Set(["color","azimuth","range_band"]) for f in actual["features"])
    end
    m=route_memory();o=obs()
    route_result!(m,o,"step","walk","performed","food",true)
    route_result!(m,o,"pickup","pickup","picked_up","food",false)
    @test isempty(m["routes"])
    route_result!(m,o,"return-step","walk","performed","home",false)
    route_result!(m,o,"deposit","deposit","performed","home",true;delivered=["pickup"])
    @test m["routes"]["food:green"]["support"]==1
    @test m["routes"]["home:green"]["support"]==1
    t=trail();record_landmark!(t,o,"step")
    other=route_memory();admit_route!(other,"food",t,"delivered")
    @test other["routes"]["home:green"]["support"]==0
    admit_route!(other,"food",t,"delivered")
    @test other["routes"]["food:green"]["support"]==1
    t["points"][1]["color"]="red"
    @test other["routes"]["food:green"]["points"][1]["color"]=="green"
    n=route_memory()
    route_result!(n,o,"step","walk","performed","food",true)
    route_result!(n,o,"eaten","pickup","picked_up","food",false)
    route_result!(n,o,"wrong-food","deposit","performed","home",true;delivered=["gift"])
    @test isempty(n["routes"]) # A consumed pickup cannot be credited by delivering a gift.
    move=D("energy"=>D("rows"=>[D("cost"=>1.,"ref"=>"2")]))
    choices=landmark_candidates(move,o,m,"home","now")
    @test any(c["route"]!==nothing for c in choices)
    @test isempty(landmark_candidates(move,D("coverage"=>"partial","features"=>Any[]),m,"home","now"))
    ambiguous=obs();push!(ambiguous["features"],D("color"=>"green","azimuth"=>[45,60],"range_band"=>"mid"))
    @test isempty(landmark_candidates(move,ambiguous,m,"home","now"))
    absent=D("coverage"=>"complete","features"=>Any[])
    @test isempty(landmark_candidates(move,absent,m,"home","now"))
    blocked=D("energy"=>D("rows"=>[D("cost"=>nothing,"ref"=>"2")]))
    @test isempty(landmark_candidates(blocked,o,m,"home","now"))
    route_result!(m,o,"block","walk","blocked","home",false,"home:green")
    @test m["routes"]["home:green"]["H"]==1
    long=trail()
    for i in 1:9;record_landmark!(long,obs(isodd(i) ? "green" : "gray"),string(i));end
    @test long["overflow"]
    n=route_memory();admit_route!(n,"food",long,"x");@test isempty(n["routes"])
end
@testset "Observed routes in continuous living" begin
    for spec in input.scenes
        off=lw_day(spec,input.clock;days=3,basic_loop=true)
        on=lw_day(spec,input.clock;days=3,basic_loop=true,landmark_routes=true)
        @test on["ended_us"]==3*input.clock.day_us
        @test all(sum(values(on["counts"][a]))==3*17_280 for a in IDS)
        @test all(plain(on["day_starts"][d])==plain(on["daily"][d-1]["physical"]) for d in 2:3)
        @test all(n["ground"]+n["consumed"]+sum(n["physical"][a]["inventory"]+n["physical"][a]["personal_stock"] for a in IDS)==on["initial_food"] for n in on["daily"])
        @test all(n["sleep"][a]["sleep"]["cycle"]["status"]=="completed" for n in on["daily"] for a in IDS)
        @test all(length(on["final_agents"][a]["routes"]["routes"])<=16 for a in IDS)
        report["scenes"][spec.name]=D("disabled"=>off,"enabled"=>on)
    end
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
