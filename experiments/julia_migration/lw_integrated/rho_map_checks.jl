include(joinpath(@__DIR__,"structure_checks.jl"))
@testset "rho map and purpose-conditioned potential" begin
    g=structure_ground();w=wall_samples()
    merge!(w,D("source"=>"ob:0:a","coverage"=>"complete","output_limited"=>false,"items"=>Any[]))
    w["samples"][4]["status"]="clear";w["samples"][4]["distance"]=12.
    original=deepcopy((g,w))
    for profile in ("coarse","fine")
        m=rho_map(g,w,profile)
        @test count(x->x["kind"]=="obstacle",m["groups"])==2
        @test any(x->x["kind"]=="obstacle" && x["passability"]=="unverified",m["breaks"])
        @test length(m["nodes"])==22
        @test isfinite(rho_descent(0.,m).potential.total)
    end
    @test (g,w)==original
    @test_throws ErrorException rho_map(g,w,"automatic")
    @test_throws ErrorException rho_map(g,merge(w,D("source"=>"other")),"fine")
    for c in w["samples"];c["distance"]=3.;c["status"]="hit";end
    coarse=rho_map(g,w,"coarse");fine=rho_map(g,w,"fine")
    @test count(x->x["kind"]=="obstacle",fine["groups"])>count(x->x["kind"]=="obstacle",coarse["groups"])
    @test coarse["nodes"]==fine["nodes"] # re-interpretation, not extra sensing
    w["samples"][4]["status"]="unknown"
    @test any(x->x["status"]=="unobserved",rho_map(g,w,"coarse")["boundaries"])
    empty_map=D("coverage"=>"complete","output_limited"=>false,"groups"=>Any[])
    @test rho_descent(0.,empty_map).angle==0.
    @test rho_descent(90.,empty_map).angle==90.
    @test rho_descent(0.,merge(empty_map,D("coverage"=>"partial")))===nothing
    obstacle=D("kind"=>"obstacle","points"=>[(.6,.5)])
    m=merge(empty_map,D("groups"=>[obstacle]))
    @test rho_descent(0.,m).angle<0
    @test rho_potential(m,(0.,.5),0.;clearance=3.).repulsion>rho_potential(m,(0.,.5),0.;clearance=1.).repulsion
    road=D("kind"=>"worn_ground","points"=>[(0.,1.),(0.,2.),(0.,4.)])
    m=merge(empty_map,D("groups"=>[road]))
    @test rho_potential(m,(0.,.5),0.).road>rho_potential(m,(.5,0.),0.).road
    square=D("kind"=>"worn_ground","points"=>[(-1.,1.),(1.,1.),(-1.,3.),(1.,3.)])
    @test rho_potential(merge(empty_map,D("groups"=>[square])),(0.,.5),0.).road==0
    # Integration: steering receives the map of this observation and records it.
    m=merge(empty_map,D("rho"=>"coarse","source"=>g["source"],"groups"=>[obstacle]))
    state=D("source"=>"ob:0:a","observation"=>m)
    world=(positions=Dict("a"=>(0.,0.)),bodies=Dict("a"=>Body(10.,0.,100.,0.)),inventory=Dict("a"=>0),obstacles=RDLMigrationProbe.Circle[])
    plan=D("action"=>"walk","direction"=>2,"question"=>"movement_progress")
    @test steer_structure!(plan,nothing,w,state,world,"a",Dict("a"=>0.),x->1.)
    @test plan["rho_source"]=="ob:0:a"
    @test plan["rho_profile"]=="coarse"
    @test plan["approach_angle"]<0
    state["source"]="stale"
    stale=D("action"=>"walk","direction"=>2)
    steer_structure!(stale,nothing,w,state,world,"a",Dict("a"=>0.),x->1.)
    @test !haskey(stale,"rho_profile")
    _,opts=native_options(["unused","--rho-profile","fine"])
    @test opts["rho-profile"]=="fine"
end

@testset "rho concentrates boundary repulsion without shrinking body" begin
    coarse=D("rho"=>"coarse","coverage"=>"complete","output_limited"=>false,
        "groups"=>[D("kind"=>"obstacle","points"=>[(.6,.5)]),D("kind"=>"obstacle","points"=>[(-.6,.5)])])
    fine=merge(coarse,D("rho"=>"fine"))
    @test rho_boundary_range(coarse,2.)==2.
    @test rho_boundary_range(fine,2.)==.5
    @test rho_boundary_range(fine,2.5)==1. # running/load additions retained
    @test rho_boundary_range(fine,.2)>.2
    @test_throws ErrorException rho_boundary_range(fine,0.)
    @test rho_potential(coarse,(0.,.5),0.).repulsion≈4*(1-.6/2)^3
    @test rho_potential(fine,(0.,.5),0.).repulsion==0.
    @test rho_potential(fine,(.5,.5),0.).repulsion>1.
    @test rho_descent(0.,fine).angle==0.
    # Same scalar evaluator is used in upstream candidate scoring.
    c=[D("action"=>"walk","direction"=>2)]
    fine["nodes"]=Any[];fine["source"]=D("observation"=>"test")
    project_rho_affordance!(c,fine)
    @test c[1]["observation_log_prior"]==0.
    # A fine map must not authorize crossing an actual solid obstacle.
    world=(positions=Dict("a"=>(0.,0.)),bodies=Dict("a"=>Body(10.,0.,100.,0.)),
        inventory=Dict("a"=>0),obstacles=[RDLMigrationProbe.Circle(0.,.4,.3)])
    emptyfine=merge(fine,D("groups"=>Any[]))
    plan=D("action"=>"walk","direction"=>2)
    @test !steer_structure!(plan,nothing,D("source"=>"test"),D("source"=>"test","observation"=>emptyfine),world,"a",Dict("a"=>0.),p->1.)
    @test !haskey(plan,"approach_angle")
end
