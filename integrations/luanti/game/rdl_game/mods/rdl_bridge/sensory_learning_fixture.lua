-- L10: finite episodes. World geometry stays on this side of the HTTP boundary.
return function(http, runtime_url, profile, options)
    options=options or {}
    local agent=options.agent_id or "npc_a"
    local offset=options.offset or 0
    local root=core.get_modpath("rdl_bridge")
    local distant=dofile(root .. "/distant_sensor.lua")
    local hearing=dofile(root .. "/audition_window_sensor.lua").new(250000,32,8)
    local transmission=dofile(root .. "/audition_transmission.lua")
    local run=core.settings:get("rdl_learning_run_id") or "l10"
    local activate=core.settings:get_bool("rdl_learning_activate",false)
    local reverse=core.settings:get_bool("rdl_learning_reverse",false)
    if options.activate~=nil then activate=options.activate end
    if options.reverse~=nil then reverse=options.reverse end
    local namespace=options.multi_agent and run .. ":" .. agent or run
    local prefix=runtime_url:gsub("/v1/observe$","")
    local npc,food,base
    local stage,episode,sim_us,seq="init",0,0,0
    local mailbox,wire,busy=nil,nil,false
    local held_reply=nil
    local current,decision,actions,attempted,acquired,deposited,blocked
    local executed,records={},{}
    local formation,validation={},{}
    local marker={x=offset,y=1,z=14}
    local start={x=offset,y=1,z=0}
    local food_pos={x=offset+4,y=1,z=0}
    local color,node_name,op,frame_id,decision_request_us
    local evidence={run_id=run,agent_id=agent,activate=activate,reverse=reverse,episodes=records}

    local function encode(value)
        local data=core.write_json(value)
        for _,key in ipairs({"visible_agents","visible_objects","visible_places","visible_regions","recent_events","external_statements","features","detections"}) do
            data=data:gsub('("' .. key .. '"%s*:%s*)null','%1[]')
        end
        return data
    end
    local function send(path,payload)
        assert(not busy);busy=true
        http.fetch({url=prefix .. path,method=payload and "POST" or "GET",timeout=3,
            extra_headers={"Content-Type: application/json"},data=payload and encode(payload) or nil},function(r)
            assert(r.succeeded and r.code==200,"L10 HTTP " .. path .. " " .. tostring(r.data))
            if path=="/v1/luanti-learning/learn" and options.delay_learning_us then
                evidence.learning_hold_started_us=options.clock()
                held_reply={data=r.data,release_us=options.clock()+options.delay_learning_us}
            else mailbox=core.parse_json(r.data);wire=r.data;busy=false end
        end)
    end
    local function take()
        local r=mailbox;mailbox=nil;return r
    end
    local function packet(frames)
        local tick=math.floor(sim_us/250000)
        local objects={}
        if food and food:get_pos() then
            local delta=vector.subtract(food:get_pos(),npc:get_pos())
            objects={{id="local_food",kind="food",relative_position=delta,distance=vector.length(delta)}}
        end
        local p={observation_id=namespace .. ":obs:" .. seq .. ":" .. stage,tick=tick,agent_id=agent,
            observation={perception_rule="l10 finite local radius and fixed apparatus",
                visible_agents={},visible_objects=objects,visible_places={},visible_regions={},recent_events={},external_statements={}}}
        if frames then p.observation.sensory_extension={schema_version="rdl-sensory-extension-v1",run_id=run,world_epoch=1,
            agent_id=agent,delivery_observation_id=p.observation_id,delivery_world_tick=tick,delivery_time_us=sim_us,frames=frames} end
        return p
    end
    local function frame(channel,payload,partial,limited)
        local sensor=channel=="audition" and "ear" or "eye"
        return {frame_id=namespace .. ":" .. channel .. ":" .. seq,agent_id=agent,sensor_id=sensor,channel=channel,
            profile_id=profile.profile_id,profile_revision=profile.profile_revision,
            sensor_model_revision=channel=="vision_distant" and "sampled-surface-v0.2" or channel=="vision_local" and "legacy_radius_v1" or "direct_band_energy_v0",
            sample_seq=seq,clock_id="world-sim-v1",sampled_world_tick=math.floor(sim_us/250000),
            capture_window={kind=channel=="audition" and "interval" or "instant",start_us=channel=="audition" and sim_us-250000 or sim_us,end_us=sim_us},
            observer_frame_ref=namespace .. ":pose:" .. episode,status="SAMPLED",coverage=partial and "PARTIAL" or "COMPLETE_WITHIN_PLAN",
            output_limited=limited or false,payload=payload}
    end
    local function reset_episode()
        episode=episode+1;seq=seq+1;actions=0;attempted=false;acquired=false;deposited=false
        npc:set_pos(start);npc:set_yaw(0)
        npc:get_luaentity().rdl_held_food=false
        base:get_luaentity().rdl_food_stock=0
        if food and food:get_pos() then food:remove() end
        food=core.add_entity(food_pos,"rdl_bridge:food","local_food")
        local red=episode%2==1
        color=red and "muted_red" or "dark_gray"
        node_name=red and "rdl_bridge:distant_red" or "rdl_bridge:distant_dark"
        core.set_node(marker,{name=node_name})
        blocked=reverse and not red or not reverse and red
        if episode>=11 then blocked=not blocked end -- hidden changed-condition canary, never sent
        for y=1,2 do core.set_node({x=offset+2,y=y,z=0},{name=blocked and "rdl_bridge:opaque_wall" or "air"}) end
        op=namespace .. ":operation:" .. episode
        if episode<=6 then formation[#formation+1]=op elseif episode<=8 then validation[#validation+1]=op end
        current={episode_id=namespace .. ":episode:" .. episode,operation_id=op,color_band=color,
            hidden_blocked=blocked,start=vector.new(npc:get_pos()),started_us=sim_us,authority_consumptions=0,
            base_stock_before=base:get_luaentity().rdl_food_stock}
        local features,partial,limited=distant.sample(npc,profile.vision_distant,{{position=marker,node_name=node_name,color_band=color}})
        assert(not partial and #features==1,"L10 World visual acquisition incomplete")
        local f=frame("vision_distant",{features=features},partial,limited);frame_id=f.frame_id
        local factor=transmission.factor(npc:get_pos(),{x=offset+1,y=1,z=0})
        assert(factor)
        hearing:emit(agent,{occurred_us=sim_us-200000,duration_us=10000,cell_key="fixed",
            observer_frame_ref=namespace .. ":ear:" .. episode,azimuth_interval_deg={60,90},low=0,mid=0.12*factor,high=0})
        local closed=hearing:close(agent,sim_us-250000,profile.audition)
        local frames={frame("vision_local",{visible_count=1},false,false),f,
            frame("audition",{detections=closed.detections},closed.incomplete,closed.incomplete)}
        stage="observing";send("/v1/observe",packet(frames))
    end
    local function result()
        current.actions=actions;current.attempted=attempted;current.food_acquired=acquired
        current.deposited=deposited;current.finish=vector.new(npc:get_pos());current.decision=decision
        current.base_stock_after=base:get_luaentity().rdl_food_stock
        current.completed_us=sim_us
        records[#records+1]=current
        stage="result"
        local payload={operation_id=op,event_id=namespace .. ":event:" .. episode,completed_us=sim_us,attempted=attempted,food_acquired=acquired}
        if options.multi_agent then payload.agent_id=agent;payload.decision_id=decision.decision_id end
        if not attempted then payload.food_acquired=nil end
        -- core.write_json drops nil keys; result null is inserted explicitly by this bounded transport.
        if not attempted then
            busy=true
            local data=encode(payload):gsub('}$',',"food_acquired":null}')
            http.fetch({url=prefix .. "/v1/luanti-learning/result",method="POST",timeout=3,
                extra_headers={"Content-Type: application/json"},data=data},function(r)
                assert(r.succeeded and r.code==200,tostring(r.data));mailbox=core.parse_json(r.data);busy=false
            end)
        else send("/v1/luanti-learning/result",payload) end
    end
    core.register_on_mods_loaded(function()
      core.after(0,function()
        core.load_area({x=offset-2,y=-1,z=-2},{x=offset+6,y=3,z=16})
        for x=offset-2,offset+6 do for y=0,3 do for z=-2,16 do core.set_node({x=x,y=y,z=z},{name="air"}) end end end
        core.forceload_block(start,true);core.forceload_block(marker,true)
        npc=core.add_entity(start,"rdl_bridge:npc",agent)
        base=core.add_entity(start,"rdl_bridge:base","local_base")
        assert(npc and base);npc:set_properties({physical=false});base:set_properties({physical=false})
        stage="ready"
      end)
    end)
    core.register_globalstep(function(dt)
        if stage=="done" then return end
        sim_us=options.clock and options.clock() or sim_us+math.floor(dt*1000000+0.5)
        if held_reply and sim_us>=held_reply.release_us then
            mailbox=core.parse_json(held_reply.data);wire=held_reply.data;busy=false;held_reply=nil
            evidence.learning_hold_released_us=sim_us
        end
        if busy then return end -- clock progresses while HTTP is pending
        if stage=="ready" and sim_us>=250000 then reset_episode()
        elseif stage=="observing" and mailbox then
            local r=take();assert(r.sensory_receipt.accepted)
            decision_request_us=sim_us
            stage="deciding";send("/v1/luanti-learning/decide",{operation_id=op,episode_id=current.episode_id,
                run_id=run,world_epoch=1,agent_id=agent,frame_id=frame_id,now_us=sim_us})
        elseif stage=="deciding" and mailbox then
            current.decision_wire=wire
            decision=take();current.decision_received_us=sim_us
            if options.decisions then options.decisions[agent]=decision end
            -- Replay before any body effect; the response must identify the same operation/model.
            stage="decision_replay";send("/v1/luanti-learning/decide",{operation_id=op,episode_id=current.episode_id,
                run_id=run,world_epoch=1,agent_id=agent,frame_id=frame_id,now_us=decision_request_us})
        elseif stage=="decision_replay" and mailbox then
            local r=take();assert(r.operation_id==decision.operation_id and r.model_ref==decision.model_ref)
            assert(wire==current.decision_wire,"changed decision replay")
            local function consume(d)
                if d.agent_id~=agent or d.operation_id~=op or d.frame_id~=frame_id then return false end
                if options.multi_agent and d.decision_id~=decision.decision_id then return false end
                if executed[d.operation_id] then return false end
                assert(sim_us<=d.expires_us,"L10 action expired")
                executed[d.operation_id]=true -- consume before any body effect
                current.authority_consumptions=current.authority_consumptions+1
                return true
            end
            if options.decisions then
                for owner,foreign in pairs(options.decisions) do
                    if owner~=agent then
                        local before=vector.new(npc:get_pos())
                        assert(not consume(foreign));assert(vector.equals(before,npc:get_pos()))
                        current.foreign_response_rejected=true
                    end
                end
            end
            assert(consume(decision));assert(not consume(r))
            if decision.action=="defer" then result()
            else attempted=true;stage="walking" end
        elseif stage=="walking" then
            current.last_body_us=sim_us
            actions=actions+1
            local pos=npc:get_pos()
            local target=vector.add(pos,{x=1,y=0,z=0})
            if core.get_node(vector.round(target)).name~="air" then result()
            elseif vector.distance(pos,food_pos)<=1.25 then
                food:remove();food=nil;acquired=true;npc:get_luaentity().rdl_held_food=true;stage="returning"
            else npc:set_yaw(-math.pi/2);npc:set_pos(target) end
            assert(actions<=16,"L10 action budget")
        elseif stage=="returning" then
            current.last_body_us=sim_us
            actions=actions+1
            if vector.distance(npc:get_pos(),base:get_pos())<=1.25 then
                assert(npc:get_luaentity().rdl_held_food)
                npc:get_luaentity().rdl_held_food=false
                base:get_luaentity().rdl_food_stock=base:get_luaentity().rdl_food_stock+1
                deposited=true;result()
            else npc:set_pos(vector.add(npc:get_pos(),{x=-1,y=0,z=0})) end
        elseif stage=="result" and mailbox then
            current.receipt=take();stage="after";send("/v1/observe",packet(nil))
        elseif stage=="after" and mailbox then
            take()
            if episode==8 then stage="inspection";send("/v1/canonical-snapshot",nil)
            elseif episode==12 then
                stage="done";evidence.finished_us=sim_us
                if options.on_complete then options.on_complete(agent,evidence)
                else core.safe_file_write(core.get_worldpath() .. "/l10-evidence.json",encode(evidence)) end
                core.log("action","[RDL_LUANTI_L10] complete agent=" .. agent .. " episodes=12")
            else stage="ready" end
        elseif stage=="inspection" and mailbox then
            local snapshot=take();local assessment=nil
            for _,r in ipairs(snapshot.assessment.records) do
                if r.E.agent_id==agent and not r.reviewed and math.abs(r.E.deltas.visible_objects_count)>=1 then assessment=r end
            end
            assert(assessment,"L10 requires independent canonical count comparison")
            evidence.assessment_id=assessment.assessment_id
            local dimensions={}
            for k,v in pairs(assessment.E.deltas) do dimensions[k]=v==0 and {status="zero"} or {status="unresolved",residual=1} end
            stage="reviewed";send("/v1/assessment-review",{assessment_id=assessment.assessment_id,expected_revision=assessment.revision,
                reviewer="l10-explicit-fixture",basis="explicit independent finite count review; not prediction loss or Candidate support",
                evidence=run,dimensions=dimensions})
        elseif stage=="reviewed" and mailbox then
            take();stage="learning";send("/v1/luanti-learning/learn",{learning_id=namespace .. ":learning",agent_id=agent,
                formation_operations=formation,validation_operations=validation,assessment_id=evidence.assessment_id,activate=activate})
        elseif stage=="learning" and mailbox then evidence.learning=take();stage="ready" end
    end)
end
