include("checks.jl")
@testset "movement and exchange share finite transition refinement" begin
    map=LW.D("coverage"=>"complete","output_limited"=>false,"groups"=>Any[])
    @test LW.rho_descent(0.,map).angle==0.
    # Refactoring preserves local movement minimization, including ties.
    for heading in (-70.,0.,55.), x in (-.4,.6)
        m=merge(map,LW.D("groups"=>[LW.D("kind"=>"obstacle","points"=>[(x,.7)])]))
        offsets=(0.,-11.25,11.25,-22.5,22.5,-33.75,33.75,-45.,45.)
        scores=[LW.rho_potential(m,(.5sind(heading+d),.5cosd(heading+d)),heading).total for d in offsets]
        @test LW.rho_descent(heading,m).angle≈heading+offsets[argmin(scores)]
    end
    @test LW.relational_transition(3.,5.;probability=.5,cost=.2).expected≈.9
    @test LW.relational_best(x->LW.relational_transition(0.,x),[1.,3.,2.]).candidate==3.
    @test_throws ErrorException LW.relational_transition(0.,NaN)
    @test_throws ErrorException LW.relational_transition(0.,1.;probability=2.)
end

@testset "quantities change utility gradients without changing relation" begin
    f=item_fixture(objects=[placed_item(1,1;owner=ITEM_A,location="held"),
        placed_item(2,1;owner=ITEM_A,location="held"),
        placed_item(3,3;owner=ITEM_B,location="held"),placed_item(4,3;owner=ITEM_B,location="held")])
    s=LW.incidental_item_state(ITEM_A,19);v=item_view(f,ITEM_A);values=LW.item_subjective_values(s,v)
    gain(g,w,gf,wf;stock=zeros(Int,4),weights=ones(4))=LW.item_social_gain(v["own"],stock,values,weights,g,w,gf,wf;visible=v["visible"])
    g=[gain([1],Int[],zeros(Int,4),[n,0,0,0]) for n in 1:3]
    @test g[1]<g[2]<g[3]
    @test g[3]-g[2]<g[2]-g[1]
    @test gain([1],Int[],zeros(Int,4),[1,0,0,0];stock=[20,0,0,0])<g[1]
    @test gain([1],Int[],zeros(Int,4),[1,0,0,0];weights=2ones(4))>g[1]
    @test gain([1,2],Int[],zeros(Int,4),[1,0,0,0])<g[1]
    @test gain(Int[],[3,4],[1,0,0,0],zeros(Int,4);stock=[5,0,0,0])>gain(Int[],[3],[1,0,0,0],zeros(Int,4);stock=[5,0,0,0])
    @test gain(Int[],[3],[2,0,0,0],zeros(Int,4);stock=[5,0,0,0])<gain(Int[],[3],[1,0,0,0],zeros(Int,4);stock=[5,0,0,0])
    give=LW.item_exchange_bundle(v,[1],zeros(Int,4));want=LW.item_exchange_bundle(v,Int[],[1,0,0,0])
    more=LW.item_exchange_bundle(v,Int[],[3,0,0,0]);two=LW.item_exchange_bundle(v,[1,2],zeros(Int,4))
    @test LW.item_exchange_key(ITEM_B,give,want)==LW.item_exchange_key(ITEM_B,two,more)
    @test LW.item_exchange_bundle_fit(s,give,two)==1
    @test LW.item_exchange_bind(s,two["items"],v["own"]["held"][1:1];partial=true)==[1]
    @test LW.item_exchange_bind(s,two["items"],Any[];partial=true)===nothing
    @test LW.item_exchange_bundle_fit(s,want,more)==1
    plan(q)=LW.D("exchange_give"=>give,"exchange_want"=>q,"partner"=>ITEM_B,"action"=>"item_offer","context"=>LW.D("need"=>0.))
    LW.item_exchange_learn!(s,plan(want),LW.D("status"=>"exchanged","us"=>1))
    m=only(s["exchange_relations"])
    @test LW.item_exchange_response(m,give,want)>LW.item_exchange_response(m,give,more)
    before=LW.item_exchange_response(m,give,more)
    LW.item_exchange_learn!(s,plan(more),LW.D("status"=>"declined","us"=>2))
    @test length(s["exchange_relations"])==1
    @test m["successes"]==1 && m["failures"]==1
    @test LW.item_exchange_response(m,give,more)<before
    middle=LW.item_exchange_bundle(v,Int[],[2,0,0,0])
    e=LW.item_exchange_recall(s,give,middle,ITEM_B,LW.D("need"=>0.),0.)
    @test e.successes==1 && e.failures==1 && isfinite(e.predicted)
    @test LW.incidental_item_snapshot(item_saved_copy(s))==LW.incidental_item_snapshot(s)
    # Quantity variants are local choices of ONE method, not extra lottery tickets.
    cs=[LW.D("method"=>"same","q"=>n,"relational_field"=>LW.relational_transition(0.,log1p(n))) for n in 1:3]
    @test only(LW.item_exchange_refine(cs))["q"]==3
    # Legacy aggregates merge counts without fabricating quantity observations.
    old=LW.incidental_item_state(ITEM_A)
    old["exchange_relations"]=[LW.D("key"=>"old-$i","partner"=>ITEM_B,"give"=>give,"want"=>q,
        "need"=>0.,"successes"=>i,"failures"=>i+1,"last_us"=>i) for (i,q) in enumerate((want,more))]
    migrated=LW.item_exchange_memory!(old)
    @test length(migrated)==1
    @test only(migrated)["successes"]==3 && only(migrated)["failures"]==5
    @test length(only(migrated)["quantity_observations"])==2
    copy_migrated=deepcopy(migrated);LW.item_exchange_memory!(old)
    @test old["exchange_relations"]==copy_migrated
    # The executor receipt and forecast use the same frozen quantity utility.
    predicted=gain([1],[3],zeros(Int,4),zeros(Int,4);stock=f.foods.personal[ITEM_A])
    offer=item_act(f,ITEM_A,"item_offer",20;target=ITEM_B,give_items=[1],want_items=[3])
    result=item_act(f,ITEM_B,"item_accept",21;offer_id=offer["offer_id"])
    @test result["status"]=="exchanged"
    notice=only(filter(n->get(n,"offer_id",nothing)==offer["offer_id"] && n["status"]=="exchanged",item_view(f,ITEM_A;now=22)["notices"]))
    @test LW.item_social_actual(LW.D("values"=>values,"weights"=>ones(4)),notice)≈predicted-.002
    @test item_checks(f)===nothing
end
