-- L14B: one continuous World, shared private stock, three separate consumers.
return function(http,runtime_url)
    local root=core.get_modpath("rdl_bridge")
    local natural=dofile(root .. "/exploration_natural.lua");natural.register()
    local landmarks=dofile(root .. "/exploration_landmarks.lua")
    local resource=dofile(root .. "/resource_patches.lua");resource.register(natural,landmarks)
    local distant=dofile(root .. "/distant_sensor.lua")
    local controller=dofile(root .. "/exploration_controller.lua")
    local terrain_enabled=core.settings:get_bool("rdl_movement_terrain",false)
    local steering_enabled=core.settings:get_bool("rdl_movement_steering",false)
    local rest_mode=core.settings:get("rdl_rest_mode") or "off"
    local reassessment_mode=core.settings:get("rdl_reassessment_mode") or "off"
    local obstacle_probe=core.settings:get("rdl_obstacle_probe") or "off"
    local reversal_review=core.settings:get("rdl_reversal_review_mode") or "off"
    local day_cycle=core.settings:get_bool("rdl_day_cycle",false)
    local return_campaign=core.settings:get_bool("rdl_return_campaign",false)
    assert(not return_campaign or day_cycle,"campaign needs days")
    local skyline=day_cycle and dofile(root .. "/elevated_landmarks.lua") or nil
    if day_cycle then
        core.register_node("rdl_bridge:exploration_tower",{description="Ochre stone tower",
            tiles={"rdl_l13_gray.png^[colorize:#d9a329:210"},walkable=true,pointable=false})
        natural.register_surface("tower","gray");landmarks.register_surface("tower","gray")
    end
    local probe_nodes=nil
    local reactivation_mode=core.settings:get("rdl_reactivation_mode") or "off"
    assert(reactivation_mode=="off" or rest_mode~="off","reactivation requires rest")
    assert(obstacle_probe=="off" or ((obstacle_probe=="persistent" or obstacle_probe=="removed") and reactivation_mode~="off"),"invalid obstacle probe")
    assert(rest_mode=="off" or steering_enabled,"rest requires steering")
    assert(not steering_enabled or terrain_enabled,"steering requires terrain")
    local lateral_assignment=core.settings:get("rdl_lateral_assignment") or "off"
    local tie_break_mode=core.settings:get("rdl_tie_break_mode") or "off"
    assert(tie_break_mode=="off" or ((tie_break_mode=="disabled" or tie_break_mode=="frozen") and
        terrain_enabled and not steering_enabled and lateral_assignment=="off"),"tie break only mode")
    local lateral_profiles={neutral={"neutral","neutral","neutral"},mixed={"left","neutral","right"},
        swapped={"right","neutral","left"},left={"left","left","left"},right={"right","right","right"}}
    assert(lateral_assignment=="off" or (lateral_profiles[lateral_assignment] and terrain_enabled and not steering_enabled),"lateral bias only mode")
    local surface=terrain_enabled and dofile(root .. "/movement_surface.lua") or nil
    local run=assert(core.settings:get("rdl_learning_run_id"))
    local periods=assert(tonumber(core.settings:get("rdl_resource_periods")))
    local assignment=core.settings:get("rdl_resource_assignment") or "mixed"
    local scenario=core.settings:get("rdl_exploration_scenario") or "natural_woodland"
    local control=core.settings:get_bool("rdl_resource_control",false)
    local faults=core.settings:get_bool("rdl_resource_faults",false)
    assert(periods>=1 and periods<=30 and periods%1==0)
    local speed=tonumber(core.settings:get("rdl_simulation_speed") or "1")
    assert(speed and speed>=1 and speed<=16,"invalid simulation speed")
    local wall_start=core.get_us_time()
    local task_seconds=tonumber(core.settings:get("rdl_task_seconds") or "0")
    assert(task_seconds==0 or ((task_seconds==16 or task_seconds==32 or task_seconds==64) and periods==1 and reassessment_mode~="off"),"invalid task deadline")
    assert(reversal_review=="off" or ((reversal_review=="disabled" or reversal_review=="enabled") and task_seconds~=0),"invalid reversal review")
    assert(not day_cycle or (periods<=(return_campaign and 30 or 3) and steering_enabled and rest_mode=="off" and reassessment_mode=="off" and task_seconds==0
        and lateral_assignment=="off" and tie_break_mode=="off" and reversal_review=="off"),"isolated day cycle")
    local period_us=(day_cycle and 64 or (task_seconds==0 and 16 or task_seconds))*1000000
    local slots_per_period=period_us/250000
    local capacity,limit=periods*slots_per_period,periods*period_us
    local prefix=runtime_url:gsub("/v1/observe$","") .. "/v1/exploration/"
    local profile={range_min_exclusive=12,range_max_inclusive=64,horizontal_fov_deg=90,vertical_fov_deg=60,angle_bin_deg=5}
    for _,spec in ipairs({{"rock_gray","gray"},{"rock_red","red"}}) do
        core.register_node("rdl_bridge:exploration_" .. spec[1],{description="L14B mountain",
            tiles={"rdl_l13_" .. spec[1] .. ".png"},walkable=true,pointable=false})
    end
    local sim,stage,last_slot=0,"setup",-1
    local agents,patches,targets={},{},{}
    local return_events,returned,checked_nights={},{},{}
    local stop_requested,stop_started=false,nil
    local evidence={run_id=run,scenario=scenario,assignment=assignment,period_count=periods,
        control=control,faults=faults,agents={},deliveries={},stock_events={},periods={},guards={}}
    if return_campaign then evidence.return_campaign={target=3,events=return_events} end
    if task_seconds~=0 then evidence.task_seconds=task_seconds end
    evidence.timing={requested_speed=speed,max_step_us=0}
    evidence.obstacle_probe={mode=obstacle_probe,events={}}
    if surface then evidence.surface_checks=dofile(root .. "/movement_surface_checks.lua")(surface) end
    local function encode(x)
        return (core.write_json(x):gsub('"visible":null','"visible":[]'):gsub('"features":null','"features":[]')
            :gsub('"items":null','"items":[]'):gsub('"__l15a_missing_height__"','null'))
    end
    local function save(failure)
        evidence.failure=failure;evidence.finished_us=sim
        evidence.timing.wall_elapsed_us=core.get_us_time()-wall_start
        local ok,stock=pcall(resource.audit,patches)
        if ok then evidence.final_stock=stock else evidence.stock_audit_failure=tostring(stock) end
        for _,a in ipairs(agents) do
            a.e.final_body=a.body();a.e.inventory=table.copy(a.inventory)
            a.e.controller={count=a.ctl.count,effects=a.ctl.effects,distance=a.ctl.distance,rotation=a.ctl.rotation}
        end
        core.safe_file_write(core.get_worldpath() .. "/l14b-evidence.json",encode(evidence));stage="done"
    end
    local function enqueue(a,kind,payload,first)
        local job={kind=kind,payload=table.copy(payload)}
        if first then table.insert(a.queue,1,job) else a.queue[#a.queue+1]=job end
        a.e.max_pending=math.max(a.e.max_pending or 0,#a.queue+(a.busy and 1 or 0))
        assert(#a.queue+(a.busy and 1 or 0)<=8,"per-agent pending capacity")
    end
    local function context(a,x) x.run_id=run;x.world_epoch=1;x.agent_id=a.id;return x end
    local function make_agent(index,id,trait)
        local x=({0,-2,2})[index]
        local a={id=id,trait=trait,queue={},inventory={},revision=0,configured=false,done=false}
        a.e={agent_id=id,profile=trait,observations={},actions={},terrain_moves={}}
        evidence.agents[id]=a.e
        a.npc=assert(core.add_entity({x=x,y=natural.height(x,0)+1,z=0},"rdl_bridge:npc",id))
        a.npc:set_properties({physical=false,nametag=id .. " / " .. trait,textures={"rdl_l13_agent.png"}})
        a.npc:set_yaw(0)
        a.last_position=vector.new(a.npc:get_pos());a.last_yaw=a.npc:get_yaw()
        function a.body()
            local pos,yaw=a.npc:get_pos(),a.npc:get_yaw()
            assert(pos,"agent body lost")
            if vector.distance(pos,a.last_position)>0.00001 or math.abs(yaw-a.last_yaw)>0.00001 then
                a.revision=a.revision+1;a.last_position=vector.new(pos);a.last_yaw=yaw
            end
            return {position=pos,yaw=yaw,revision=a.revision,pose_ref=run .. ":" .. id .. ":pose:" .. a.revision}
        end
        local function execute(c)
            if c.kind=="wait" then return "waited" end
            if c.kind=="turn" then a.npc:set_yaw(a.npc:get_yaw()-math.rad(c.amount));return "turned" end
            if c.kind=="pickup" then
                local before=resource.audit(patches)
                if resource.pickup(patches,c.target_ref,a.npc:get_pos()) then
                    a.revision=a.revision+1
                    local item={operation_id=c.operation_id,target_ref=c.target_ref,acquired_us=sim}
                    a.inventory[#a.inventory+1]=item;assert(#a.inventory<=96,"inventory budget")
                    evidence.stock_events[#evidence.stock_events+1]={agent_id=id,operation_id=c.operation_id,
                        executed_us=sim,target_ref=c.target_ref,before=before,after=resource.audit(patches)}
                    return "picked_up"
                end
                return "not_found"
            end
            local pos=a.npc:get_pos()
            local destination,audit=natural.destination(pos,core.yaw_to_dir(a.npc:get_yaw()),core.get_node_or_nil)
            a.e.terrain_moves[#a.e.terrain_moves+1]={operation_id=c.operation_id,before=vector.new(pos),audit=audit}
            if not destination then return "blocked" end
            a.npc:set_pos(destination);return "moved"
        end
        local teaching
        teaching,a.e.teaching_audit=resource.teach(run .. ":" .. id,natural,a.npc,
            {x=-4,y=natural.height(-4,-2)+1,z=-2},{x=x,y=natural.height(x,2)+1,z=2})
        a.config=context(a,{schema="l14b-multi-resource-predictability-v1",clock_id="world-sim-v1",
            teaching=teaching,selection_profile=trait})
        if terrain_enabled then a.config.schema="l15a-terrain-resource-exploration-v1" end
        if steering_enabled then a.config.schema="l15a-terrain-resource-steering-v2" end
        if rest_mode~="off" then
            a.config.schema="l15a-movement-rest-v1";a.config.rest_mode=rest_mode
        end
        if reactivation_mode~="off" then
            a.config.schema="l15a-rest-reactivation-v1";a.config.reactivation_mode=reactivation_mode
        end
        if reassessment_mode~="off" then
            a.config.schema="l15a-goal-reassessment-v1";a.config.reassessment_mode=reassessment_mode
        end
        if lateral_assignment~="off" then
            a.config.schema="l15a-terrain-lateral-bias-v1"
            local index=id=="npc_a" and 1 or (id=="npc_b" and 2 or 3)
            a.config.lateral_bias=lateral_profiles[lateral_assignment][index]
        end
        if tie_break_mode~="off" then
            a.config.schema="l15a-terrain-tie-break-v1"
            a.config.tie_break_mode=tie_break_mode
        end
        if day_cycle then a.config.schema="l15a-landmark-day-cycle-v1" end
        if return_campaign then a.config.schema="l15a-landmark-return-campaign-v1" end
        a.e.config=table.copy(a.config)
        a.ctl=controller.new(run,{agent_id=id,body=a.body,execute=execute,natural=true,landmarks=true,resources=true,
            capacity=capacity,limit_us=limit,period_us=period_us,
            cycle_boundaries=day_cycle and {1000000,32000000,56000000,64000000} or nil,taught_appearance=teaching.appearance})
        if task_seconds~=0 then a.config.schema="l15a-task-deadline-v1";a.config.task_seconds=task_seconds end
        if reversal_review~="off" then a.config.schema="l15a-reversal-review-v1";a.config.reversal_review_mode=reversal_review end
        a.e.initial_body=a.body();enqueue(a,"configure",a.config)
        return a
    end
    local function sample(a,slot)
        local b=a.body()
        -- Fixed finite experiment schedule, never sent to the agent.
        -- A head-height beam blocks the body while lower surface rays may miss it.
        if a.id=="npc_a" and obstacle_probe~="off" then
            if slot==23 then
                probe_nodes={}
                local dir=core.yaw_to_dir(b.yaw)
                local seen={}
                for i=1,4 do
                    local pos=vector.round(vector.add(b.position,vector.multiply(dir,i/4)))
                    pos.y=math.floor(b.position.y+.5)+1
                    local key=core.pos_to_string(pos)
                    if not seen[key] then
                        seen[key]=true
                        local old=core.get_node(pos)
                        assert(old.name=="air","probe needs clear headroom")
                        probe_nodes[#probe_nodes+1]={position=pos,previous=old}
                        core.set_node(pos,{name="rdl_bridge:exploration_rock_gray"})
                    end
                end
                evidence.obstacle_probe.events[#evidence.obstacle_probe.events+1]={kind="insert",slot=slot,
                    capture_us=sim,nodes=table.copy(probe_nodes),body=table.copy(b)}
            elseif slot==27 and obstacle_probe=="removed" then
                assert(probe_nodes)
                for _,n in ipairs(probe_nodes) do
                    core.set_node(n.position,n.previous)
                    assert(core.get_node(n.position).name==n.previous.name,"probe removal readback")
                end
                evidence.obstacle_probe.events[#evidence.obstacle_probe.events+1]={kind="remove",slot=slot,capture_us=sim}
            end
        end
        if a.id=="npc_a" and obstacle_probe~="off" and slot==28 then
            local destination,audit=natural.destination(b.position,core.yaw_to_dir(b.yaw),core.get_node_or_nil)
            local nodes={}
            for _,n in ipairs(probe_nodes) do
                nodes[#nodes+1]={position=table.copy(n.position),name=core.get_node(n.position).name}
            end
            -- Experimenter-only audit, not an agent observation or prediction.
            evidence.obstacle_probe.review={slot=slot,body=table.copy(b),nodes=nodes,
                traversable=destination~=nil,audit=audit}
        end
        local visible,coverage,visibility=resource.sample(patches,b.position,b.yaw,function(eye,target)
            return natural.visibility(eye,target,core.get_node_or_nil)
        end)
        local features,partial,limited=distant.sample(a.npc,profile,targets)
        local scope=run .. ":" .. a.id
        local p=context(a,{clock_id="world-sim-v1",observation_id=scope .. ":obs:" .. slot,
            capture_us=sim,sample_seq=slot,pose_ref=b.pose_ref,body_revision=b.revision,
            ground=natural.sample(b.position,b.yaw,core.get_node_or_nil),food={coverage=coverage,visible=visible},
            distant={frame_id=scope .. ":distant:" .. slot,agent_id=a.id,sensor_id="eye",channel="vision_distant",
                profile_id="fixture-distant-enabled",profile_revision=1,sensor_model_revision="sampled-surface-v0.2",
                sample_seq=slot,clock_id="world-sim-v1",sampled_world_tick=slot,observer_frame_ref=b.pose_ref,
                capture_window={kind="instant",start_us=sim,end_us=sim},status="SAMPLED",
                coverage=partial and "PARTIAL" or "COMPLETE_WITHIN_PLAN",output_limited=limited,payload={features=features}}})
        local rays;p.landmarks,rays=landmarks.sample(b.position,b.yaw,core.get_node_or_nil)
        local skyline_audit
        if skyline then p.skyline,skyline_audit=skyline.sample(b.position,b.yaw,core.get_node_or_nil,
            {agent_id=a.id,observation_id=p.observation_id,capture_us=sim,pose_ref=b.pose_ref}) end
        local surface_audit
        if surface then p.movement_surface,surface_audit=surface.sample(p,b.position,b.yaw,core.get_node_or_nil) end
        a.e.observations[#a.e.observations+1]={packet=table.copy(p),body=b,daytime=core.get_timeofday(),
            food_visibility=visibility,landmark_rays=rays,movement_surface_audit=surface_audit,skyline_rays=skyline_audit,
            stock_event_count=#evidence.stock_events}
        enqueue(a,"observe",p)
    end
    local function receive(a)
        if not a.mailbox or sim<a.mailbox.release_us then return end
        local reply=a.mailbox;a.mailbox=nil;a.busy=nil
        assert(reply.ok,"HTTP failed: " .. tostring(reply.wire))
        local job=reply.job;local response=core.parse_json(reply.wire)
        evidence.deliveries[#evidence.deliveries+1]={kind=job.kind,request=job.payload,response_wire=reply.wire,
            sent_us=job.sent_us,arrived_us=reply.arrived_us,received_us=sim}
        if job.kind=="configure" then a.configured=true
        elseif job.kind=="observe" then
            local loss_target=a.id=="npc_a" and response.command.kind=="pickup"
            if steering_enabled then
                loss_target=response.command.kind=="turn" and
                    string.sub(response.command.reason,1,18)=="observed_material_"
            end
            if tie_break_mode=="frozen" then loss_target=response.command.reason=="observed_material_tie_break" end
            if faults and loss_target and not evidence.guards.lost_response then
                if tie_break_mode=="frozen" then evidence.guards.lost_tie={agent_id=a.id,
                    operation_id=response.command.operation_id,source_id=job.payload.observation_id} end
                if steering_enabled then evidence.guards.lost_turn={agent_id=a.id,
                    operation_id=response.command.operation_id,source_id=job.payload.observation_id} end
                evidence.guards.lost_response=true;enqueue(a,"observe",job.payload,true)
            else
                if response.new_frames==0 then evidence.guards.loss_recovered=true end
                local before=a.body();local result,new=a.ctl:consume(response.command,job.payload,sim)
                if new then
                    a.e.actions[#a.e.actions+1]={command=response.command,result=result,before=before,after=a.body(),
                        stock_event_count=#evidence.stock_events}
                    enqueue(a,"result",result,true)
                    local effects=a.ctl.effects
                    local _,again=a.ctl:consume(response.command,job.payload,sim)
                    assert(not again and effects==a.ctl.effects);evidence.guards.duplicate_operation=true
                    local other=agents[a.id=="npc_a" and 2 or 1]
                    local other_before=other.body();local count=other.ctl.count
                    assert(not pcall(function() other.ctl:consume(response.command,job.payload,sim) end),"cross-agent response accepted")
                    assert(other.ctl.count==count and vector.equals(other.body().position,other_before.position))
                    evidence.guards.cross_agent=true
                    if not a.old_reply then a.old_reply={command=table.copy(response.command),packet=table.copy(job.payload)} end
                    if faults and job.payload.sample_seq==65 then
                        local _,again2=a.ctl:consume(a.old_reply.command,a.old_reply.packet,sim)
                        assert(not again2 and a.ctl.effects==effects);evidence.guards.old_callback=true
                    end
                end
            end
        elseif job.kind=="finish" then a.done=true end
    end
    local function audit_returns()
        if not return_campaign or stop_requested then return end
        for _,a in ipairs(agents) do
            local last=a.e.actions[#a.e.actions]
            if last and last.command.capture_us%period_us>=56000000 and last.result.status=="waited" then
                local day=math.floor(last.command.capture_us/period_us)
                local key=a.id .. ":" .. day
                if not checked_nights[key] then
                    checked_nights[key]=true
                    local pos=last.after.position
                    local fresh={}
                    for _,item in ipairs(a.inventory) do
                        if not returned[item.operation_id] then fresh[#fresh+1]=item.operation_id end
                    end
                    if pos.x^2+(pos.z-6)^2<=100 and #fresh>0 then
                        for _,op in ipairs(fresh) do returned[op]=true end
                        return_events[#return_events+1]={agent_id=a.id,day=day+1,checked_us=sim,
                            night_operation=last.command.operation_id,position=vector.new(pos),pickup_operations=fresh}
                        if #return_events==3 then stop_requested=true;stop_started=sim;return end
                    end
                end
            end
        end
    end
    local function send(a)
        if a.busy or #a.queue==0 then return end
        local job=table.remove(a.queue,1);a.busy=job;job.sent_us=sim
        http.fetch({url=prefix .. job.kind,method="POST",extra_headers={"Content-Type: application/json"},
            data=encode(job.payload),timeout=3},function(r)
                a.mailbox={job=job,ok=r.succeeded and r.code==200,wire=r.data,arrived_us=sim,
                    release_us=sim+((faults and a.id=="npc_a" and job.kind=="observe" and job.payload.sample_seq==63) and 750000 or 0)}
            end)
    end
    core.register_on_mods_loaded(function() core.after(0,function()
        local ok,err=pcall(function()
            evidence.terrain=natural.build(scenario,day_cycle and 31 or nil);evidence.forceloaded={}
            for x=-64,48,16 do for y=-16,16,16 do for z=-64,48,16 do
                local pos={x=x,y=y,z=z};assert(core.forceload_block(pos,true),"forceload budget")
                evidence.forceloaded[#evidence.forceloaded+1]=pos
            end end end
            patches,evidence.resource_trees=resource.build(run,natural,control,12)
            evidence.stock_initial=resource.audit(patches)
            for i,m in ipairs({{x=-22,z=42,h=8,r=6,color="gray"},{x=42,z=24,h=6,r=5,color="red"},{x=-38,z=-34,h=10,r=7,color="gray"}}) do
                local name="rdl_bridge:exploration_rock_" .. m.color
                for y=1,m.h do local radius=math.max(1,m.r-math.floor(y/2))
                    for x=m.x-radius,m.x+radius do for z=m.z-radius,m.z+radius do core.set_node({x=x,y=y,z=z},{name=name}) end end
                end
                local radius=m.r-2;local surface={x=m.x,y=4,z=m.z-radius}
                if i==2 then surface={x=m.x-radius,y=4,z=m.z} end
                if i==3 then surface={x=m.x+radius,y=4,z=m.z} end
                targets[i]={position=surface,node_name=name,color_band=m.color=="red" and "muted_red" or "dark_gray"}
            end
            if day_cycle then
                local h=natural.height(0,6)
                for x=-1,1 do for z=5,7 do for y=natural.height(x,z)+1,h+12 do
                    core.set_node({x=x,y=y,z=z},{name="rdl_bridge:exploration_tower"})
                end end end
                evidence.home_tower={position={x=0,y=h,z=6},height=12,radius=1}
            end
            core.set_timeofday(.5)
            local traits=assignment=="swapped" and {"restless","curious","steady"} or
                (assignment=="steady" and {"steady","steady","steady"} or {"steady","curious","restless"})
            for i,id in ipairs({"npc_a","npc_b","npc_c"}) do agents[i]=make_agent(i,id,traits[i]) end
            stage="configuring"
        end)
        if not ok then save(tostring(err)) end
    end) end)
    core.register_globalstep(function(dt)
        if stage=="setup" or stage=="done" then return end
        local step=math.floor(dt*speed*1000000+.5)
        evidence.timing.max_step_us=math.max(evidence.timing.max_step_us,step)
        sim=sim+step
        local ok,err=pcall(function()
            assert(sim<=limit+9000000 and (not stop_started or sim<=stop_started+9000000),"drain deadline")
            if stage=="running" and sim>=limit then
                stage="draining"
                for _,a in ipairs(agents) do a.ctl.stopped=true;a.ending=context(a,{ended_us=sim,reason="time_limit"}) end
            end
            -- Rotate simultaneous execution order; fixed A-first never decides all races.
            local first=math.floor(sim/250000)%3
            for j=1,3 do receive(agents[(first+j-1)%3+1]) end
            if stage=="configuring" and agents[1].configured and agents[2].configured and agents[3].configured then stage="running" end
            if stage=="running" then
                audit_returns()
                if stop_requested then stage="draining" end
            end
            if stage=="running" then
                local slot=math.floor(sim/250000)
                if slot~=last_slot then
                    assert(slot==last_slot+1 and slot<capacity,"missed acquisition slot");last_slot=slot
                    if slot%slots_per_period==0 then evidence.periods[#evidence.periods+1]={period=math.floor(slot/slots_per_period),capture_us=sim,
                        stock=resource.audit(patches),stock_event_count=#evidence.stock_events} end
                    for _,a in ipairs(agents) do sample(a,slot) end
                    if return_campaign and slot%slots_per_period==0 then
                        local status={day=math.floor(slot/slots_per_period)+1,capture_us=sim,returns=#return_events,agents={}}
                        for _,a in ipairs(agents) do status.agents[a.id]={inventory=#a.inventory,body=a.body()} end
                        core.safe_file_write(core.get_worldpath() .. "/campaign-progress.json",encode(status))
                    end
                end
            end
            for _,a in ipairs(agents) do
                if stage=="draining" and not a.finishing and not a.busy and #a.queue==0 then
                    if stop_requested then a.ending=context(a,{ended_us=sim,reason="return_target_reached"}) end
                    enqueue(a,"finish",a.ending);a.finishing=true
                end
                send(a)
            end
            if agents[1].done and agents[2].done and agents[3].done then save() end
        end)
        if not ok then save(tostring(err)) end
    end)
end
