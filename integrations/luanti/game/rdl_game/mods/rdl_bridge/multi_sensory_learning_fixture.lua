-- L10B: two independent learners, one continuously advancing World clock.
return function(http,runtime_url,profiles)
    local scenario=core.settings:get("rdl_learning_multi_scenario") or "opposite"
    assert(scenario=="opposite" or scenario=="a_only" or scenario=="b_only")
    local clock_us=0
    core.register_globalstep(function(dt) clock_us=clock_us+math.floor(dt*1000000+0.5) end)
    local evidence={schema="l10b-world-v1",scenario=scenario,by_agent={}}
    local decisions={}
    local function complete(agent,value)
        evidence.by_agent[agent]=value
        if evidence.by_agent.npc_a and evidence.by_agent.npc_b then
            evidence.finished_us=clock_us
            core.safe_file_write(core.get_worldpath() .. "/l10b-evidence.json",core.write_json(evidence))
            core.log("action","[RDL_LUANTI_L10B] complete A/B episodes=24")
        end
    end
    local controller=dofile(core.get_modpath("rdl_bridge") .. "/sensory_learning_fixture.lua")
    for _,agent in ipairs({"npc_a","npc_b"}) do
        local a=agent=="npc_a"
        controller(http,runtime_url,profiles[agent],{
            agent_id=agent,multi_agent=true,offset=a and -12 or 12,
            activate=scenario=="opposite" or (a and scenario=="a_only") or (not a and scenario=="b_only"),
            reverse=not a and scenario=="opposite",clock=function() return clock_us end,
            delay_learning_us=a and 2000000 or nil,decisions=decisions,on_complete=complete,
        })
    end
end
