using Test
include("../../src/lw/LW.jl")
function reference_fit(state,a,b)
    aa=unique(a["items"]);bb=unique(b["items"])
    isempty(aa)!=isempty(bb) && return 0.
    fit=isempty(aa) ? 1. :
        (sum(maximum(LW.incidental_item_fit(state,f,g) for g in bb) for f in aa)/length(aa)+
         sum(maximum(LW.incidental_item_fit(state,g,f) for f in aa) for g in bb)/length(bb))/2
    fit*exp(-sum((a["food"].>0).!=(b["food"].>0)))
end
function reference_support(state,give,want,partner,context,H)
    scored=Any[]
    for m in state["exchange_relations"]
        fit=reference_fit(state,give,m["give"])*reference_fit(state,want,m["want"])
        fit*=partner==m["partner"] ? 1. : .25
        fit*=exp(-abs(context["need"]-m["need"]))
        push!(scored,(fit=fit,m=m))
    end
    sort!(scored;by=x->(-x.fit,-x.m["successes"],x.m["key"]))
    resize!(scored,min(length(scored),8,LW.mb_retrieval_budget(H)))
    successes=0.;failures=0.
    for x in scored;successes+=x.fit*x.m["successes"];failures+=x.fit*x.m["failures"];end
    (matches=scored,successes=successes,failures=failures)
end
f=LW.D("color"=>"cyan","size"=>.12,"light_source"=>.02)
g=LW.D("color"=>"blue","size"=>.18,"light_source"=>0.)
bundles=[LW.D("items"=>x,"food"=>food) for x in (Any[],Any[f],Any[f,deepcopy(f)],Any[f,g],Any[g,f])
    for food in ([0,0,0,0],[1,0,0,0],[4,0,0,0],[0,0,3,1])]
@testset "prepared matching keeps exact fits, order and H retrieval" begin
    state=LW.incidental_item_state("npc_a",33)
    for a in bundles,b in bundles
        @test isequal(reference_fit(state,a,b),LW.item_exchange_bundle_fit(state,a,b))
    end
    state["exchange_relations"]=Any[LW.D("give"=>a,"want"=>bundles[mod1(i+3,length(bundles))],
        "partner"=>isodd(i) ? "npc_b" : "npc_c","need"=>i/25,"key"=>string(i),
        "successes"=>mod(i,4),"failures"=>mod(i,3)) for (i,a) in enumerate(bundles)]
    saved=deepcopy(state);materials=IdDict{Any,LW.ItemFitMaterial}()
    for H in (0.,4.,16.),partner in ("npc_b","npc_c"),a in bundles
        b=bundles[1];context=LW.D("need"=>.3)
        expected=reference_support(state,a,b,partner,context,H)
        @test isequal(expected,LW.item_exchange_support(state,a,b,partner,context,H;materials))
    end
    @test length(materials)==length(bundles)
    @test isequal(state["exchange_relations"],saved["exchange_relations"])
    # A new decision must re-prepare changed quantities/learned prototype content.
    bundles[1]["food"][2]=2
    fresh=IdDict{Any,Any}()
    @test isequal(reference_support(state,bundles[1],bundles[2],"npc_b",LW.D("need"=>.3),4.),
        LW.item_exchange_support(state,bundles[1],bundles[2],"npc_b",LW.D("need"=>.3),4.;materials=fresh))
end

@testset "typed observation kernels infer concrete numeric results" begin
    a=LW.ObservedItemFeatures(f);b=LW.ObservedItemFeatures(g)
    w=(2.,1.)
    @test (@inferred LW.item_feature_fit(a,b,w)) == LW.incidental_item_fit(LW.incidental_item_state("a"),f,g)
    x=LW.item_exchange_fit_material(bundles[5]);y=LW.item_exchange_fit_material(bundles[end])
    @test (@inferred LW.item_exchange_material_fit(x,y,w)) == reference_fit(LW.incidental_item_state("a"),bundles[5],bundles[end])
end
