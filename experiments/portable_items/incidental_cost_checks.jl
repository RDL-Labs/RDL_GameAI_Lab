# Deliberate operation fixture: exercise accounting, not autonomous item selection.
using Test
include(joinpath(@__DIR__,"../../src/lw/simulation/integrated.jl"))

cost_view(now,band)=D("source"=>"ob:$now:a","coverage"=>"complete","features"=>[
    D("color"=>"brown","azimuth"=>[-5.,5.],"range_band"=>band,"distance"=>5.),
    D("color"=>"gray","azimuth"=>[40.,50.],"range_band"=>"far","distance"=>20.)])
const COST_MOVE=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
cost_pickup(goal;incidental=true)=D("action"=>"item_pickup","purpose_family"=>goal,
    "portable_item_action"=>true,"incidental_item"=>incidental)
function cost_fixture(goal)
    s=mb_map_state("a";chunks=true)
    walk=D("action"=>"walk","direction"=>0,"purpose_family"=>goal)
    mb_observe!(s,cost_view(0,"far"),0)
    mb_record!(s,walk,"performed",.01,0)
    mb_observe!(s,cost_view(1_000_000,"mid"),1_000_000)
    mb_record!(s,walk,"performed",.01,1_000_000)
    mb_observe!(s,cost_view(2_000_000,"near"),2_000_000)
    path=copy(s["route_trace"]);mb_trace_reset!(s)
    mb_observe!(s,cost_view(3_000_000,"far"),3_000_000)
    p=mb_route_attach!(merge(walk,D("priority"=>2.,"mb_edge"=>first(path))),s,path,goal,"wake")
    mb_parent_begin!(s,p,goal,nothing,3_000_000)
    mb_record!(s,p,"performed",.01,3_000_000)
    mb_observe!(s,cost_view(4_000_000,"mid"),4_000_000)
    s,p
end

@testset "incidental costs preserve the selected parent and route" begin
    for goal in ("home","food")
        s,p=cost_fixture(goal)
        parent=s["parent_mb"]["active"][goal];route=s["routes"]["active"]
        estimate=deepcopy(parent["estimate"]);route_estimate=deepcopy(route["estimate"])
        path=copy(route["path"]);trace=copy(s["route_trace"])
        # Consecutive pickups, including execution failures, must not lose costs
        # merely because no navigation trial is evaluated on those ticks.
        for tick in 4:11
            status=iseven(tick) ? "item_picked_up" : "item_unavailable"
            mb_record!(s,cost_pickup(goal),status,.1,tick*1_000_000)
            mb_observe!(s,cost_view((tick+1)*1_000_000,"mid"),(tick+1)*1_000_000)
            @test s["parent_mb"]["active"][goal]===parent
            @test s["routes"]["active"]===route
            @test parent["estimate"]==estimate && route["estimate"]==route_estimate
            @test route["path"]==path && route["cursor"]==2 && route["verified"]==1
            @test s["route_trace"]==trace && s["trace_goal"]==goal
            @test s["last_chunk_operation"]===nothing
            @test !mb_goal_result!(s,goal,"op:$(tick*1_000_000):a",true,8,0,(tick+1)*1_000_000)
            # Child operations cannot bind a parent/route completion.
            @test mb_parent_H_increment!(s,goal,"op:$(tick*1_000_000):a",false,(tick+1)*1_000_000)===nothing
            @test mb_route_H_increment!(s,goal,"op:$(tick*1_000_000):a",false,(tick+1)*1_000_000)===nothing
            mb_route_goal!(s,goal,"op:$(tick*1_000_000):a",true,8,0,(tick+1)*1_000_000)
            @test s["routes"]["active"]===route
        end
        @test parent["actions"]==9 && parent["energy"]≈.81
        @test route["effort"]["actions"]==9 && route["effort"]["energy"]≈.81
        @test parent["last_us"]==route["last_us"]==3_000_000
        @test s["parent_mb"]["successes"]==0 && s["chunk_goal_credits"]==0
        @test get(s["routes"]["stats"][route["id"]],"reward",0)==0
        # Resume the actual route. All the retained cost appears in its next
        # ordinary residual evaluation, without granting more forecast time.
        q=only(mb_route_candidates!(s,COST_MOVE,goal,90.,0.,12_000_000))
        q["purpose_family"]=goal
        mb_parent_begin!(s,q,goal,nothing,12_000_000)
        mb_record!(s,q,"performed",.01,12_000_000)
        mb_observe!(s,cost_view(13_000_000,"near"),13_000_000)
        child=mb_route_H_increment!(s,goal,"op:12000000:a",false,13_000_000)
        inc=mb_parent_H_increment!(s,goal,"op:12000000:a",false,13_000_000;child_increment=child)
        @test child>0 && inc>=child
        @test parent["actions"]==route["effort"]["actions"]==10
        @test parent["estimate"]==estimate && route["estimate"]==route_estimate
        @test length(s["route_trace"])==2 && route["cursor"]==3
        @test last(s["parent_mb"]["records"])["actions"]==10
        @test mb_parent_H_increment!(s,goal,"op:12000000:a",false,13_000_000;child_increment=child)==inc
        @test s["parent_mb"]["H_requested"]==inc
    end
end

@testset "incidental action cannot create a parent or bypass a purpose switch" begin
    s=mb_map_state("a";chunks=true)
    mb_observe!(s,cost_view(0,"mid"),0)
    mb_record!(s,cost_pickup("home"),"item_picked_up",.2,0)
    @test isempty(s["parent_mb"]["active"]) && isempty(s["parent_mb"]["models"])
    @test s["routes"]["active"]===nothing && s["routes"]["started"]==0
    s,p=cost_fixture("home");parent=s["parent_mb"]["active"]["home"]
    mb_record!(s,cost_pickup("food"),"item_picked_up",.2,4_000_000)
    mb_observe!(s,cost_view(5_000_000,"mid"),5_000_000)
    @test !haskey(s["parent_mb"]["active"],"food")
    @test parent["actions"]==1 && parent["energy"]≈.01 && parent["paused"]
    @test s["routes"]["active"]===nothing
    @test last(s["routes"]["events"])["reason"]=="parent_purpose_changed"
    @test isempty(s["route_trace"]) && s["chunk_goal_credits"]==0
end

@testset "scheduled item operations retain their old pause semantics" begin
    s,p=cost_fixture("home");parent=s["parent_mb"]["active"]["home"]
    route=s["routes"]["active"];before=deepcopy(route["effort"])
    mb_record!(s,cost_pickup("home";incidental=false),"item_picked_up",.2,4_000_000)
    mb_observe!(s,cost_view(5_000_000,"mid"),5_000_000)
    @test parent["actions"]==1 && parent["energy"]≈.01 && parent["paused"]
    @test route["effort"]==before && route["reason"]=="social_pause"
    @test isempty(s["route_trace"])
end

@testset "incidental pauses do not invent bridges across observation changes" begin
    for observation in ("changed","missing","gap")
        s,p=cost_fixture("home")
        mb_record!(s,cost_pickup("home"),"item_picked_up",-.1,4_000_000)
        now=observation=="gap" ? 6_000_000 : 5_000_000
        obs=cost_view(now,observation=="changed" ? "near" : "mid")
        observation=="missing" && (obs["coverage"]="partial")
        mb_observe!(s,obs,now)
        @test isempty(s["route_trace"])
        @test s["routes"]["active"]["cursor"]==2
        @test s["parent_mb"]["active"]["home"]["energy"]≈.01
        @test s["routes"]["active"]["effort"]["energy"]≈.01
        @test s["last_chunk_operation"]===nothing
    end
end
