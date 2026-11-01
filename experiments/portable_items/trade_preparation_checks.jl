using Test, JSON3
include("../../src/lw/LW.jl")
row(id,color="cyan",size=.12,light=.02)=LW.D("ref"=>id,"color"=>color,"size"=>size,"light_source"=>light)
@testset "prepared observations preserve gain, binding and duplicate rules" begin
    for duplicate in (false,true), invalid_first in (false,true)
        a=row(1);b=row(2,"blue",.18,0.);c=row(3,"cream",.1,0.)
        invalid_first && (a["color"]=3)
        visible=duplicate ? Any[c,row(1,"orange",.3,.04),row(3,"blue",.18,0.)] : Any[c]
        view=LW.D("own"=>LW.D("held"=>Any[a],"stored"=>Any[b]),"visible"=>visible)
        original=deepcopy(view);state=LW.incidental_item_state("npc_a",33)
        stock=[4,0,2,0];weights=[.8,1.,.2,.4]
        values=LW.item_subjective_values(state,view;stock,weights)
        p=LW.item_social_prepare(state,view,stock,weights)
        @test isequal(p.values,values)
        @test isequal(p.before,LW.item_social_utility(view["own"],stock,values,weights))
        for give in (Int[],[1],[2],[1,2],[99]), want in (Int[],[3],[1],[99]), n in (0,1,4,5)
            gf=[n,0,0,0];wf=[0,0,1,0]
            old=LW.item_social_gain(view["own"],stock,values,weights,give,want,gf,wf;visible)
            new=LW.item_social_gain(view["own"],stock,values,weights,give,want,gf,wf;visible,prepared=p)
            @test isequal(old,new)
        end
        for ids in (Int[],[1],[2],[3],[1,2],[3,1],[1,1],[99])
            @test isequal(LW.item_exchange_bundle(view,ids,stock),LW.item_exchange_prepared_bundle(p.by_ref,ids,stock))
        end
        @test isequal(view,original)
        a["color"]="red"
        fresh=LW.item_social_prepare(state,view,stock,weights)
        @test fresh.by_ref[1]["color"]=="red"
        @test p.by_ref[1]===nothing || p.by_ref[1]["color"]=="cyan"
    end
end
