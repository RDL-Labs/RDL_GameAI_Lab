include(joinpath(@__DIR__,"rho_map_checks.jl"))
@testset "observed passage candidates" begin
    g=structure_ground();w=wall_samples()
    merge!(w,D("source"=>"ob:0:a","coverage"=>"complete","output_limited"=>false,"items"=>Any[]))
    move=D("energy"=>D("rows"=>[D("cost"=>1.) for _ in 1:5]))
    @test isempty(rho_openings(rho_map(g,w,"coarse")))
    w["samples"][4]["status"]="clear";w["samples"][4]["distance"]=12.
    for profile in ("coarse","fine")
        map=rho_map(g,w,profile);opening=only(rho_openings(map))
        @test opening.angle==0.
        @test opening.contrast==11.
        c=only(rho_opening_candidates(map,move))
        @test c["steering_angle"]==0.
        @test c["question"]=="target_observed" # mere walking earns no success
        @test c["opening_source"]=="ob:0:a"
        blocked=deepcopy(move);blocked["energy"]["rows"][3]["cost"]=nothing
        @test isempty(rho_opening_candidates(map,blocked))
        @test isempty(rho_openings(merge(map,D("coverage"=>"partial"))))
    end
    w["samples"][3]["status"]="unknown"
    @test isempty(rho_openings(rho_map(g,w,"coarse")))
    w["samples"][3]["status"]="hit"
    for c in w["samples"];c["status"]="clear";c["distance"]=12.;end
    @test isempty(rho_openings(rho_map(g,w,"coarse")))
    # Open edge of field of view is not a bounded gap.
    w["samples"][4]["status"]="hit";w["samples"][4]["distance"]=1.
    @test isempty(rho_openings(rho_map(g,w,"coarse")))
end

@testset "current observation prior and unresolved learning" begin
    g=structure_ground();w=wall_samples()
    for c in g["cells"];c["appearance"]="grass";end
    merge!(w,D("source"=>"ob:0:a","coverage"=>"complete","output_limited"=>false,"items"=>Any[]))
    w["samples"][4]["status"]="clear";w["samples"][4]["distance"]=12.
    map=rho_map(g,w,"coarse")
    cs=[D("method"=>"step_$i","action"=>"walk","direction"=>i,"priority"=>1.5,"question"=>"target_observed") for i in 0:4]
    s=BasicLoop("search";probabilistic=true);s.H=32
    @test all(≈(.2),method_distribution(s,cs))
    project_rho_affordance!(cs,map)
    ps=method_distribution(s,cs)
    @test argmax(ps)==3
    @test ps[3]>.5
    @test all(>(0.),ps)
    @test ps[1]≈ps[5] && ps[2]≈ps[4]
    @test all(-2<=c["observation_log_prior"]<=2.5 for c in cs)
    @test all(c["affordance_source"]=="ob:0:a" for c in cs)
    @test s.H==32 && isempty(s.methods) # evidence is not learned reward or resolution
    chosen=choose_method!(s,cs,"trial")
    resolve_method!(s,"trial",false,false)
    @test s.H==32 && all(n.reward==0 for n in values(s.methods))
end
