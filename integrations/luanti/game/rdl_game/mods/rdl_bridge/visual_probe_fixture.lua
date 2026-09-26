return function(http, runtime_url, profile)
    local root = core.get_modpath("rdl_bridge")
    local probe = dofile(root .. "/visual_probe.lua")
    local controller_checks = dofile(root .. "/visual_probe_checks.lua")(probe)
    local sensor = dofile(root .. "/distant_sensor.lua")
    local run = assert(core.settings:get("rdl_probe_run_id"))
    local controller = probe.new(run, 1, "npc_a")
    local cases = {"right", "left", "removed", "occluded", "multiple", "overflow", "rotation_mismatch",
                   "expired", "life_busy", "moved", "profile_changed", "pose_expired", "priority", "unloaded", "wrap"}
    local records, frames, npc, candidates = {}, {}, nil, {}
    local tick, elapsed, waiting, index, phase = 0, 0, false, 1, "prepare"
    local entry, request, source, before_yaw, source_yaw, origin, start_tick
    local function time() return tick * 250000 end
    local function yaw_delta(a, b) return probe.wrap(math.deg(a - b)) end -- right positive
    local function body()
        return {now_us = time(), life_busy = false, mapping_valid = true, mapping_expires_us = source.capture_window.start_us + 2000000,
                translation = vector.distance(origin, npc:get_pos()), tilt_deg = math.deg(math.max(math.abs(npc:get_rotation().x),math.abs(npc:get_rotation().z))),
                profile_id = profile.profile_id, profile_revision = profile.profile_revision,
                source_pose = source.observer_frame_ref, pose_ref = request.operation_id .. ":start",
                source_to_start_deg = yaw_delta(source_yaw,npc:get_yaw()), measured_right_deg = yaw_delta(before_yaw,npc:get_yaw()), clock_id = "world-sim-v1"}
    end
    local function sample()
        local values, partial, limited = sensor.sample(npc, profile.vision_distant, candidates)
        local seq = #frames + 1
        local f = {frame_id = run .. ":eye:" .. seq, agent_id = "npc_a", sensor_id = "eye", channel = "vision_distant",
                   profile_id = profile.profile_id, profile_revision = 1, sensor_model_revision = "sampled-surface-v0.2",
                   sample_seq = seq, clock_id = "world-sim-v1", sampled_world_tick = tick,
                   capture_window = {kind = "instant", start_us = time(), end_us = time()},
                   observer_frame_ref = run .. ":pose:" .. seq, status = "SAMPLED",
                   coverage = partial and "PARTIAL" or "COMPLETE_WITHIN_PLAN", output_limited = limited,
                   payload = {features = values}}
        frames[#frames + 1] = f; return f
    end
    local delivery = 0
    local function send(frame, duplicate, done)
        delivery = delivery + 1
        local id = run .. ":delivery:" .. delivery
        local packet = {schema_version = "rdl-luanti-observation-v1", observation_id = id, agent_id = "npc_a", tick = tick,
            observation = {perception_rule = "OBS8 explicit visual probe fixture", visible_agents = {}, visible_objects = {},
                visible_places = {}, visible_regions = {}, recent_events = {}, external_statements = {},
                sensory_extension = {schema_version = "rdl-sensory-extension-v1", run_id = run, world_epoch = 1,
                    agent_id = "npc_a", delivery_observation_id = id, delivery_world_tick = tick,
                    delivery_time_us = time(), frames = {frame}}}}
        local data = core.write_json(packet)
        for _, key in ipairs({"visible_agents", "visible_objects", "visible_places", "visible_regions", "recent_events", "external_statements", "features"}) do
            data = data:gsub('("' .. key .. '"%s*:%s*)null', '%1[]')
        end
        waiting = true
        http.fetch({url = runtime_url, method = "POST", timeout = 3, extra_headers = {"Content-Type: application/json"}, data = data}, function(r)
            assert(r.succeeded and r.code == 200, tostring(r.data))
            local receipt = core.parse_json(r.data).sensory_receipt
            assert(receipt.accepted and receipt.new_frames == (duplicate and 0 or 1), "OBS8 admission")
            waiting = false; done()
        end)
    end
    local function clear_world()
        local vm = VoxelManip()
        local lo, hi = vm:read_from_map({x=-25,y=0,z=-25}, {x=25,y=3,z=25})
        local area = VoxelArea:new({MinEdge=lo,MaxEdge=hi})
        local data = vm:get_data(); local open = core.get_content_id("rdl_bridge:observation_space")
        for x=-25,25 do for y=0,3 do for z=-25,25 do data[area:index(x,y,z)] = open end end end
        vm:set_data(data); vm:write_to_map(); vm:update_map()
    end
    local function target(x,z)
        local pos = {x=x,y=1,z=z}
        core.set_node(pos, {name="rdl_bridge:distant_red"})
        candidates[#candidates+1] = {position=pos,node_name="rdl_bridge:distant_red",color_band="muted_red"}
    end
    local function finish()
        local evidence = {operation_id=request.operation_id, run_id=run, world_epoch=1, agent_id="npc_a",
            operation_status=entry.operation_status, reasons=entry.reasons, rotations=entry.rotations, samples=entry.samples,
            operation_response_lost=entry.operation_response_lost or false, delivery_new_frames=entry.delivery_new_frames,
            final_right_yaw_deg=yaw_delta(before_yaw,npc:get_yaw()), final_translation=vector.distance(origin,npc:get_pos())}
        if entry.plan then
            evidence.started_us=entry.plan.started_us; evidence.command_deg=entry.plan.command_deg
            evidence.rotation_completed_us=entry.rotation_completed_us
        end
        if entry.frame then
            evidence.sample_tick=entry.sample_tick; evidence.new_frame_id=entry.frame.frame_id
            evidence.pose={issuer="luanti-body-yaw-v1", evidence_id=request.operation_id .. ":measured", valid=true,
                source_ref=source.observer_frame_ref, start_ref=entry.plan.start_pose, target_ref=entry.frame.observer_frame_ref,
                source_us=source.capture_window.start_us, start_us=entry.plan.started_us, target_us=entry.frame.capture_window.start_us,
                expires_us=source.capture_window.start_us+2000000, clock_id="world-sim-v1",
                source_to_start_deg=entry.plan.source_to_start_deg, start_to_target_deg=entry.acquisition_body.measured_right_deg,
                error_deg=0.001, translation=entry.acquisition_body.translation, tilt_deg=entry.acquisition_body.tilt_deg}
        end
        records[#records+1]={case=cases[index], request=table.copy(request), evidence=evidence}
        local again, fresh = controller.start(request,source,body())
        assert(again==entry and not fresh, "terminal replay")
        assert(not controller.rotate(entry,body(),function() error("duplicate rotation") end,function() return 0 end))
        assert(not controller.sample(entry,tick,body(),function() error("duplicate sample") end))
        index=index+1; phase="prepare"
        if index>#cases then
            -- Capacity and conflict refusal after actual operations; old context never executes.
            local extra=table.copy(request); extra.operation_id="sixteenth"
            local busy=body(); busy.life_busy=true
            controller.start(extra,source,busy)
            extra.operation_id="seventeenth"; assert(not pcall(controller.start,extra,source,busy))
            extra=table.copy(request); extra.color_band="dark_gray"; assert(not pcall(controller.start,extra,source,busy))
            extra=table.copy(request); extra.run_id="old-run"; assert(not pcall(controller.start,extra,source,busy))
            core.safe_file_write(core.get_worldpath() .. "/obs8-evidence.json", core.write_json({run_id=run,records=records,ledger_checks=true,controller_checks=controller_checks}))
            core.log("action", "[RDL_LUANTI_OBS8] complete cases=" .. #records .. " frames=" .. #frames)
            phase="done"
        end
    end
    core.register_on_mods_loaded(function()
        core.after(0,function()
            clear_world()
            npc=assert(core.add_entity({x=0,y=1,z=0},"rdl_bridge:npc","npc_a"))
            npc:set_properties({physical=false}); npc:set_acceleration({x=0,y=0,z=0})
        end)
    end)
    core.register_globalstep(function(dt)
        if not npc or waiting or phase=="done" then return end
        elapsed=elapsed+dt; if elapsed<0.25 then return end; elapsed=elapsed-0.25
        local name=cases[index]
        if phase=="prepare" and tick%4==0 then
            clear_world(); candidates={}; npc:set_pos({x=0,y=1,z=0}); npc:set_yaw(name=="wrap" and math.rad(179) or 0)
            origin=npc:get_pos(); before_yaw=npc:get_yaw(); source_yaw=before_yaw
            if name=="wrap" then target(12,-20) else target(name=="left" and -12 or 12,20) end
            source=sample(); assert(#source.payload.features==1 and source.coverage=="COMPLETE_WITHIN_PLAN")
            request={operation_id=run .. ":op:" .. index,run_id=run,world_epoch=1,agent_id="npc_a",
                     purpose="visual_reacquisition_after_yaw",rule_version="obs8-v1",source_frame_id=source.frame_id,
                     feature_id=source.payload.features[1].feature_id,color_band="muted_red"}
            phase="waiting_source"
            send(source,false,function() phase="start" end)
        elseif phase=="start" then
            if name=="wrap" then npc:set_yaw(source_yaw+math.rad(10)) end
            before_yaw=npc:get_yaw()
            local b=body()
            if name=="expired" then b.now_us=source.capture_window.start_us+2000001 end
            if name=="life_busy" then b.life_busy=true end
            entry=controller.start(request,source,b)
            if entry.operation_status=="not_executed" then finish()
            else
                start_tick=tick
                controller.rotate(entry,b,function(deg) npc:set_yaw(before_yaw-math.rad(deg)+(name=="rotation_mismatch" and math.rad(2) or 0)) end,
                                  function() return yaw_delta(before_yaw,npc:get_yaw()) end)
                local retry,fresh=controller.start(request,source,b); assert(retry==entry and not fresh)
                assert(not controller.rotate(entry,b,function() error("rotation repeated") end,function() return 0 end))
                if entry.operation_status=="aborted" then finish()
                else
                    if name=="removed" then core.set_node(candidates[1].position,{name="rdl_bridge:observation_space"}) end
                    if name=="occluded" then core.set_node({x=11,y=1,z=19},{name="rdl_bridge:opaque_wall"}) end
                    if name=="multiple" then target(14,20) end
                    if name=="overflow" then for _,x in ipairs({2,5,8,15,18}) do target(x,20) end end
                    if name=="unloaded" then candidates[#candidates+1]={position={x=10000,y=1,z=10000},node_name="rdl_bridge:distant_red",color_band="muted_red"} end
                    if name=="moved" then npc:set_pos({x=0.1,y=1,z=0}) end
                    phase="sample"
                end
            end
        elseif phase=="sample" then
            local b=body()
            if name=="profile_changed" then b.profile_revision=2 end
            if name=="pose_expired" then b.mapping_valid=false end
            if name=="priority" then b.life_busy=true end
            local f=controller.sample(entry,tick,b,function()
                entry.acquisition_body=body() -- acquisition-time provenance, never delivery-time pose
                return sample()
            end)
            if entry.operation_status=="aborted" then finish()
            elseif f then
                phase="waiting_target"
                -- Drop the first successful observation response for the right-turn case.
                -- The operation result remains in the ledger; delivery replay saves no new frame.
                send(f,false,function()
                    if name=="right" then
                        entry.operation_response_lost=true -- first completion intentionally not returned to caller
                        local replay,fresh=controller.start(request,source,body()); assert(replay==entry and not fresh)
                        entry.delivery_new_frames={1,0}
                        send(f,true,finish)
                    else finish() end
                end)
            end
        end
        tick=tick+1
    end)
end
