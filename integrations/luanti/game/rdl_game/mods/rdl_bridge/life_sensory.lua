local M = {}

function M.new(profiles, interval)
    local modpath = core.get_modpath("rdl_bridge")
    local distant_sensor = dofile(modpath .. "/distant_sensor.lua")
    local transmission = dofile(modpath .. "/audition_transmission.lua")
    local window_us = math.floor(interval * 1000000 + 0.5)
    local audition = dofile(modpath .. "/audition_window_sensor.lua").new(window_us, 32, 8)
    local state = {time_us = 0, sequences = {}, audition = audition,
                   pending = {npc_a = {}, npc_b = {}}, in_flight = {},
                   retry_ids = {}, world_initialized = false}
    local distant_targets = {
        npc_a = {{position = {x = 0, y = 1, z = 17},
                  node_name = "rdl_bridge:distant_red", color_band = "muted_red"}},
        npc_b = {{position = {x = 1, y = 1, z = 23},
                  node_name = "rdl_bridge:distant_dark", color_band = "dark_gray"}},
    }

    local function next_sequence(agent_id, channel)
        local key = agent_id .. ":" .. channel
        state.sequences[key] = (state.sequences[key] or 0) + 1
        return state.sequences[key]
    end

    function state:initialize_world()
        if self.world_initialized then return end
        local vm = VoxelManip()
        local min_edge, max_edge = vm:read_from_map(
            {x = 0, y = 1, z = -3}, {x = 4, y = 2, z = 23})
        local area = VoxelArea:new({MinEdge = min_edge, MaxEdge = max_edge})
        local data = vm:get_data()
        local open_id = core.get_content_id("rdl_bridge:observation_space")
        for x = 0, 4 do
            for y = 1, 2 do
                for z = -3, 23 do data[area:index(x, y, z)] = open_id end
            end
        end
        for _, targets in pairs(distant_targets) do
            for _, target in ipairs(targets) do
                data[area:index(target.position.x, target.position.y, target.position.z)] =
                    core.get_content_id(target.node_name)
            end
        end
        vm:set_data(data)
        vm:write_to_map()
        vm:update_map()
        self.world_initialized = true
    end

    function state:verify_world_changes(npcs)
        local npc, target = npcs.npc_a, distant_targets.npc_a[1]
        if not npc then return false end
        local original_yaw = npc:get_yaw() or 0
        npc:set_yaw(0)
        local visible = distant_sensor.sample(npc, profiles.npc_a.vision_distant, {target})
        local wall_position = {x = 0, y = 1, z = 8}
        local original_wall = core.get_node(wall_position)
        core.set_node(wall_position, {name = "rdl_bridge:opaque_wall"})
        local hidden = distant_sensor.sample(npc, profiles.npc_a.vision_distant, {target})
        self:initialize_world()
        local wall_preserved = core.get_node(wall_position).name == "rdl_bridge:opaque_wall"
        core.set_node(wall_position, original_wall)
        local original_target = core.get_node(target.position)
        core.set_node(target.position, {name = "rdl_bridge:observation_space"})
        local absent = distant_sensor.sample(npc, profiles.npc_a.vision_distant, {target})
        core.set_node(target.position, original_target)
        npc:set_yaw(original_yaw)

        local sound_wall = {x = 0, y = 1, z = 0}
        local original_sound_wall = core.get_node(sound_wall)
        core.set_node(sound_wall, {name = "rdl_bridge:observation_space"})
        local open_factor = transmission.factor({x = 0, y = 1, z = -3}, {x = 0, y = 1, z = 3})
        core.set_node(sound_wall, {name = "rdl_bridge:opaque_wall"})
        local wall_factor = transmission.factor({x = 0, y = 1, z = -3}, {x = 0, y = 1, z = 3})
        core.set_node(sound_wall, original_sound_wall)
        local passed = #visible == 1 and #hidden == 0 and #absent == 0 and
            wall_preserved and open_factor == 1 and wall_factor == 0.5
        core.log(passed and "action" or "error", string.format(
            "[RDL_LUANTI_OBS6C] world_probe=%s visible=%d hidden=%d absent=%d wall_preserved=%s sound=%.1f/%.1f",
            passed and "PASS" or "FAIL", #visible, #hidden, #absent,
            tostring(wall_preserved), open_factor or -1, wall_factor or -1))
        return passed
    end

    local function interval_band(value, width)
        local lower = math.floor(value / width) * width
        return {lower, lower + width}
    end

    local function local_angle(npc, target)
        local delta = vector.subtract(target, npc:get_pos())
        local forward = core.yaw_to_dir(npc:get_yaw() or 0)
        local right = {x = forward.z, y = 0, z = -forward.x}
        return math.deg(math.atan2(vector.dot(delta, right), vector.dot(delta, forward)))
    end

    local function frame(agent_id, channel, sensor_id, profile, tick, capture, payload,
                         pose_ref, coverage, output_limited)
        local sequence = next_sequence(agent_id, channel)
        return {
            frame_id = string.format("fixture-run-1:1:%s:%s:%s:%d",
                agent_id, sensor_id, channel, sequence),
            agent_id = agent_id, sensor_id = sensor_id, channel = channel,
            profile_id = profile.profile_id, profile_revision = profile.profile_revision,
            sensor_model_revision = channel == "vision_local" and "legacy_radius_v1" or
                (channel == "vision_distant" and "sampled-surface-v0.2" or "direct_band_energy_v0"),
            sample_seq = sequence, clock_id = "world-sim-v1", capture_window = capture,
            sampled_world_tick = tick, observer_frame_ref = pose_ref,
            status = "SAMPLED", coverage = coverage or "COMPLETE_WITHIN_PLAN",
            output_limited = output_limited or false, payload = payload,
        }
    end

    local function enqueue(agent_id, value)
        if #state.pending[agent_id] >= 64 then
            core.log("error", "[RDL_LUANTI_OBS6] sensory pending queue full agent=" .. agent_id)
            return false
        end
        table.insert(state.pending[agent_id], value)
        return true
    end

    function state:record_action_sound(source_agent_id, npcs, tick)
        local source = npcs[source_agent_id]
        if not source then return end
        for receiver_id, receiver in pairs(npcs) do
            if receiver_id ~= source_agent_id then
                local distance = vector.distance(receiver:get_pos(), source:get_pos())
                local attenuation = 1 / (1 + (distance / 4) ^ 2)
                local path_factor = transmission.factor(receiver:get_pos(), source:get_pos())
                if not path_factor then
                    self.audition:mark_incomplete(receiver_id, self.time_us)
                else
                    local angle = local_angle(receiver, source:get_pos())
                    local angle_interval = interval_band(
                        angle, profiles[receiver_id].audition.direction_bin_deg)
                    local pose_ref = string.format("%s:ear-pose:%d", receiver_id, tick)
                    self.audition:emit(receiver_id, {
                        occurred_us = self.time_us, duration_us = 10000,
                        observer_frame_ref = pose_ref,
                        cell_key = string.format("%d:%d:%s",
                            angle_interval[1], angle_interval[2], pose_ref),
                        azimuth_interval_deg = angle_interval,
                        low = 0, mid = attenuation * path_factor, high = 0,
                    })
                end
            end
        end
    end

    function state:attach(packet, agent_id, npc, visible_count, tick)
        local profile = profiles[agent_id]
        enqueue(agent_id, frame(agent_id, "vision_local", "eye", profile, tick,
            {kind = "instant", start_us = self.time_us, end_us = self.time_us},
            {visible_count = visible_count}, string.format("%s:eye-pose:%d", agent_id, tick)))

        if tick % profile.vision_distant.sample_every_world_ticks == 0 then
            local features, partial, limited = distant_sensor.sample(
                npc, profile.vision_distant, distant_targets[agent_id])
            core.log("action", string.format(
                "[RDL_LUANTI_OBS6] distant agent=%s tick=%d features=%d partial=%s yaw=%.3f",
                agent_id, tick, #features, tostring(partial), npc:get_yaw() or 0))
            enqueue(agent_id, frame(agent_id, "vision_distant", "eye", profile, tick,
                {kind = "instant", start_us = self.time_us, end_us = self.time_us},
                {features = features}, string.format("%s:eye-pose:%d", agent_id, tick),
                partial and "PARTIAL" or "COMPLETE_WITHIN_PLAN", limited))
        end

        local frames = {}
        local retry = self.retry_ids[agent_id]
        for _, queued in ipairs(self.pending[agent_id]) do
            if not retry or retry[queued.frame_id] then
                table.insert(frames, queued)
                if #frames == 4 then break end
            end
        end
        self.in_flight[agent_id] = {}
        for _, pending_frame in ipairs(frames) do
            table.insert(self.in_flight[agent_id], pending_frame.frame_id)
        end

        packet.observation.sensory_extension = {
            schema_version = "rdl-sensory-extension-v1", run_id = "fixture-run-1",
            world_epoch = 1, agent_id = agent_id,
            delivery_observation_id = packet.observation_id,
            delivery_world_tick = tick, delivery_time_us = self.time_us, frames = frames,
        }
        core.log("action", string.format(
            "[RDL_LUANTI_OBS6D] delivery agent=%s frames=%d pending=%d",
            agent_id, #frames, #self.pending[agent_id]))
    end

    function state:ack(agent_id, receipt)
        local ids = self.in_flight[agent_id]
        self.in_flight[agent_id] = nil
        if not ids or not receipt or receipt.accepted ~= true then
            core.log("warning", "[RDL_LUANTI_OBS6D] sensory receipt rejected; retained agent=" .. agent_id)
            return false
        end
        local accepted, retained = {}, {}
        for _, frame_id in ipairs(ids) do accepted[frame_id] = true end
        for _, pending_frame in ipairs(self.pending[agent_id]) do
            if not accepted[pending_frame.frame_id] then table.insert(retained, pending_frame) end
        end
        self.pending[agent_id] = retained
        self.retry_ids[agent_id] = nil
        core.log("action", string.format(
            "[RDL_LUANTI_OBS6D] ack agent=%s removed=%d pending=%d new_frames=%s",
            agent_id, #ids, #retained, tostring(receipt.new_frames)))
        return true
    end

    -- Fixture-only response loss: preserve the exact accepted batch for retry.
    function state:lose_response(agent_id)
        local retry = {}
        for _, id in ipairs(self.in_flight[agent_id] or {}) do retry[id] = true end
        self.retry_ids[agent_id] = retry
        self:release(agent_id)
    end

    function state:probe(agent_id, phase, frames, receipt)
        local ids, pending = {}, {}
        for _, value in ipairs(frames) do table.insert(ids, value.frame_id) end
        for _, value in ipairs(self.pending[agent_id]) do table.insert(pending, value.frame_id) end
        core.log("action", "[RDL_LUANTI_OBS6E] " .. core.write_json({
            phase = phase, agent_id = agent_id, ids = ids, pending = pending,
            accepted = receipt and receipt.accepted,
            new_frames = receipt and receipt.new_frames,
            in_flight = self.in_flight[agent_id] ~= nil,
        }))
    end

    function state:release(agent_id)
        self.in_flight[agent_id] = nil
    end

    function state:advance(tick)
        local start_us = self.time_us
        self.time_us = self.time_us + window_us
        for agent_id, profile in pairs(profiles) do
            local closed = self.audition:close(agent_id, start_us, profile.audition)
            local pending_frame = frame(agent_id, "audition", "ears", profile, tick,
                {kind = "interval", start_us = start_us, end_us = self.time_us},
                {detections = closed.detections}, string.format("%s:ear-window:%d", agent_id, tick),
                closed.incomplete and "PARTIAL" or "COMPLETE_WITHIN_PLAN", closed.incomplete)
            enqueue(agent_id, pending_frame)
        end
    end

    return state
end

return M
