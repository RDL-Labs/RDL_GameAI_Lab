-- L10C: one shared resource, two learners, continuously advancing World time.
return function(http,runtime_url,profiles)
    local root=core.get_modpath("rdl_bridge")
    local distant=dofile(root .. "/distant_sensor.lua")
    local hearing=dofile(root .. "/audition_window_sensor.lua").new(250000,32,8)
    local trial_module=dofile(root .. "/shared_food_trial.lua")
    local checks=dofile(root .. "/shared_food_trial_checks.lua")(trial_module)
    local run=assert(core.settings:get("rdl_learning_run_id"))
    local scenario=core.settings:get("rdl_learning_shared_scenario") or "both_active"
    local variants={both_active={true,true},neither_active={false,false},a_only={true,false},
        b_only={false,true},reversed_cues={true,true}}
    local activation=assert(variants[scenario])
    local prefix=runtime_url:gsub("/v1/observe$","")
    local ids={"npc_a","npc_b"}
    local sim_us,episode,stage,stage_us=0,0,"init",0
    local agents,food,trial,current={}
    local marker={x=0,y=1,z=14}
    local evidence={schema="l10c-world-v1",run_id=run,scenario=scenario,episodes={},by_agent={},
        lua_checks=checks,resets=0}
    local function encode(v)
        local data=core.write_json(v)
        for _,key in ipairs({"visible_agents","visible_objects","visible_places","visible_regions","recent_events","external_statements","features","detections"}) do
            data=data:gsub('("' .. key .. '"%s*:%s*)null','%1[]')
        end
        return data
    end
    local function phase(value) stage=value;stage_us=sim_us end
    local function fail(reason)
        evidence.failure={reason=reason,stage=stage,at_us=sim_us,episode=episode}
        if trial then evidence.incomplete_trial=trial:snapshot() end
        core.safe_file_write(core.get_worldpath() .. "/l10c-evidence.json",encode(evidence))
        phase("failed");core.log("error","[L10C] " .. reason)
    end
    local function send(a,path,payload,null_result)
        assert(not a.busy);a.busy=true;a.path=path
        local data=payload and encode(payload) or nil
        if null_result then data=data:gsub('}$',',"food_acquired":null}') end
        http.fetch({url=prefix .. path,method=payload and "POST" or "GET",timeout=3,
            extra_headers={"Content-Type: application/json"},data=data},function(r)
            -- No body/state-machine effect in callback. Alternating bounded delivery hold.
            a.reply={ok=r.succeeded and r.code==200,wire=r.data,
                release_us=sim_us+(path=="/v1/luanti-learning/decide" and
                    ((episode%2==1 and a.id=="npc_a") or (episode%2==0 and a.id=="npc_b")) and 40000 or 0)}
        end)
    end
    local function take(a) local r=a.mailbox;a.mailbox=nil;return r end
    local function all_ready()
        for _,id in ipairs(ids) do if agents[id].busy or not agents[id].mailbox then return false end end
        return true
    end
    local function packet(a,frames,label)
        local objects,others={},{}
        if food and food:get_pos() then
            local delta=vector.subtract(food:get_pos(),a.npc:get_pos())
            if vector.length(delta)<=a.profile.vision_local.radius then
                objects={{id="shared_food",kind="food",relative_position=delta,distance=vector.length(delta)}}
            end
        end
        for _,id in ipairs(ids) do if id~=a.id then
            local delta=vector.subtract(agents[id].npc:get_pos(),a.npc:get_pos())
            if vector.length(delta)<=a.profile.vision_local.radius then
                others[#others+1]={id=id,kind="npc",relative_position=delta,distance=vector.length(delta)}
            end
        end end
        local p={observation_id=run .. ":" .. a.id .. ":" .. episode .. ":" .. label,
            tick=math.floor(sim_us/250000),agent_id=a.id,observation={
                perception_rule="finite local radius; L10C shared apparatus",visible_agents=others,visible_objects=objects,
                visible_places={},visible_regions={},recent_events={},external_statements={}}}
        if frames then p.observation.sensory_extension={schema_version="rdl-sensory-extension-v1",run_id=run,
            world_epoch=1,agent_id=a.id,delivery_observation_id=p.observation_id,delivery_world_tick=p.tick,
            delivery_time_us=sim_us,frames=frames} end
        return p
    end
    local function frame(a,channel,payload,partial,limited)
        return {frame_id=run .. ":" .. a.id .. ":" .. channel .. ":" .. episode,agent_id=a.id,
            sensor_id=channel=="audition" and "ear" or "eye",channel=channel,profile_id=a.profile.profile_id,
            profile_revision=1,sensor_model_revision=channel=="vision_distant" and "sampled-surface-v0.2" or
                channel=="vision_local" and "legacy_radius_v1" or "direct_band_energy_v0",
            sample_seq=episode,clock_id="world-sim-v1",sampled_world_tick=math.floor(sim_us/250000),
            capture_window={kind=channel=="audition" and "interval" or "instant",
                start_us=channel=="audition" and sim_us-250000 or sim_us,end_us=sim_us},
            observer_frame_ref=run .. ":" .. a.id .. ":pose:" .. episode,status="SAMPLED",
            coverage=partial and "PARTIAL" or "COMPLETE_WITHIN_PLAN",output_limited=limited or false,payload=payload}
    end
    local function reset()
        assert(not trial or trial.complete,"reset before both completed")
        episode=episode+1;evidence.resets=evidence.resets+1;trial=nil
        assert(not food or not food:get_pos(),"resource left by previous Episode")
        local red=episode%2==1
        local color=red and "muted_red" or "dark_gray"
        local node=red and "rdl_bridge:distant_red" or "rdl_bridge:distant_dark"
        local first=red and "npc_a" or "npc_b"
        if scenario=="reversed_cues" then first=first=="npc_a" and "npc_b" or "npc_a" end
        if episode>=11 then first=first=="npc_a" and "npc_b" or "npc_a" end
        current={episode_id=run .. ":shared-episode:" .. episode,index=episode,capture_us=sim_us,
            color_band=color,first_agent=first,by_agent={},packets={before={},after={}},entity_removals=0,decision_deliveries={}}
        evidence.episodes[#evidence.episodes+1]=current
        core.set_node(marker,{name=node})
        food=core.add_entity({x=0,y=1,z=0},"rdl_bridge:food","shared_food");assert(food)
        for _,id in ipairs(ids) do
            local a=agents[id]
            a.npc:set_pos({x=a.home,y=1,z=0});a.npc:set_yaw(core.dir_to_yaw(vector.subtract(marker,a.npc:get_pos())))
            a.npc:get_luaentity().rdl_held_food=false
        end
        for _,id in ipairs(ids) do
            local a=agents[id]
            local features,partial,limited=distant.sample(a.npc,a.profile.vision_distant,{{position=marker,node_name=node,color_band=color}})
            local f=frame(a,"vision_distant",{features=features},partial,limited)
            local p=packet(a,nil,"before")
            local closed=hearing:close(id,sim_us-250000,a.profile.audition)
            local frames={frame(a,"vision_local",{visible_count=#p.observation.visible_objects+#p.observation.visible_agents},false,false),
                f,frame(a,"audition",{detections=closed.detections},closed.incomplete,closed.incomplete)}
            a.op=run .. ":" .. id .. ":op:" .. episode
            if episode<=6 then a.formation[#a.formation+1]=a.op elseif episode<=8 then a.validation[#a.validation+1]=a.op end
            a.frame_id=f.frame_id
            current.by_agent[id]={start_x=a.npc:get_pos().x,base_stock_before=a.base:get_luaentity().rdl_food_stock}
            p=packet(a,frames,"before");current.packets.before[id]=table.copy(p)
            send(a,"/v1/observe",p)
        end
        phase("observing")
    end
    local adapter={}
    function adapter.position(id) return agents[id].npc:get_pos().x end
    function adapter.home(id) return agents[id].home end
    function adapter.move(id,x)
        local npc=agents[id].npc;local p=npc:get_pos()
        npc:set_yaw(x>p.x and -math.pi/2 or math.pi/2);npc:set_pos({x=x,y=p.y,z=p.z})
    end
    function adapter.claim(id)
        if not food or not food:get_pos() then return false end
        assert(not current.claimant and vector.distance(agents[id].npc:get_pos(),food:get_pos())<=1.25)
        current.claimant=id;current.entity_removals=current.entity_removals+1
        local entity=food;food=nil;entity:remove()
        agents[id].npc:get_luaentity().rdl_held_food=true
        return true
    end
    function adapter.deposit(id)
        local a=agents[id];assert(a.npc:get_luaentity().rdl_held_food and current.claimant==id)
        a.npc:get_luaentity().rdl_held_food=false
        a.base:get_luaentity().rdl_food_stock=a.base:get_luaentity().rdl_food_stock+1
    end
    core.register_on_mods_loaded(function() core.after(0,function()
        core.load_area({x=-6,y=-1,z=-2},{x=6,y=3,z=16})
        for x=-6,6 do for y=0,3 do for z=-2,16 do core.set_node({x=x,y=y,z=z},{name="air"}) end end end
        core.forceload_block({x=-4,y=1,z=0},true);core.forceload_block({x=4,y=1,z=0},true);core.forceload_block(marker,true)
        for i,id in ipairs(ids) do
            local a={id=id,home=i==1 and -4 or 4,profile=profiles[id],formation={},validation={}}
            a.npc=core.add_entity({x=a.home,y=1,z=0},"rdl_bridge:npc",id)
            a.base=core.add_entity({x=a.home,y=1,z=0},"rdl_bridge:base",id .. "-base")
            assert(a.npc and a.base);a.npc:set_properties({physical=false});a.base:set_properties({physical=false})
            a.base:get_luaentity().rdl_food_stock=0;agents[id]=a
            evidence.by_agent[id]={activate=activation[i],profile_id=profiles[id].profile_id}
        end
        phase("ready")
    end) end)
    core.register_globalstep(function(dt)
        if stage=="done" or stage=="failed" then return end
        sim_us=sim_us+math.floor(dt*1000000+0.5)
        for _,id in ipairs(ids) do
            local a=agents[id]
            if a and a.reply and sim_us>=a.reply.release_us then
                if not a.reply.ok then fail("HTTP " .. a.path .. ": " .. tostring(a.reply.wire));return end
                a.wire=a.reply.wire;a.mailbox=core.parse_json(a.wire);a.reply=nil;a.busy=false
                if a.path=="/v1/luanti-learning/decide" then
                    current.decision_deliveries[#current.decision_deliveries+1]={agent_id=id,at_us=sim_us}
                end
            end
        end
        if sim_us-stage_us>10000000 then fail("stage timeout");return end
        if stage=="ready" and sim_us>=250000 then reset()
        elseif stage=="observing" or stage=="deciding" or stage=="replaying" then
            if sim_us>current.capture_us+500000 then fail("start barrier expired");return end
            if not all_ready() then return end
            for _,id in ipairs(ids) do
                local a=agents[id];local r=take(a)
                if stage=="observing" then
                    assert(r.sensory_receipt.accepted and r.sensory_receipt.new_frames==3)
                    a.request={operation_id=a.op,episode_id=current.episode_id,agent_id=id,run_id=run,world_epoch=1,
                        frame_id=a.frame_id,now_us=sim_us}
                    current.by_agent[id].request=table.copy(a.request)
                    send(a,"/v1/luanti-learning/decide",a.request)
                elseif stage=="deciding" then
                    assert(r.agent_id==id and r.operation_id==a.op and r.frame_id==a.frame_id)
                    current.by_agent[id].decision_wire=a.wire
                    a.decision=r;a.decision_wire=a.wire;current.by_agent[id].decision_received_us=sim_us
                    send(a,"/v1/luanti-learning/decide",a.request)
                else assert(a.wire==a.decision_wire,"changed decision replay") end
            end
            if stage=="observing" then phase("deciding")
            elseif stage=="deciding" then phase("replaying")
            else
                local decisions={};for _,id in ipairs(ids) do decisions[id]=agents[id].decision end
                current.ready_us=sim_us
                local ok,value=pcall(trial_module.new,{capture_us=current.capture_us,ready_us=sim_us,
                    first=current.first_agent,decisions=decisions},adapter)
                if not ok then fail(tostring(value));return end
                trial=value
                phase("acting")
            end
        elseif stage=="acting" then
            for _,id in ipairs(ids) do
                local other=id=="npc_a" and "npc_b" or "npc_a"
                assert(not trial:consume(id,agents[other].decision,sim_us))
            end
            local order=episode%2==1 and {"npc_a","npc_b"} or {"npc_b","npc_a"}
            trial:step(sim_us,order)
            if trial.aborted then fail(trial.aborted);return end
            if not trial.complete then return end
            current.trial=trial:snapshot()
            for _,id in ipairs(ids) do
                local a=agents[id];local t=trial.actors[id];local w=current.by_agent[id]
                local other=id=="npc_a" and "npc_b" or "npc_a"
                local before=adapter.position(id);local stock=a.base:get_luaentity().rdl_food_stock
                assert(not trial:consume(id,agents[other].decision,sim_us))
                assert(not trial:consume(id,a.decision,sim_us))
                assert(adapter.position(id)==before and a.base:get_luaentity().rdl_food_stock==stock)
                w.replay_rejected=true;w.foreign_rejected=true;w.finish_x=before;w.base_stock_after=stock
                a.result={agent_id=id,decision_id=a.decision.decision_id,operation_id=a.op,
                    event_id=run .. ":" .. id .. ":event:" .. episode,completed_us=t.completed_us,
                    attempted=t.attempted,food_acquired=t.attempted and t.acquired or nil}
                if t.attempted then a.result.food_acquired=t.acquired end
                w.result=table.copy(a.result)
                send(a,"/v1/luanti-learning/result",a.result,not t.attempted)
            end
            phase("results")
        elseif stage=="results" and all_ready() then
            for _,id in ipairs(ids) do local a=agents[id];take(a);send(a,"/v1/luanti-learning/result",a.result,not a.result.attempted) end
            phase("result_replay")
        elseif stage=="result_replay" and all_ready() then
            for _,id in ipairs(ids) do
                local a=agents[id];take(a);local p=packet(a,nil,"after")
                current.packets.after[id]=table.copy(p);send(a,"/v1/observe",p)
            end
            phase("after")
        elseif stage=="after" and all_ready() then
            for _,id in ipairs(ids) do take(agents[id]) end
            if episode==8 then
                send(agents.npc_a,"/v1/canonical-snapshot",nil);phase("inspection")
            elseif episode==12 then
                evidence.finished_us=sim_us
                core.safe_file_write(core.get_worldpath() .. "/l10c-evidence.json",encode(evidence));phase("done")
            else phase("ready") end
        elseif stage=="inspection" and agents.npc_a.mailbox then
            local snapshot=take(agents.npc_a)
            for _,id in ipairs(ids) do
                local a=agents[id];local record
                for _,r in ipairs(snapshot.assessment.records) do
                    if r.E.agent_id==id and not r.reviewed and math.abs(r.E.deltas.visible_objects_count)>=1 then record=r end
                end
                assert(record,"independent canonical comparison missing")
                a.assessment_id=record.assessment_id
                local dimensions={}
                for k,v in pairs(record.E.deltas) do dimensions[k]=v==0 and {status="zero"} or {status="unresolved",residual=1} end
                send(a,"/v1/assessment-review",{assessment_id=record.assessment_id,expected_revision=record.revision,
                    reviewer="l10c-explicit-fixture",basis="independent finite count review; not acquisition loss",
                    evidence=run,dimensions=dimensions})
            end
            phase("reviewed")
        elseif stage=="reviewed" and all_ready() then
            for i,id in ipairs(ids) do
                local a=agents[id];take(a)
                send(a,"/v1/luanti-learning/learn",{learning_id=run .. ":" .. id .. ":learn",agent_id=id,
                    formation_operations=a.formation,validation_operations=a.validation,assessment_id=a.assessment_id,activate=activation[i]})
            end
            phase("learned")
        elseif stage=="learned" and all_ready() then
            for _,id in ipairs(ids) do evidence.by_agent[id].learning=take(agents[id]) end
            phase("ready")
        end
    end)
end
