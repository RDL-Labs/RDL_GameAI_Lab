include("native.jl")
using Test
function recognition_view(t,band="far";angle=45.,single=false)
    features=Any[D("color"=>"brown","azimuth"=>[-5.,5.],"range_band"=>band,"distance"=>8.)]
    single || push!(features,D("color"=>"gray","azimuth"=>[angle-5,angle+5],"range_band"=>"far","distance"=>20.))
    D("source"=>"ob:$t:a","coverage"=>"complete","features"=>features)
end
move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
walk=D("action"=>"walk","direction"=>0,"purpose_family"=>"home")
function recognized_trip()
    s=mb_map_state("a";chunks=true)
    mb_observe!(s,recognition_view(0),0);mb_record!(s,walk,"performed",.01,0)
    mb_observe!(s,recognition_view(1_000_000,"mid"),1_000_000);mb_record!(s,walk,"performed",.01,1_000_000)
    mb_observe!(s,recognition_view(2_000_000,"near"),2_000_000;home=true)
    s
end
@testset "uncertain correspondence and learning from consequences" begin
    s=recognized_trip();origin=mb_scene(recognition_view(0)).key
    mb_observe!(s,recognition_view(3_000_000;angle=90.),3_000_000)
    @test s["current"].key!=origin
    matches=mb_correspondences(s,[origin],3_000_000)
    @test length(matches)==1 && 0<only(matches)["confidence"]<1
    @test only(matches)["probability"]==1
    candidates=mb_simulate!(s,move,"home",8,2,90.,0.,3_000_000)
    @test !isempty(candidates) && all(haskey(p,"mb_association") for p in candidates)
    # Explicitly try the hypothesis mapping the changed view to the learned origin.
    p=only(filter(p->p["mb_recognized"]==origin,candidates));id=p["mb_association"]
    mb_record!(s,p,"performed",.01,3_000_000)
    mb_observe!(s,recognition_view(4_000_000,"near"),4_000_000)
    @test s["recognition"]["associations"][id]["mismatches"]==1
    @test s["edges"][p["mb_edge"]]["samples"]==1 # Recognition does not merge the observed origin into memory.
    @test any(e["from"]==mb_scene(recognition_view(3_000_000;angle=90.)).key && e["to"]==s["current"].key for e in values(s["edges"]))
    @test last(s["recognition"]["feedback"])["cause"]=="recognition_or_transition_unresolved"
    mb_observe!(s,recognition_view(5_000_000;angle=90.),5_000_000)
    weakened=only(mb_correspondences(s,[origin],5_000_000))
    @test weakened["weight"]<only(matches)["weight"]
    evaluator=BasicLoop("recognition-evaluation";probabilistic=true,seed=7)
    alternative=D("method"=>"alternative","priority"=>3.)
    candidate(m)=mb_attach_correspondence!(D("method"=>"hypothesis","priority"=>3.),s,m)
    @test method_distribution(evaluator,[candidate(weakened),alternative])[1]<method_distribution(evaluator,[candidate(only(matches)),alternative])[1]
    # A blocked motor action is not evidence of a wrong location hypothesis.
    mb_record!(s,p,"blocked",.01,5_000_000)
    mb_observe!(s,recognition_view(6_000_000;angle=90.),6_000_000)
    @test s["recognition"]["associations"][id]["mismatches"]==1
    @test s["recognition"]["associations"][id]["execution_failures"]==1
    mb_record!(s,p,"performed",.01,6_000_000)
    mb_observe!(s,recognition_view(7_000_000,"mid"),7_000_000)
    @test s["recognition"]["associations"][id]["matches"]==1
    mb_observe!(s,recognition_view(8_000_000;angle=90.),8_000_000)
    @test only(mb_correspondences(s,[origin],8_000_000))["weight"]>weakened["weight"]
    mb_record!(s,p,"performed",.01,8_000_000)
    mb_observe!(s,recognition_view(9_000_000,"mid";single=true),9_000_000)
    @test s["current"]!==nothing && s["recognition"]["associations"][id]["unknown"]==1
    @test !isempty(mb_correspondences(s,[origin],9_000_000))
    @test s["chunk_reward"]==0 && isempty(s["chunks"])
    # Selecting recognition/action alternatives really uses the existing stochastic loop.
    loop=BasicLoop("a:recognition-test";probabilistic=true,seed=7)
    choices=[D("method"=>"one","action"=>"scan","question"=>"target_observed","priority"=>1.),D("method"=>"two","action"=>"scan","question"=>"target_observed","priority"=>1.)]
    chosen=Set{String}()
    for i in 1:100
        plan=choose_method!(loop,choices,"op:$i:a");push!(chosen,plan["method"])
        resolve_method!(loop,"op:$i:a",nothing,nothing;creditable=false)
    end
    @test length(chosen)==2
end
@testset "no age expiry and sleep-only capacity organization" begin
    s=recognized_trip();origin=mb_scene(recognition_view(0)).key
    now=100*17_280_000_000
    @test mb_search(s,origin,"home",now).solution!==nothing
    mb_sleep_freeze!(s,3_000_000);mb_sleep_review!(s,100,now)
    @test !isempty(s["sleep"]["hypotheses"])
    mb_observe!(s,recognition_view(now+1;angle=90.),now+1)
    @test !isempty(mb_sleep_candidates!(s,move,"home",8,2,90.,0.,now+1))
    @test s["chunk_reward"]==0
    # Age alone does not remove an unused hypothesis on another sleep review.
    ids=Set(keys(s["sleep"]["hypotheses"]))
    mb_sleep_freeze!(s,now+2);mb_sleep_review!(s,101,now+17_280_000_000)
    @test issubset(ids,Set(keys(s["sleep"]["hypotheses"])))
    full=mb_map_state("a")
    for i in 1:MB_MAP_NODE_LIMIT
        full["nodes"][string(i)]=D("signature"=>"brown:far:0","home"=>false,"food"=>false,"seen"=>0)
    end
    mb_observe!(full,recognition_view(0),0)
    @test length(full["nodes"])==MB_MAP_NODE_LIMIT && full["evictions"]==0
    @test full["recognition"]["admission_blocked"]==1
    mb_sleep_organize!(full,0,1_000_000)
    @test length(full["nodes"])==960 && full["evictions"]==320
    mb_sleep_organize!(full,0,2_000_000)
    @test length(full["recognition"]["sleep_reviews"])==1
end
