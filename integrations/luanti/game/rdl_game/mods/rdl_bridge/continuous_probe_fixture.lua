-- OBS-8B opt-in scheduler over the existing RW2 action resolver.
return function(http, runtime_url, profiles, life_state, agents, ensure, find, build, resolve)
    local root=core.get_modpath("rdl_bridge")
    local controller_module=dofile(root .. "/continuous_visual_controller.lua")
    local arbiter_module=dofile(root .. "/probe_arbiter.lua")
    local checks=dofile(root .. "/probe_arbiter_checks.lua")(arbiter_module,controller_module)
    local sensor=dofile(root .. "/distant_sensor.lua")
    local run=assert(core.settings:get("rdl_probe_run_id"))
    local scenario=core.settings:get("rdl_probe_scenario") or "delayed"
    local sim_us, drain_us, last_tick, initialized, done=0,0,-1,false,false
    local arbiters,controllers,poses,frames,sequences={},{},{},{},{}
    local samples,actions,operations,events={},{},{},{}
    local entry,request,source,start_yaw,start_position,acquisition_pose
    local dropped,delayed,jumped=false,false,false
    local old_response,old_replayed=nil,false
    local held_life,life_replanned=false,false
    local function wrap(x) return (x+180)%360-180 end
    local function relative(a,b) return wrap(math.deg(a-b)) end
    for _,id in ipairs({"npc_a","npc_b"}) do
        controllers[id]=controller_module.new(run,1,id)
        arbiters[id]=arbiter_module.new(run,1,id,controllers[id]);arbiters[id].idle=id=="npc_a"
        poses[id]={};sequences[id]=0;frames[id]={}
    end
    local function setup()
        local vm=VoxelManip();local lo,hi=vm:read_from_map({x=-2,y=0,z=-5},{x=22,y=3,z=26})
        local area=VoxelArea:new({MinEdge=lo,MaxEdge=hi});local data=vm:get_data()
        local open=core.get_content_id("rdl_bridge:observation_space")
        for x=-2,22 do for y=0,3 do for z=-5,26 do data[area:index(x,y,z)]=open end end end
        vm:set_data(data);vm:write_to_map();vm:update_map()
        for _,z in ipairs({17,23}) do core.set_node({x=12,y=1,z=z},{name="rdl_bridge:distant_red"}) end
    end
    local function body()
        local npc=find("rdl_bridge:npc","npc_a");local p=poses.npc_a[source.frame_id]
        return {now_us=sim_us,life_busy=false,mapping_valid=true,mapping_expires_us=source.capture_window.start_us+2000000,
                source_pose=source.observer_frame_ref,pose_ref=request.operation_id .. ":start",clock_id="world-sim-v1",
                source_to_start_deg=relative(p.yaw,npc:get_yaw()),measured_right_deg=relative(start_yaw or npc:get_yaw(),npc:get_yaw()),
                translation=vector.distance(p.position,npc:get_pos()),tilt_deg=math.deg(math.max(math.abs(npc:get_rotation().x),math.abs(npc:get_rotation().z))),
                profile_id=profiles.npc_a.profile_id,profile_revision=1}
    end
    local function acquire(id,tick)
        local npc=find("rdl_bridge:npc",id)
        local values,partial,limited=sensor.sample(npc,profiles[id].vision_distant,{{position={x=12,y=1,z=id=="npc_a" and 17 or 23},node_name="rdl_bridge:distant_red",color_band="muted_red"}})
        sequences[id]=sequences[id]+1
        local f={frame_id=run .. ":" .. id .. ":" .. sequences[id],agent_id=id,sensor_id="eye",channel="vision_distant",
            profile_id=profiles[id].profile_id,profile_revision=1,sensor_model_revision="sampled-surface-v0.2",sample_seq=sequences[id],clock_id="world-sim-v1",
            sampled_world_tick=tick,capture_window={kind="instant",start_us=sim_us,end_us=sim_us},observer_frame_ref=run .. ":" .. id .. ":pose:" .. sequences[id],
            status="SAMPLED",coverage=partial and "PARTIAL" or "COMPLETE_WITHIN_PLAN",output_limited=limited,payload={features=values}}
        poses[id][f.frame_id]={yaw=npc:get_yaw(),position=npc:get_pos()};frames[id][#frames[id]+1]=f
        samples[#samples+1]={agent_id=id,tick=tick,time_us=sim_us,frame_id=f.frame_id}
        return f
    end
    local function transmit(id,tick,draining)
        local a,c=arbiters[id],agents[id]
        if c.result_in_flight then return end
        local life=a.intent and not c.deposited and not draining
        if not life and #a.pending==0 then return end
        local delivery=run .. ":" .. id .. ":delivery:" .. (a.transfer_count+1)
        local t=a.begin(delivery,sim_us,life);if not t then return end
        -- One real life action can move the body before target-frame delivery.
        if id=="npc_a" and scenario=="delayed" and entry and entry.frame and not c.first_action_after_probe then t.frames={};t.ids={} end
        if scenario=="same_slot" and id=="npc_a" and life and old_response and not old_replayed then
            old_replayed=true
            local before={};for _,f in ipairs(a.pending) do before[#before+1]=f.frame_id end
            a.submit(old_response.transfer.id,old_response.response,sim_us,sim_us)
            local obsolete=a.consume(sim_us);assert(not a.authorized(obsolete))
            assert(a.in_flight==delivery and #a.pending==#before)
            for i,f in ipairs(a.pending) do assert(f.frame_id==before[i]) end
            events[#events+1]={kind="old_callback_after_new_request",time_us=sim_us,old_id=obsolete.transfer.id,new_id=delivery,retained=before}
        end
        local packet=build(id,c);packet.observation_id=delivery;packet.tick=tick
        if #t.frames>0 then
            packet.observation.sensory_extension={schema_version="rdl-sensory-extension-v1",run_id=run,world_epoch=1,agent_id=id,
                delivery_observation_id=delivery,delivery_world_tick=tick,delivery_time_us=sim_us,frames=t.frames}
        end
        local data=core.write_json(packet)
        if not packet.observation.life_context.god_statue_cue then
            data=data:gsub('("life_context"%s*:%s*{)','%1"god_statue_cue":null,',1)
        end
        for _,key in ipairs({"visible_agents","visible_objects","visible_places","visible_regions","recent_events","external_statements","features","held_food_ids","interrupt_candidates"}) do
            data=data:gsub('("' .. key .. '"%s*:%s*)null','%1[]')
        end
        data=data:gsub('("last_rescue_delivery"%s*:%s*)null','%1{}')
        http.fetch({url=runtime_url,method="POST",timeout=3,extra_headers={"Content-Type: application/json"},data=data},function(r)
            local response=r.succeeded and r.code==200 and core.parse_json(r.data) or nil
            assert(response,"OBS8B HTTP failure: " .. tostring(r.data))
            local delay=0
            if scenario=="same_slot" and id=="npc_b" and life and not held_life then delay=1100000;held_life=true end
            if id=="npc_a" and not delayed and scenario=="stale" then delay=2100000;delayed=true end
            if id=="npc_a" and not delayed and scenario=="delayed" and entry and entry.frame and t.ids[entry.frame.frame_id] then delay=1100000;delayed=true end
            if id=="npc_a" and not dropped and scenario=="loss" and entry and entry.frame and t.ids[entry.frame.frame_id] then
                response=nil;dropped=true;events[#events+1]={kind="response_lost",time_us=sim_us,delivery_id=delivery}
            end
            a.submit(delivery,response,sim_us,sim_us+delay)
        end)
    end
    local function evidence()
        local e={operation_id=request.operation_id,run_id=run,world_epoch=1,agent_id="npc_a",operation_status=entry.operation_status,
            reasons=entry.reasons,rotations=entry.rotations,samples=entry.samples,generation=entry.generation,
            final_translation=vector.distance(start_position or poses.npc_a[source.frame_id].position,find("rdl_bridge:npc","npc_a"):get_pos())}
        if entry.plan then e.started_us=entry.plan.started_us;e.command_deg=entry.plan.command_deg;e.rotation_completed_us=entry.rotation_completed_us end
        if entry.frame then
            e.new_frame_id=entry.frame.frame_id;e.sample_tick=entry.sample_tick
            e.pose={issuer="luanti-body-yaw-v1",evidence_id=request.operation_id .. ":body",valid=true,source_ref=source.observer_frame_ref,
                start_ref=entry.plan.start_pose,target_ref=entry.frame.observer_frame_ref,source_us=source.capture_window.start_us,start_us=entry.plan.started_us,
                target_us=entry.frame.capture_window.start_us,expires_us=source.capture_window.start_us+2000000,clock_id="world-sim-v1",
                source_to_start_deg=entry.plan.source_to_start_deg,start_to_target_deg=acquisition_pose.measured_right_deg,error_deg=0.001,
                translation=acquisition_pose.translation,tilt_deg=acquisition_pose.tilt_deg}
        end
        return e
    end
    local world_ready=false
    core.register_globalstep(function(dt)
        if done then return end
        if not initialized then
            if not world_ready then setup();world_ready=true end
            ensure();if not life_state.ready then return end
            for id in pairs(agents) do local npc=find("rdl_bridge:npc",id);npc:set_properties({physical=false});npc:set_yaw(0) end
            initialized=true
        end
        sim_us=sim_us+math.floor(dt*1000000+0.5)
        if scenario=="jump" and not jumped and sim_us>=700000 then sim_us=sim_us+650000;jumped=true;events[#events+1]={kind="dtime_jump",time_us=sim_us} end
        local tick=math.floor(sim_us/250000);life_state.tick=tick
        for slot=(math.floor(last_tick/4)+1)*4,math.min(tick-1,20),4 do
            if slot>=0 then events[#events+1]={kind="missed_slot",tick=slot,time_us=sim_us} end
        end
        local ending=sim_us>=6000000
        if ending and not arbiters.npc_a.stopped then
            for _,a in pairs(arbiters) do a.stop(sim_us) end
            events[#events+1]={kind="run_end",time_us=sim_us}
        end
        local responses={}
        for id,a in pairs(arbiters) do
            a.result_waiting=agents[id].result_in_flight
            responses[id]=a.consume(sim_us)
            if id=="npc_a" and responses[id] and responses[id].response and not old_response then old_response=responses[id] end
        end
        if not ending then
            arbiters.npc_b.life_intent(sim_us)
            if scenario=="same_slot" and not life_replanned and sim_us>=600000 then
                life_replanned=true;arbiters.npc_b.invalidate("life_replanned",sim_us)
                events[#events+1]={kind="life_generation_changed",time_us=sim_us,agent_id="npc_b"}
            end
            local onset=scenario=="preempt" and 700000 or scenario=="same_slot" and 1000000 or scenario=="stale" and 2500000 or scenario=="jump" and 2000000 or 1200000
            if sim_us>=onset then arbiters.npc_a.life_intent(sim_us) end
            if not source and frames.npc_a[1] and arbiters.npc_a.admitted[frames.npc_a[1].frame_id] then source=frames.npc_a[1] end
            if source and not entry then
                request={operation_id=run .. ":probe",run_id=run,world_epoch=1,agent_id="npc_a",purpose="visual_reacquisition_after_yaw",rule_version="obs8b-v1",
                         source_frame_id=source.frame_id,feature_id=source.payload.features[1].feature_id,color_band=source.payload.features[1].color_band}
                local npc=find("rdl_bridge:npc","npc_a");start_yaw=npc:get_yaw();start_position=npc:get_pos()
                entry=arbiters.npc_a.start(request,source,body())
                if entry.operation_status=="validated" then controllers.npc_a.rotate(entry,body(),function(deg) npc:set_yaw(start_yaw-math.rad(deg)) end,function() return relative(start_yaw,npc:get_yaw()) end) end
            end
            for id,result in pairs(responses) do
                if arbiters[id].authorized(result) then
                    resolve(id,agents[id],result.response)
                    actions[#actions+1]={agent_id=id,time_us=sim_us,delivery_id=result.transfer.id,generation=arbiters[id].generation,action=result.response.action.type}
                    if id=="npc_a" and entry and entry.frame then agents[id].first_action_after_probe=true end
                end
            end
            if entry and entry.operation_status=="rotated" then
                local c=controllers.npc_a
                if not c.guard(entry,body()) or tick>entry.next_sample_tick then
                    if entry.operation_status=="rotated" then c.abort(entry,"missed_acquisition_slot") end
                    arbiters.npc_a.active=nil;arbiters.npc_a.reserved=0
                end
            end
            if tick~=last_tick then
                for id,a in pairs(arbiters) do
                    if a.slot(tick) then
                        local f,linked
                        if id=="npc_a" and entry and entry.operation_status=="rotated" then
                            f=controllers.npc_a.sample(entry,tick,body(),function() acquisition_pose=body();return acquire(id,tick) end)
                            linked=f~=nil
                            if linked then a.active=nil end
                        end
                        if not f then f=acquire(id,tick) end
                        a.enqueue(f,linked)
                    end
                end
            end
        end
        if tick~=last_tick or ending then
            for id in pairs(agents) do transmit(id,tick,ending) end
        end
        last_tick=tick
        if ending then
            drain_us=drain_us+math.floor(dt*1000000+0.5)
            local clear=true
            for id,a in pairs(arbiters) do if a.in_flight or a.mailbox or #a.pending>0 or agents[id].result_in_flight then clear=false end end
            if clear then
                assert(entry,"Probe was never requested")
                local repeat_entry,fresh=arbiters.npc_a.start(request,source,body());assert(repeat_entry==entry and not fresh)
                local output={run_id=run,scenario=scenario,arbiter_checks=checks,request=request,evidence=evidence(),samples=samples,actions=actions,events=events,
                    agents={},traces={},end_us=sim_us}
                for id,a in pairs(arbiters) do output.agents[id]={picked_up=agents[id].picked_up,deposited=agents[id].deposited,result_accepted=agents[id].result_accepted,pending=#a.pending};output.traces[id]=a.log end
                core.safe_file_write(core.get_worldpath() .. "/obs8b-evidence.json",core.write_json(output))
                core.log("action","[RDL_LUANTI_OBS8B] complete scenario=" .. scenario);done=true
            elseif drain_us>5000000 then error("OBS8B drain timeout") end
        end
    end)
end
