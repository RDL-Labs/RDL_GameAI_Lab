return function(http, runtime_url, profiles)
    local agents = {
        npc_a = {position = {x = 0, y = 1, z = 0}, profile = profiles.npc_a},
        npc_b = {position = {x = 1, y = 1, z = 0}, profile = profiles.npc_b},
    }
    local source_position = {x = 0, y = 1, z = 4}
    local event_time_us = 125000
    local world_events = {
        {occurred_us = event_time_us, duration_us = 10000,
         band_energy = {low = 0, mid = 0.3, high = 0}},
        {occurred_us = event_time_us, duration_us = 10000,
         band_energy = {low = 0, mid = 0.3, high = 0}},
    }

    local function bounded_events(events)
        local accepted = {}
        local overflow = false
        for _, event in ipairs(events) do
            if #accepted < 32 then
                table.insert(accepted, event)
            else
                overflow = true
            end
        end
        return accepted, overflow
    end

    local function quantized_interval(value, width)
        local lower = math.floor(value / width) * width
        return {lower, lower + width}
    end

    local function transmission(observer, source)
        local delta = vector.subtract(source, observer)
        local distance = vector.length(delta)
        local direction = vector.normalize(delta)
        local source_node = vector.round(source)
        local factor = 1
        local previous_node_key = nil
        for index = 1, math.min(128, math.ceil(distance / 0.5)) do
            local position = vector.round(vector.add(observer, vector.multiply(direction, index * 0.5)))
            if position.x == source_node.x and position.y == source_node.y and
                    position.z == source_node.z then
                return factor
            end
            local node_key = string.format("%d:%d:%d", position.x, position.y, position.z)
            if node_key ~= previous_node_key then
                local node = core.get_node_or_nil(position)
                if not node or node.name == "ignore" then return nil end
                if node.name == "rdl_bridge:opaque_wall" then
                    factor = factor * 0.5
                elseif node.name ~= "air" and node.name ~= "rdl_bridge:observation_space" then
                    return nil
                end
                previous_node_key = node_key
            end
        end
        return nil
    end

    local function receive(agent)
        local delta = vector.subtract(source_position, agent.position)
        local distance = vector.length(delta)
        local path_factor = transmission(agent.position, source_position)
        if not path_factor then return {}, "PARTIAL" end
        local attenuation = 1 / (1 + (distance / 4) ^ 2)
        local emitted_mid = 0
        for _, event in ipairs(world_events) do
            emitted_mid = emitted_mid + event.band_energy.mid
        end
        local mixed_mid = emitted_mid * attenuation * path_factor
        local perceived = math.min(1, mixed_mid * agent.profile.audition.gain)
        local threshold = math.max(agent.profile.audition.detection_threshold,
            agent.profile.audition.noise_floor * agent.profile.audition.noise_ratio)
        if perceived < threshold then return {}, "COMPLETE_WITHIN_PLAN" end
        local azimuth = math.deg(math.atan2(delta.x, delta.z))
        local strength = perceived < 0.2 and "weak" or
            (perceived < 0.6 and "medium" or "strong")
        return {{
            detection_id = "d0",
            received_interval_us = {event_time_us, event_time_us + 10000},
            observer_frame_ref = agent.observer_frame_ref,
            azimuth_interval_deg = quantized_interval(
                azimuth, agent.profile.audition.direction_bin_deg),
            elevation_band = "level", received_strength_band = strength,
            dominant_band = "mid", temporal_form = "brief",
        }}, "COMPLETE_WITHIN_PLAN"
    end

    local function packet_for(agent_id, sequence)
        local agent = agents[agent_id]
        agent.observer_frame_ref = agent_id .. ":ear-pose:1"
        local detections, coverage = receive(agent)
        local observation_id = "luanti-audition-000001-" .. agent_id
        local overflow_events = {}
        for index = 1, 33 do table.insert(overflow_events, {ordinal = index}) end
        local _, overflow = bounded_events(overflow_events)
        local frames = {{
            frame_id = string.format("fixture-run-1:1:%s:ears:audition:%d", agent_id, sequence),
            agent_id = agent_id, sensor_id = "ears", channel = "audition",
            profile_id = agent.profile.profile_id,
            profile_revision = agent.profile.profile_revision,
            sensor_model_revision = "direct_band_energy_v0", sample_seq = sequence,
            clock_id = "world-sim-v1",
            capture_window = {kind = "interval", start_us = 0, end_us = 250000},
            sampled_world_tick = 1, observer_frame_ref = agent.observer_frame_ref,
            status = "SAMPLED", coverage = coverage, output_limited = false,
            payload = {detections = detections},
        }, {
            frame_id = string.format("fixture-run-1:1:%s:ears:audition:%d", agent_id, sequence + 1),
            agent_id = agent_id, sensor_id = "ears", channel = "audition",
            profile_id = agent.profile.profile_id,
            profile_revision = agent.profile.profile_revision,
            sensor_model_revision = "direct_band_energy_v0", sample_seq = sequence + 1,
            clock_id = "world-sim-v1",
            capture_window = {kind = "interval", start_us = 250000, end_us = 500000},
            sampled_world_tick = 1, observer_frame_ref = agent.observer_frame_ref,
            status = "SAMPLED", coverage = overflow and "PARTIAL" or "COMPLETE_WITHIN_PLAN",
            output_limited = overflow, payload = {detections = {}},
        }}
        return {
            schema_version = "rdl-luanti-observation-v1", observation_id = observation_id,
            tick = 1, agent_id = agent_id,
            observation = {
                perception_rule = "audition fixture; no legacy targets",
                visible_agents = {}, visible_objects = {}, visible_places = {},
                visible_regions = {}, recent_events = {}, external_statements = {},
                sensory_extension = {
                    schema_version = "rdl-sensory-extension-v1", run_id = "fixture-run-1",
                    world_epoch = 1, agent_id = agent_id,
                    delivery_observation_id = observation_id, delivery_world_tick = 1,
                    delivery_time_us = 500000, frames = frames,
                },
            },
            adapter = {backend = "luanti", version = "rdl-luanti-audition-v0",
                       authority = "finite-world-observation-only"},
        }, #detections, coverage, overflow
    end

    local function send(agent_ids, index)
        if index > #agent_ids then return end
        local agent_id = agent_ids[index]
        local packet, count, coverage, overflow = packet_for(agent_id, 1)
        local body = core.write_json(packet)
        for _, field in ipairs({"visible_agents", "visible_objects", "visible_places",
                                "visible_regions", "recent_events", "external_statements",
                                "detections"}) do
            body = body:gsub('("' .. field .. '"%s*:%s*)null', '%1[]')
        end
        http.fetch({url = runtime_url, method = "POST", timeout = 3,
                    extra_headers = {"Content-Type: application/json"}, data = body},
            function(result)
                if not result.succeeded or result.code ~= 200 then
                    core.log("error", "[rdl_bridge] audition Runtime response " ..
                        tostring(result.code) .. ": " .. tostring(result.data))
                    return
                end
                core.log("action", string.format(
                    "[RDL_LUANTI_OBS4] delivered agent=%s detections=%d coverage=%s overflow=%s",
                    agent_id, count, coverage, tostring(overflow)))
                send(agent_ids, index + 1)
            end)
    end

    local function ensure_fixture()
        local vm = VoxelManip()
        local min_edge, max_edge = vm:read_from_map({x = -1, y = 1, z = 0}, {x = 1, y = 1, z = 4})
        local area = VoxelArea:new({MinEdge = min_edge, MaxEdge = max_edge})
        local data = vm:get_data()
        local open_id = core.get_content_id("rdl_bridge:observation_space")
        local wall_id = core.get_content_id("rdl_bridge:opaque_wall")
        for x = -1, 1 do
            for y = 1, 1 do
                for z = 0, 4 do
                    data[area:index(x, y, z)] = open_id
                end
            end
        end
        data[area:index(0, 1, 2)] = wall_id
        data[area:index(1, 1, 2)] = wall_id
        vm:set_data(data)
        vm:write_to_map()
        vm:update_map()
        core.after(0.25, function() send({"npc_a", "npc_b"}, 1) end)
    end

    core.register_on_mods_loaded(function()
        core.forceload_block({x = 0, y = 0, z = 0}, true)
        core.after(0, ensure_fixture)
    end)
end
