include("structure_checks.jl")
@testset "observed group boxes and need-driven detail" begin
    ground=structure_ground();walls=wall_samples()
    walls["source"]=ground["source"]["observation"]
    walls["coverage"]="complete";walls["output_limited"]=false
    walls["samples"][4]["status"]="clear";walls["samples"][4]["distance"]=12.
    coarse=rho_map(ground,walls,"coarse";boxes=true)
    groups=filter(g->g["kind"]=="obstacle",coarse["groups"])
    @test length(groups)==2
    @test all(haskey(g,"observed_bounds") for g in groups)
    @test !isempty(rho_openings(coarse))
    @test rho_box_distance((1.,3.,2.,4.),(2.,3.))==0.
    @test rho_box_distance((1.,3.,2.,4.),(0.,1.))≈sqrt(2.)
    @test rho_box_distance((1.,1.,2.,2.),(1.,2.))==0.
    for point in ((0.,0.),(.25,.25),(-.5,0.))
        @test rho_local_potential(rho_local_field(coarse),point,30.).total≈rho_potential(coarse,point,30.).total
    end
    fine=rho_map(ground,walls,"fine";boxes=true)
    @test fine==rho_map(ground,walls,"fine")
    state=structure_memory("a");update_structures!(state,coarse,nothing)
    @test rho_observed_map!(state,ground,walls,"coarse";boxes=true)===coarse
    update_structures!(state,fine,nothing)
    @test state["observation"]===fine
    @test rho_observed_map!(state,ground,walls,"coarse";boxes=true)!==fine
    estimate=D("near"=>true,"checking"=>false)
    @test rho_box_profile(estimate,nothing)=="coarse"
    @test rho_box_profile(D("checking"=>true),nothing)=="fine"
    @test rho_box_profile(estimate,D("action"=>"walk","status"=>"blocked","forward"=>0.,"right"=>0.))=="fine"
    @test rho_box_profile(estimate,D("action"=>"rest"))=="coarse"
    @test rho_box_profile(estimate,D("action"=>"scan"))=="fine"
    @test rho_box_profile(estimate,nothing;explicit_fine=true)=="fine"
end
