include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "observed cue eligibility and H widening" begin
    tower=(x=0.,z=6.,radius=.3,height=12.,color="ochre")
    @test isempty(landmark_fan([tower],(0.,0.),0.,"s")["features"])
    ob=landmark_fan([tower],(0.,0.),0.,"s";all_colors=true)
    @test any(f->f["color"]=="ochre",ob["features"])
    move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]),"visible"=>Any[])
    # Two identically colored observed patches remain uncertain hypotheses.
    push!(ob["features"],D("color"=>"gray","azimuth"=>[-67.5,-52.5],"range_band"=>"mid","distance"=>12.))
    push!(ob["features"],D("color"=>"gray","azimuth"=>[52.5,67.5],"range_band"=>"mid","distance"=>12.))
    structures=D("source"=>D("observation"=>"s"),"groups"=>[D("kind"=>"water","points"=>[(3.,3.),(4.,4.)])])
    hazard=D("features"=>[D("right"=>1.,"forward"=>4.,"distance"=>sqrt(17.))])
    sky=skyline_fan([tower],(0.,0.),0.,"s")
    pool=observed_cues(ob,sky,structures,move,hazard,"s")
    @test Set(c["kind"] for c in pool.items) ⊇ Set(["shape","sky","surface","moving","arrangement"])
    @test length(unique(c["key"] for c in pool.items))==length(pool.items)
    @test all(!haskey(c,"x") && !haskey(c,"object_id") for c in pool.items)
    @test all(c["tier"]==1 for c in pool.items if c["label"]=="gray")
    sets=Any[]
    for H in (0,2,4)
        lazy=observed_cues(ob,sky,structures,move,hazard,"s";level=min(2,H÷2))
        @test lazy.items==filter(c->c["tier"]<=min(2,H÷2),pool.items)
        @test cue_candidates!(cue_stats(),lazy,move,H,2)==cue_candidates!(cue_stats(),pool,move,H,2)
        stats=cue_stats();cs=cue_candidates!(stats,pool,move,H,2);push!(sets,Set(c["method"] for c in cs))
        @test all(c["cue_tier"]<=min(2,H÷2) for c in cs)
        @test all(c["cue_uncertain"]==(c["cue_tier"]>0) for c in cs)
        @test all(c["question"]=="target_observed" for c in cs)
        @test all(c["action"]=="scan" for c in cs if c["cue_kind"] in ("surface","moving","arrangement"))
        @test stats["tower_observations"]==1
    end
    @test sets[1] ⊊ sets[2] ⊊ sets[3]
    @test_throws ErrorException observed_cues(ob,merge(sky,D("source"=>"stale")),nothing,move,nothing,"s")
    empty_ob=D("coverage"=>"partial","features"=>Any[],"source"=>"s","lights"=>Any[])
    @test isempty(observed_cues(empty_ob,nothing,nothing,move,nothing,"s").items)
    close=landmark_fan([tower],(0.,5.),0.,"s";all_colors=true)
    cs=cue_candidates!(cue_stats(),observed_cues(close,nothing,nothing,move,nothing,"s"),move,32,2)
    @test !isempty(cs) && all(c["action"]=="scan" for c in cs)
    stats=cue_stats();cs=cue_candidates!(stats,pool,move,4,2)
    for _ in 1:100;record_cue_selection!(stats,first(cs),4);end
    @test length(stats["records"])==32
    @test sum(stats["selected"])==100
    _,opts=native_options(["unused","--general-landmarks","on"])
    @test opts["general-landmarks"]=="on"
end
