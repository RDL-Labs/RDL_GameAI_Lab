-- Small adapter tests run inside real Luanti before the shared-World fixture.
return function(module)
    local n=0
    local function check(v) n=n+1;assert(v,"L10C controller check " .. n) end
    local function setup(first,actions)
        local positions={npc_a=-4,npc_b=4};local stocks={npc_a=0,npc_b=0};local food=true;local claims=0
        local ds={}
        for _,id in ipairs({"npc_a","npc_b"}) do ds[id]={agent_id=id,operation_id="op",frame_id=id .. "-frame",
            decision_id=id .. "-decision",model_ref=id .. "-model",expires_us=1000000,action=actions and actions[id] or "attempt_food"} end
        local adapter={position=function(id) return positions[id] end,home=function(id) return id=="npc_a" and -4 or 4 end,
            move=function(id,x) positions[id]=x end,claim=function() if not food then return false end;food=false;claims=claims+1;return true end,
            deposit=function(id) stocks[id]=stocks[id]+1 end}
        local spec={capture_us=0,ready_us=100000,first=first,decisions=ds}
        return module.new(spec,adapter),ds,positions,stocks,function() return claims end,spec,adapter
    end
    for _,first in ipairs({"npc_a","npc_b"}) do
        for _,order in ipairs({{"npc_a","npc_b"},{"npc_b","npc_a"}}) do
            local t,ds,pos,stock,claims=setup(first)
            check(not t:consume("npc_a",ds.npc_b,250000))
            local changed=table.copy(ds.npc_a);changed.action="defer"
            check(not t:consume("npc_a",changed,250000))
            check(not t:consume(first,ds[first],249999))
            for i=0,8 do
                t:step(250000+i*250000,order)
                local before=core.write_json(t:snapshot());t:step(250000+i*250000,order)
                check(core.write_json(t:snapshot())==before)
            end
            check(t.complete and not t.aborted and claims()==1)
            check(t.claimant==first and stock[first]==1)
            local other=first=="npc_a" and "npc_b" or "npc_a"
            check(stock[other]==0 and t.actors[other].attempted and not t.actors[other].acquired)
            check(t.actors[first].actions==7 and t.actors[other].actions==4)
            check(not t:consume(first,ds[first],2500000) and claims()==1)
        end
    end
    local t,ds,pos,stock,claims=setup("npc_a",{npc_a="defer",npc_b="attempt_food"})
    for i=0,9 do t:step(250000+i*250000) end
    check(t.complete and t.claimant=="npc_b" and claims()==1)
    check(t.actors.npc_a.actions==0 and not t.actors.npc_a.attempted and pos.npc_a==-4)
    local jump=setup("npc_a");jump:step(750000)
    check(jump.aborted=="missed_execution_slot" and jump.actors.npc_a.actions==0)
    local mid=setup("npc_a");mid:step(250000);mid:step(750000)
    check(mid.aborted=="missed_execution_slot" and mid.actors.npc_a.actions==1)
    local _,_,_,_,_,spec,adapter=setup("npc_a");spec.ready_us=500001
    check(not pcall(module.new,spec,adapter))
    spec.ready_us=100000;spec.decisions.npc_a.action="defer"
    spec.decisions.npc_a.basis="acquisition_conditions_unavailable"
    check(not pcall(module.new,spec,adapter))
    local late=setup("npc_a")
    check(not late:consume("npc_a",late.actors.npc_a.decision,1000001))
    local budget=setup("npc_a");budget.actors.npc_a.actions=16;budget:step(250000)
    check(budget.aborted=="body_budget")
    local reentrant,_,_,_,_,_,re_adapter=setup("npc_a")
    local original=re_adapter.move
    re_adapter.move=function(id,x) reentrant:step(250000);original(id,x) end
    reentrant:step(250000)
    check(reentrant.actors.npc_a.actions==1)
    return n
end
