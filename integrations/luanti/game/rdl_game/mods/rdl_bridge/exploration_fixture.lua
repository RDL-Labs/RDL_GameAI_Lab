-- World geometry is private to this adapter. Runtime receives only bounded observations.
return function(http,runtime_url)
    local root=core.get_modpath("rdl_bridge")
    local ground=dofile(root .. "/exploration_ground.lua")
    local controller=dofile(root .. "/exploration_controller.lua")
    local distant=dofile(root .. "/distant_sensor.lua")
    local run=assert(core.settings:get("rdl_learning_run_id"))
    local scenario=core.settings:get("rdl_exploration_scenario") or "straight"
    local natural=(scenario=="natural_meadow" or scenario=="natural_woodland") and dofile(root .. "/exploration_natural.lua") or nil
    if natural then natural.register() end
    local neighborhood=core.settings:get_bool("rdl_exploration_neighborhood",false)
    local landmarks=(neighborhood or core.settings:get_bool("rdl_exploration_landmarks",false)) and dofile(root .. "/exploration_landmarks.lua") or nil
    assert(not landmarks or natural,"landmark mode requires natural terrain")
    local profile={range_min_exclusive=12,range_max_inclusive=64,horizontal_fov_deg=90,vertical_fov_deg=60,angle_bin_deg=5}
    local prefix=runtime_url:gsub("/v1/observe$","") .. "/v1/exploration/"
    for _,spec in ipairs({{"gray","#777777"},{"blue","#4477cc"},{"rock_gray","#484848"},{"rock_red","#985950"}}) do
        core.register_node("rdl_bridge:exploration_" .. spec[1],{description="L13 " .. spec[1],
            tiles={"rdl_l13_" .. spec[1] .. ".png"},walkable=true,pointable=false})
    end
    local config={schema=neighborhood and "l13v-neighborhood-exploration-v1" or (landmarks and "l13u-landmark-exploration-v1" or (natural and "l13t-natural-exploration-v1" or "l13a-exploration-v1")),run_id=run,world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1"}
    local evidence={run_id=run,scenario=scenario,config=config,observations={},actions={},deliveries={},guards={},mountains={}}
    local sim,stage,last_slot=0,"setup",-1
    local npc,food,ctl,body_revision,last_position,last_yaw,ending
    local queue,busy,mailbox={},nil,nil
    local targets={}
    local function encode(x)
        return (core.write_json(x):gsub('"visible":null','"visible":[]'):gsub('"features":null','"features":[]'))
    end
    local function context(x)
        x.run_id=run;x.world_epoch=1;x.agent_id="npc_a";return x
    end
    local function enqueue(kind,payload,first)
        local job={kind=kind,payload=table.copy(payload)}
        if first then table.insert(queue,1,job) else queue[#queue+1]=job end
        evidence.max_pending=math.max(evidence.max_pending or 0,#queue+(busy and 1 or 0))
        assert(#queue+(busy and 1 or 0)<=8,"pending_capacity")
    end
    local function body()
        local pos,yaw=npc:get_pos(),npc:get_yaw()
        if vector.distance(pos,last_position)>0.00001 or math.abs(yaw-last_yaw)>0.00001 then
            body_revision=body_revision+1;last_position=vector.new(pos);last_yaw=yaw
        end
        return {position=pos,yaw=yaw,revision=body_revision,pose_ref=run .. ":pose:" .. body_revision}
    end
    local function execute(c)
        if c.kind=="wait" then return "waited" end
        if c.kind=="turn" then npc:set_yaw(npc:get_yaw()-math.rad(c.amount));return "turned" end
        if c.kind=="pickup" then
            if food and food:get_pos() and food:get_luaentity().rdl_id==c.target_ref
                    and vector.distance(npc:get_pos(),food:get_pos())<=1.25 then
                food:remove();assert(food:get_pos()==nil);food=nil
                body_revision=body_revision+1;evidence.pickups=(evidence.pickups or 0)+1
                return "picked_up"
            end
            return "not_found"
        end
        local pos=npc:get_pos();local dir=core.yaw_to_dir(npc:get_yaw())
        if natural then
            local destination,audit=natural.destination(pos,dir,core.get_node_or_nil)
            evidence.terrain_moves[#evidence.terrain_moves+1]={operation_id=c.operation_id,before=vector.new(pos),audit=audit}
            if not destination then return "blocked" end
            npc:set_pos(destination);return "moved"
        end
        for i=1,4 do
            local p=vector.add(pos,vector.multiply(dir,i/4))
            if math.abs(p.x)>32.00001 or math.abs(p.z)>32.00001 then return "blocked" end
            local node=core.get_node_or_nil(vector.round(p))
            local floor=core.get_node_or_nil({x=math.floor(p.x+.5),y=0,z=math.floor(p.z+.5)})
            if not node or node.name~="air" or not floor
                    or (floor.name~="rdl_bridge:exploration_blue" and floor.name~="rdl_bridge:exploration_gray") then return "blocked" end
        end
        npc:set_pos(vector.add(pos,dir));return "moved"
    end
    local function stop(reason)
        if not ending then ending=context({ended_us=sim,reason=reason});ctl.stopped=true;stage="draining" end
    end
    local function save(failure)
        evidence.failure=failure;evidence.finished_us=sim;evidence.ending=ending
        evidence.controller={count=ctl and ctl.count or 0,effects=ctl and ctl.effects or 0,
            distance=ctl and ctl.distance or 0,rotation=ctl and ctl.rotation or 0}
        evidence.final_body=npc and body() or nil
        core.safe_file_write(core.get_worldpath() .. "/l13a-evidence.json",encode(evidence));stage="done"
    end
    local function sample()
        local slot=math.floor(sim/250000)
        if slot==last_slot then return end
        assert(slot<64,"acquisition budget");assert(slot==last_slot+1,"missed acquisition slot")
        last_slot=slot
        local b=body()
        local g=(natural or ground).sample(b.position,b.yaw,function(pos)
            if scenario=="partial" then return nil end -- explicit acquisition fault, not an empty scene
            return core.get_node_or_nil(pos)
        end)
        local visible={};local food_coverage="complete";local visibility
        if food and food:get_pos() then
            local delta=vector.subtract(food:get_pos(),b.position);local distance=vector.length(delta)
            local seen=true
            if natural and distance<=12 then seen,food_coverage=natural.visibility(vector.add(b.position,{x=0,y=.5,z=0}),food:get_pos(),core.get_node_or_nil) end
            if natural then visibility={distance=distance,in_range=distance<=12,line_of_sight=distance<=12 and seen,coverage=food_coverage} end
            if distance<=12 and seen then
                local f=core.yaw_to_dir(b.yaw);local r={x=f.z,y=0,z=-f.x}
                visible[1]={ref=food:get_luaentity().rdl_id,distance=distance,forward=vector.dot(delta,f),right=vector.dot(delta,r)}
                if natural then visible[1].up=delta.y end
                evidence.first_food_us=evidence.first_food_us or sim
            end
        end
        local features,partial,limited=distant.sample(npc,profile,targets)
        local p=context({clock_id="world-sim-v1",observation_id=run .. ":obs:" .. slot,
            capture_us=sim,sample_seq=slot,pose_ref=b.pose_ref,body_revision=b.revision,ground=g,
            food={coverage=food_coverage,visible=visible},distant={frame_id=run .. ":distant:" .. slot,
                agent_id="npc_a",sensor_id="eye",channel="vision_distant",profile_id="fixture-distant-enabled",profile_revision=1,
                sensor_model_revision="sampled-surface-v0.2",sample_seq=slot,clock_id="world-sim-v1",
                capture_window={kind="instant",start_us=sim,end_us=sim},sampled_world_tick=slot,observer_frame_ref=b.pose_ref,
                status="SAMPLED",coverage=partial and "PARTIAL" or "COMPLETE_WITHIN_PLAN",output_limited=limited,
                payload={features=features}}})
        local landmark_audit
        if landmarks then p.landmarks,landmark_audit=landmarks.sample(b.position,b.yaw,core.get_node_or_nil) end
        evidence.observations[#evidence.observations+1]={packet=table.copy(p),body=b,daytime=core.get_timeofday(),food_visibility=visibility,landmark_rays=landmark_audit}
        enqueue("observe",p)
        if scenario=="blocked" and slot==2 then
            local pos=vector.round(vector.add(b.position,core.yaw_to_dir(b.yaw)))
            core.set_node(pos,{name="rdl_bridge:opaque_wall"})
            evidence.inserted_obstacle={position=pos,after_capture_us=sim}
        end
    end
    local function send()
        if busy or #queue==0 then return end
        local job=table.remove(queue,1);busy=job;job.sent_us=sim
        http.fetch({url=prefix .. job.kind,method="POST",extra_headers={"Content-Type: application/json"},
            data=encode(job.payload),timeout=2},function(r)
                mailbox={job=job,ok=r.succeeded and r.code==200,wire=r.data,
                    release_us=sim+((scenario=="faults" and job.kind=="observe" and job.payload.sample_seq==3) and 750000 or 0),
                    arrived_us=sim}
            end)
    end
    core.register_on_mods_loaded(function() core.after(0,function()
        local ok,err=pcall(function()
            if natural then
                evidence.terrain=natural.build(scenario);evidence.terrain_moves={}
            else
            -- Fill loaded air once; surface sampling must not silently read ignore nodes.
            local lo,hi={x=-56,y=0,z=-56},{x=56,y=14,z=56}
            local vm=VoxelManip();local emin,emax=vm:read_from_map(lo,hi)
            local area=VoxelArea:new({MinEdge=emin,MaxEdge=emax});local data=vm:get_data()
            local air,gray=core.get_content_id("air"),core.get_content_id("rdl_bridge:exploration_gray")
            for z=lo.z,hi.z do for y=lo.y,hi.y do for x=lo.x,hi.x do data[area:index(x,y,z)]=y==0 and gray or air end end end
            vm:set_data(data);vm:write_to_map();vm:update_map()
            end
            for x=-32,32,16 do for z=-32,32,16 do core.forceload_block({x=x,y=1,z=z},true) end end
            local rotated=scenario=="rotated"
            local left=scenario=="left"
            local bend=scenario~="straight"
            local function transform(x,z) if rotated then return -z,x end;return x,z end
            local function tile(x,z)
                x,z=transform(x,z)
                if scenario~="no_strip" then core.set_node({x=x,y=0,z=z},{name="rdl_bridge:exploration_blue"}) end
            end
            if not natural then
            for z=0,(bend and 13 or 26) do tile(0,z);tile(left and -1 or 1,z) end
            if bend then for x=0,24 do for z=12,13 do tile(left and -x or x,z) end end end
            end
            local fx,fz=transform(bend and (left and -24 or 24) or 0,bend and 12 or 26)
            if natural then fx,fz=18,18 end
            evidence.food_initial={x=fx,y=natural and natural.height(fx,fz)+1 or 1,z=fz}
            if scenario~="no_food" then food=assert(core.add_entity(evidence.food_initial,"rdl_bridge:food",run .. ":food")) end
            for i,m in ipairs({{x=-22,z=42,h=8,r=6,color="gray"},{x=42,z=24,h=6,r=5,color="red"},{x=-38,z=-34,h=10,r=7,color="gray"}}) do
                local node="rdl_bridge:exploration_rock_" .. m.color
                for y=1,m.h do
                    local radius=math.max(1,m.r-math.floor(y/2))
                    for x=m.x-radius,m.x+radius do for z=m.z-radius,m.z+radius do core.set_node({x=x,y=y,z=z},{name=node}) end end
                end
                local radius=m.r-2
                local surface={x=m.x,y=4,z=m.z-radius}
                if i==2 then surface={x=m.x-radius,y=4,z=m.z} end
                if i==3 then surface={x=m.x+radius,y=4,z=m.z} end
                targets[i]={position=surface,node_name=node,color_band=m.color=="red" and "muted_red" or "dark_gray"}
                evidence.mountains[i]={shape=m,surface=surface,node_name=node,readback=core.get_node(surface).name}
            end
            core.set_timeofday(.5)
            npc=assert(core.add_entity({x=0,y=1,z=0},"rdl_bridge:npc","npc_a"))
            npc:set_properties({physical=false,nametag="L13 explorer",textures={"rdl_l13_agent.png"}})
            npc:set_yaw(rotated and math.pi/2 or 0)
            if food then food:set_properties({textures={"rdl_l13_food.png"}}) end
            body_revision=0;last_position=vector.new(npc:get_pos());last_yaw=npc:get_yaw()
            ctl=controller.new(run,{body=body,execute=execute,natural=natural~=nil,landmarks=landmarks~=nil})
            evidence.initial_body=body()
            evidence.lua_checks=dofile(root .. "/exploration_checks.lua")(controller,ground)
            if natural then evidence.natural_checks=dofile(root .. "/exploration_natural_checks.lua")(natural,controller) end
            if landmarks then evidence.landmark_checks=dofile(root .. "/exploration_landmark_checks.lua")(landmarks,controller) end
            enqueue("configure",config);stage="configuring"
        end)
        if not ok then save(tostring(err)) end
    end) end)
    core.register_globalstep(function(dt)
        if stage=="setup" or stage=="done" then return end
        sim=sim+math.floor(dt*1000000+.5)
        local ok,err=pcall(function()
            assert(sim<=25000000,"drain deadline")
            if stage=="running" and sim>=16000000 then stop("time_limit") end
            if mailbox and sim>=mailbox.release_us then
                local reply=mailbox;mailbox=nil;busy=nil
                assert(reply.ok,"HTTP failed: " .. tostring(reply.wire))
                local job=reply.job;local response=core.parse_json(reply.wire)
                evidence.deliveries[#evidence.deliveries+1]={kind=job.kind,request=job.payload,response_wire=reply.wire,
                    sent_us=job.sent_us,arrived_us=reply.arrived_us,received_us=sim}
                if job.kind=="configure" then stage="running"
                elseif job.kind=="observe" then
                    if scenario=="faults" and job.payload.sample_seq==0 and not evidence.lost_response then
                        evidence.lost_response=true;enqueue("observe",job.payload,true)
                    else
                        if scenario=="faults" and job.payload.sample_seq==0 then
                            assert(response.new_frames==0);evidence.loss_recovered=true
                        end
                        local before=body();local result,new=ctl:consume(response.command,job.payload,sim)
                        if new then
                            evidence.actions[#evidence.actions+1]={command=response.command,result=result,before=before,after=body()}
                            enqueue("result",result,true)
                            local effects=ctl.effects;local same,again=ctl:consume(response.command,job.payload,sim)
                            assert(not again and ctl.effects==effects);evidence.guards.duplicate_operation=true
                            if not evidence.old_reply then evidence.old_reply={command=table.copy(response.command),packet=table.copy(job.payload)} end
                            if result.acquired then evidence.acquired_us=sim;stop("acquired") end
                        end
                        if scenario=="faults" and job.payload.sample_seq==4 then
                            local old=evidence.old_reply;local effects=ctl.effects
                            local _,again=ctl:consume(old.command,old.packet,sim)
                            assert(not again and ctl.effects==effects);evidence.guards.old_callback=true
                        end
                    end
                elseif job.kind=="finish" then save() end
            end
            if stage=="running" then sample() end
            if stage=="draining" and not busy and #queue==0 then enqueue("finish",ending);stage="finishing" end
            send()
        end)
        if not ok then save(tostring(err)) end
    end)
end
