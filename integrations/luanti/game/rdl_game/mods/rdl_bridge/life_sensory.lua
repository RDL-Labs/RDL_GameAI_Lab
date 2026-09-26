local M = {}

function M.new(profiles, interval)
    local modpath = core.get_modpath("rdl_bridge")
    local distant_sensor = dofile(modpath .. "/distant_sensor.lua")
    local window_us = math.floor(interval * 1000000 + 0.5)
    local audition = dofile(modpath .. "/audition_window_sensor.lua").new(window_us, 32, 8)
    local state = {time_us = 0, sequences = {}, audition = audition}
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

    function state:ensure_world()
        local vm = VoxelManip()
        local min_edge, max_edge = vm:read_from_map(
            {x = 0, y = 1, z = -3}, {x = 1, y = 2, z = 23})
        local area = VoxelArea:new({MinEdge = min_edge, MaxEdge = max_edge})
        local data = vm:get_data()
        local open_id = core.get_content_id("rdl_bridge:observation_space")
        for x = 0, 1 do
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

    function state:record_action_sound(source_agent_id, npcs, tick)
        local source = npcs[source_agent_id]
        if not source then return end
        for receiver_id, receiver in pairs(npcs) do
            if receiver_id ~= source_agent_id then
                local distance = vector.distance(receiver:get_pos(), source:get_pos())
                local attenuation = 1 / (1 + (distance / 4) ^ 2)
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
                    low = 0, mid = attenuation, high = 0,
                })
            end
        end
    end

    function state:attach(packet, agent_id, npc, visible_count, tick)
        local profile = profiles[agent_id]
        local frames = {}
        table.insert(frames, frame(agent_id, "vision_local", "eye", profile, tick,
            {kind = "instant", start_us = self.time_us, end_us = self.time_us},
            {visible_count = visible_count}, string.format("%s:eye-pose:%d", agent_id, tick)))

        if tick % profile.vision_distant.sample_every_world_ticks == 0 then
            local features, partial, limited = distant_sensor.sample(
                npc, profile.vision_distant, distant_targets[agent_id])
            core.log("action", string.format(
                "[RDL_LUANTI_OBS6] distant agent=%s tick=%d features=%d partial=%s yaw=%.3f",
                agent_id, tick, #features, tostring(partial), npc:get_yaw() or 0))
            table.insert(frames, frame(agent_id, "vision_distant", "eye", profile, tick,
                {kind = "instant", start_us = self.time_us, end_us = self.time_us},
                {features = features}, string.format("%s:eye-pose:%d", agent_id, tick),
                partial and "PARTIAL" or "COMPLETE_WITHIN_PLAN", limited))
        end

        if self.time_us >= window_us then
            local start_us = self.time_us - window_us
            local closed = self.audition:close(agent_id, start_us, profile.audition)
            table.insert(frames, frame(agent_id, "audition", "ears", profile, tick,
                {kind = "interval", start_us = start_us, end_us = self.time_us},
                {detections = closed.detections}, string.format("%s:ear-window:%d", agent_id, tick),
                closed.incomplete and "PARTIAL" or "COMPLETE_WITHIN_PLAN", closed.incomplete))
        end

        packet.observation.sensory_extension = {
            schema_version = "rdl-sensory-extension-v1", run_id = "fixture-run-1",
            world_epoch = 1, agent_id = agent_id,
            delivery_observation_id = packet.observation_id,
            delivery_world_tick = tick, delivery_time_us = self.time_us, frames = frames,
        }
    end

    function state:advance()
        self.time_us = self.time_us + window_us
    end

    return state
end

return M
