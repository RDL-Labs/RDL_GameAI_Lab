-- OBS-9 finite full-sensory integration over the RW2 resolver; callbacks never act.
return function(http, runtime_url, profiles, life_state, agents, ensure, find, build, resolve)
    local root=core.get_modpath("rdl_bridge")
    local controller_module=dofile(root .. "/continuous_visual_controller.lua")
    local arbiter_module=dofile(root .. "/probe_arbiter.lua")
    local checks=dofile(root .. "/probe_arbiter_checks.lua")(arbiter_module,controller_module)

    local v1_checks=dofile(root .. "/observation_v1_checks.lua")(arbiter_module,controller_module,profiles)
    local run=assert(core.settings:get("rdl_probe_run_id"))
    local scenario=core.settings:get("rdl_probe_scenario") or "normal"
    local probe_id=scenario=="swap" and "npc_b" or "npc_a"
    local other_id=probe_id=="npc_a" and "npc_b" or "npc_a"
    local targets={npc_a={{position={x=12,y=1,z=17},node_name="rdl_bridge:distant_red",color_band="muted_red"}},
                   npc_b={{position={x=12,y=1,z=23},node_name="rdl_bridge:distant_red",color_band="muted_red"}}}
    local sampler=dofile(root .. "/observation_v1_sampler.lua").new(run,profiles,find,build,agents,targets)
    local peaks={npc_a=0,npc_b=0}
    local deferred,rejected=false,false
    local sim_us, drain_us, last_tick, initialized, done=0,0,-1,false,false
    local arbiters,controllers,poses,frames={},{},{},{}
    local samples,actions,events={},{},{}
    local entry,request,source,start_yaw,start_position,acquisition_pose
    local dropped,delayed=false,false
    local old_response,old_replayed=nil,false
    local held_life,life_replanned=false,false
    local function wrap(x) return (x+180)%360-180 end
    local function relative(a,b) return wrap(math.deg(a-b)) end
    for _,id in ipairs({"npc_a","npc_b"}) do
        controllers[id]=controller_module.new(run,1,id,"obs9-v1")
        arbiters[id]=arbiter_module.new(run,1,id,controllers[id],64);arbiters[id].idle=id==probe_id
        poses[id]={};frames[id]={}
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
        local npc=find("rdl_bridge:npc",probe_id);local p=poses[probe_id][source.frame_id]
        return {now_us=sim_us,life_busy=false,mapping_valid=true,mapping_expires_us=source.capture_window.start_us+2000000,
                source_pose=source.observer_frame_ref,pose_ref=request.operation_id .. ":start",clock_id="world-sim-v1",
                source_to_start_deg=relative(p.yaw,npc:get_yaw()),measured_right_deg=relative(start_yaw or npc:get_yaw(),npc:get_yaw()),
                translation=vector.distance(p.position,npc:get_pos()),tilt_deg=math.deg(math.max(math.abs(npc:get_rotation().x),math.abs(npc:get_rotation().z))),
                profile_id=profiles[probe_id].profile_id,profile_revision=1}
    end
    local function acquire(id,tick)
        local npc=find("rdl_bridge:npc",id)
        local f=sampler.distant_frame(id,tick,sim_us)
        poses[id][f.frame_id]={yaw=npc:get_yaw(),position=npc:get_pos()};frames[id][#frames[id]+1]=f
        samples[#samples+1]={agent_id=id,tick=tick,time_us=sim_us,frame_id=f.frame_id}
        return f
    end
    local function enqueue(id,f,reserved)
        if f then assert(arbiters[id].enqueue(f,reserved),"unexpected_capacity_loss") end
        peaks[id]=math.max(peaks[id],#arbiters[id].pending+arbiters[id].reserved)
    end
    local function transmit(id,tick,draining)
        local a,c=arbiters[id],agents[id]
        if scenario=="faults" and id==probe_id and not deferred then
            deferred=true;events[#events+1]={kind="send_deferred",time_us=sim_us};return
        end
        if c.result_in_flight then return end
        local life=a.intent and not c.deposited and not draining
        if not life and #a.pending==0 then return end
        local delivery=run .. ":" .. id .. ":delivery:" .. (a.transfer_count+1)
        local t=a.begin(delivery,sim_us,life);if not t then return end
        -- One real life action can move the body before target-frame delivery.
        if id==probe_id and scenario=="delayed" and entry and entry.frame and not c.first_action_after_probe then t.frames={};t.ids={};t.frame_order={} end
        if (scenario=="same_slot" or scenario=="faults") and id==probe_id and life and old_response and not old_replayed then
            old_replayed=true
            local before={};for _,f in ipairs(a.pending) do before[#before+1]=f.frame_id end
            a.submit(old_response.transfer.id,old_response.response,sim_us,sim_us)
            local obsolete=a.consume(sim_us);assert(not a.authorized(obsolete))
            assert(a.in_flight==delivery and #a.pending==#before)
            for i,f in ipairs(a.pending) do assert(f.frame_id==before[i]) end
            events[#events+1]={kind="old_callback_after_new_request",time_us=sim_us,old_id=obsolete.transfer.id,new_id=delivery,retained=before}
        end
        local packet=table.copy(sampler.packets[id]);packet.observation_id=delivery;packet.tick=tick
        if #t.frames>0 then
            packet.observation.sensory_extension={schema_version="rdl-sensory-extension-v1",run_id=run,world_epoch=1,agent_id=id,
                delivery_observation_id=delivery,delivery_world_tick=tick,delivery_time_us=sim_us,frames=t.frames}
        end
        if scenario=="faults" and id==other_id and not rejected and #t.frames>0 then
            packet.observation.sensory_extension.schema_version="intentional-invalid-schema"
            rejected=true;events[#events+1]={kind="sensory_rejection_sent",delivery_id=delivery,time_us=sim_us}
        end
        local data=core.write_json(packet)
        if not packet.observation.life_context.god_statue_cue then
            data=data:gsub('("life_context"%s*:%s*{)','%1"god_statue_cue":null,',1)
        end
        for _,key in ipairs({"visible_agents","visible_objects","visible_places","visible_regions","recent_events","external_statements","features","detections","held_food_ids","interrupt_candidates"}) do
            data=data:gsub('("' .. key .. '"%s*:%s*)null','%1[]')
        end
        data=data:gsub('("last_rescue_delivery"%s*:%s*)null','%1{}')
        http.fetch({url=runtime_url,method="POST",timeout=3,extra_headers={"Content-Type: application/json"},data=data},function(r)
            local response=r.succeeded and r.code==200 and core.parse_json(r.data) or nil
            assert(response,"OBS9 HTTP failure: " .. tostring(r.data))
            local delay=0
            if (scenario=="same_slot" or scenario=="faults") and id==other_id and life and not held_life then delay=1100000;held_life=true end
            if id==probe_id and not delayed and scenario=="delayed" and entry and entry.frame and t.ids[entry.frame.frame_id] then delay=1100000;delayed=true end
            if id==probe_id and not dropped and scenario=="faults" and entry and entry.frame and t.ids[entry.frame.frame_id] then
                assert(response.sensory_receipt.accepted and response.sensory_receipt.new_frames>0)
                local ids={};for _,f in ipairs(t.frames) do ids[#ids+1]=f.frame_id end
                local pending={};for _,f in ipairs(a.pending) do pending[#pending+1]=f.frame_id end
                events[#events+1]={kind="response_lost",time_us=sim_us,delivery_id=delivery,frame_ids=ids,pending=pending,receipt=response.sensory_receipt}
                a.lose_response(delivery);response=nil;dropped=true;delay=1100000
            end
            if response and response.sensory_receipt and response.sensory_receipt.accepted==false then
                events[#events+1]={kind="sensory_rejected",delivery_id=delivery,time_us=sim_us,receipt=response.sensory_receipt}
            end
            a.submit(delivery,response,sim_us,sim_us+delay)
        end)
    end
    local function evidence()
        local e={operation_id=request.operation_id,run_id=run,world_epoch=1,agent_id=probe_id,operation_status=entry.operation_status,
            reasons=entry.reasons,rotations=entry.rotations,samples=entry.samples,generation=entry.generation,
            final_translation=vector.distance(start_position or poses[probe_id][source.frame_id].position,find("rdl_bridge:npc",probe_id):get_pos())}
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
            sampler.sound({x=0,y=1,z=0},0,0.12)
            initialized=true
        end
        local previous_us=sim_us
        sim_us=sim_us+math.floor(dt*1000000+0.5)
        local tick=math.floor(sim_us/250000);life_state.tick=tick
        for slot=(math.floor(last_tick/4)+1)*4,math.min(tick-1,20),4 do
            if slot>=0 then events[#events+1]={kind="missed_slot",channel="vision_distant",tick=slot,time_us=sim_us} end
        end
        for missed=math.max(0,last_tick+1),math.min(tick-1,23) do
            events[#events+1]={kind="missed_slot",channel="vision_local",tick=missed,time_us=sim_us}
        end
        sampler.close(sim_us,enqueue,previous_us)
        local ending=sim_us>=6000000
        if ending and not arbiters[probe_id].stopped then
            for _,a in pairs(arbiters) do a.stop(sim_us) end
            events[#events+1]={kind="run_end",time_us=sim_us}
        end
        local responses={}
        for id,a in pairs(arbiters) do
            a.result_waiting=agents[id].result_in_flight
            responses[id]=a.consume(sim_us)
            if id==probe_id and responses[id] and responses[id].response and not old_response then old_response=responses[id] end
        end
        if not ending then
            arbiters[other_id].life_intent(sim_us)
            if (scenario=="same_slot" or scenario=="faults") and not life_replanned and sim_us>=600000 then
                life_replanned=true;arbiters[other_id].invalidate("life_replanned",sim_us)
                events[#events+1]={kind="life_generation_changed",time_us=sim_us,agent_id="npc_b"}
            end
            local onset=scenario=="preempt" and 700000 or scenario=="same_slot" and 1000000 or 1200000
            if sim_us>=onset then arbiters[probe_id].life_intent(sim_us) end
            if not source and frames[probe_id][1] and arbiters[probe_id].admitted[frames[probe_id][1].frame_id] then source=frames[probe_id][1] end
            if source and not entry then
                request={operation_id=run .. ":probe",run_id=run,world_epoch=1,agent_id=probe_id,purpose="visual_reacquisition_after_yaw",rule_version="obs9-v1",
                         source_frame_id=source.frame_id,feature_id=source.payload.features[1].feature_id,color_band=source.payload.features[1].color_band}
                local npc=find("rdl_bridge:npc",probe_id);start_yaw=npc:get_yaw();start_position=npc:get_pos()
                entry=arbiters[probe_id].start(request,source,body())
                peaks[probe_id]=math.max(peaks[probe_id],#arbiters[probe_id].pending+arbiters[probe_id].reserved)
                if entry.operation_status=="validated" then
                    controllers[probe_id].rotate(entry,body(),function(deg) npc:set_yaw(start_yaw-math.rad(deg)) end,function() return relative(start_yaw,npc:get_yaw()) end)
                    if scenario=="removed" then core.set_node(targets[probe_id][1].position,{name="rdl_bridge:observation_space"}) end
                    if scenario=="partial" then
                        for _,x in ipairs({2,5,8,15,18}) do
                            local p={x=x,y=1,z=targets[probe_id][1].position.z}
                            core.set_node(p,{name="rdl_bridge:distant_red"})
                            targets[probe_id][#targets[probe_id]+1]={position=p,node_name="rdl_bridge:distant_red",color_band="muted_red"}
                        end
                    end
                end
            end
            for id,result in pairs(responses) do
                if arbiters[id].authorized(result) then
                    resolve(id,agents[id],result.response)
                    sampler.sound(find("rdl_bridge:npc",id):get_pos(),sim_us,1,id)
                    actions[#actions+1]={agent_id=id,time_us=sim_us,delivery_id=result.transfer.id,generation=arbiters[id].generation,action=result.response.action.type}
                    if id==probe_id and entry and entry.frame then agents[id].first_action_after_probe=true end
                end
            end
            if entry and entry.operation_status=="rotated" then
                local c=controllers[probe_id]
                if not c.guard(entry,body()) or tick>entry.next_sample_tick then
                    if entry.operation_status=="rotated" then c.abort(entry,"missed_acquisition_slot") end
                    arbiters[probe_id].active=nil;arbiters[probe_id].reserved=0
                end
            end
            if tick~=last_tick then
                for id,a in pairs(arbiters) do
                    enqueue(id,sampler.local_frame(id,tick,sim_us))
                    if a.slot(tick) then
                        local f,linked
                        if id==probe_id and entry and entry.operation_status=="rotated" then
                            f=controllers[probe_id].sample(entry,tick,body(),function() acquisition_pose=body();return acquire(id,tick) end)
                            linked=f~=nil
                            if linked then a.active=nil end
                        end
                        if not f then f=acquire(id,tick) end
                        enqueue(id,f,linked)
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
                local repeat_entry,fresh=arbiters[probe_id].start(request,source,body());assert(repeat_entry==entry and not fresh)
                local output={run_id=run,scenario=scenario,probe_agent=probe_id,profiles=profiles,queue_peaks=peaks,acquired_frames=sampler.frames,all_samples=sampler.samples,arbiter_checks=checks,v1_checks=v1_checks,request=request,evidence=evidence(),samples=samples,actions=actions,events=events,
                    agents={},traces={},end_us=sim_us}
                for id,a in pairs(arbiters) do output.agents[id]={picked_up=agents[id].picked_up,deposited=agents[id].deposited,result_accepted=agents[id].result_accepted,pending=#a.pending,reserved=a.reserved,transfers=a.transfer_count};output.traces[id]=a.log end
                local json=core.write_json(output)
                for _,key in ipairs({"features","detections"}) do json=json:gsub('("' .. key .. '"%s*:%s*)null','%1[]') end
                core.safe_file_write(core.get_worldpath() .. "/obs9-evidence.json",json)
                core.log("action","[RDL_LUANTI_OBS9] complete scenario=" .. scenario);done=true
            elseif drain_us>5000000 then error("OBS9 drain timeout") end
        end
    end)
end
