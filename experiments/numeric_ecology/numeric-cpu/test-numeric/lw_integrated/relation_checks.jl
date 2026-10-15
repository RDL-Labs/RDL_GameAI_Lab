include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "Python angular relation field correspondence" begin
 rows=JSON3.read(read(joinpath(@__DIR__,"relation_reference.json"),String))
 for r in rows
    rel=compare_relation(r.ob,r.target)
    @test rel["status"]==r.expected.relation.status
    @test length(rel["pairs"])==length(r.expected.relation.pairs)
    for (p,q) in zip(rel["pairs"],r.expected.relation.pairs)
        @test p["error"]≈q.error
    end
    for row in r.expected.samples
        @test isapprox(relation_cost(rel,row.direction,r.weight;goal_angle=r.goal),row.total;atol=1e-12)
    end
 end
end
@testset "observed relation proposals and route evidence" begin
 ob=D("coverage"=>"complete","source"=>"ob0","features"=>[
    D("color"=>"brown","azimuth"=>[-20.,-10.],"range_band"=>"mid"),
    D("color"=>"green","azimuth"=>[30.,40.],"range_band"=>"far")])
 t=trail();record_landmark!(t,ob,"walk1";relational=true)
 @test length(t["points"])==1 && length(t["points"][1]["scene"])==2
 m=route_memory();admit_route!(m,"food",t,"delivered1";relational=true)
 @test length(m["routes"])==2
 @test only(n["support"] for n in values(m["routes"]) if n["goal"]=="home")==0
 admit_route!(m,"food",t,"delivered1";relational=true)
 @test only(n["support"] for n in values(m["routes"]) if n["goal"]=="food")==1
 changed=deepcopy(t);changed["points"][1]["scene"][2]["angle"]=70.
 admit_route!(m,"food",changed,"delivered2";relational=true)
 @test length(m["routes"])==4 # same colors, different relation must not merge
 move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>i==2 ? nothing : 1.) for i in 0:4]))
 s=relation_field_state();cs=relation_candidates!(s,move,ob,m,"food","now")
 @test !isempty(cs) && all(c["direction"]!=2 for c in cs)
 @test all(m["routes"][c["route"]]["goal"]=="food" for c in cs)
 @test isempty(relation_candidates!(s,move,merge(ob,D("coverage"=>"partial")),m,"food","partial"))
 before=deepcopy(m["routes"])
 @test isempty(relation_candidates!(s,move,merge(ob,D("features"=>ob["features"][1:1])),m,"food","single"))
 @test m["routes"]==before
end
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--orientation","on",
    "--relation-field",mode,"--general-sleep","apply","--sleep-retention","strata","--sleep-maintenance","on"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
    @testset "living relation bounds" begin
        @test all(length(s.records)<=32 for s in values(r.relation_field))
        @test all(length(s.routes.routes)<=16 for s in values(r.final_agents))
        @test all(all(length(p.scene)<=5 for n in values(s.routes.routes) for p in n.points) for s in values(r.final_agents))
    end
 end
end
