local M = {}

function M.new(profiles, interval)
    local window_us = math.floor(interval * 1000000 + 0.5)
    local state = {time_us = 0, sequences = {}, receipts = {npc_a = {}, npc_b = {}}}
    local distant_targets = {
        npc_a = {x = 20, y = 1, z = -3},
        npc_b = {x = 20, y = 1, z = 3},
    }

    local function next_sequence(agent_id, channel)
        local key = agent_id .. ":" .. channel
        state.sequences[key] = (state.sequences[key] or 0) + 1
        return state.sequences[key]
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
                local profile = profiles[receiver_id]
                local distance = vector.distance(receiver:get_pos(), source:get_pos())
                local received = (1 / (1 + (distance / 4) ^ 2)) * profile.audition.gain
                table.insert(self.receipts[receiver_id], {
                    tick = tick, strength = received,
                    angle = local_angle(receiver, source:get_pos()),
                    pose_ref = string.format("%s:ear-pose:%d", receiver_id, tick),
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
            local angle = local_angle(npc, distant_targets[agent_id])
            local features = {}
            local distance = vector.distance(npc:get_pos(), distant_targets[agent_id])
            if distance > profile.vision_distant.range_min_exclusive and
                    distance <= profile.vision_distant.range_max_inclusive and
                    math.abs(angle) <= profile.vision_distant.horizontal_fov_deg / 2 then
                table.insert(features, {
                    feature_id = "f0",
                    azimuth_interval_deg = interval_band(angle, profile.vision_distant.angle_bin_deg),
                    elevation_interval_deg = {0, profile.vision_distant.angle_bin_deg},
                    angular_width_band = "unknown", angular_height_band = "unknown",
                    color_band = agent_id == "npc_a" and "muted_red" or "dark_gray",
                })
            end
            table.insert(frames, frame(agent_id, "vision_distant", "eye", profile, tick,
                {kind = "instant", start_us = self.time_us, end_us = self.time_us},
                {features = features}, string.format("%s:eye-pose:%d", agent_id, tick)))
        end

        local detections = {}
        for _, receipt in ipairs(self.receipts[agent_id]) do
            if receipt.strength >= profile.audition.detection_threshold then
                table.insert(detections, {
                    detection_id = "d" .. tostring(#detections),
                    received_interval_us = {self.time_us - window_us, self.time_us},
                    observer_frame_ref = receipt.pose_ref,
                    azimuth_interval_deg = interval_band(receipt.angle, profile.audition.direction_bin_deg),
                    elevation_band = "level", received_strength_band = receipt.strength < 0.2 and "weak" or "medium",
                    dominant_band = "mid", temporal_form = "brief",
                })
            end
        end
        self.receipts[agent_id] = {}
        table.insert(frames, frame(agent_id, "audition", "ears", profile, tick,
            {kind = "interval", start_us = math.max(0, self.time_us - window_us), end_us = self.time_us},
            {detections = detections}, string.format("%s:ear-window:%d", agent_id, tick)))

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
