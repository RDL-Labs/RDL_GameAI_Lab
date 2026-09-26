return function(http, runtime_url, profiles)
    local WINDOW_US, BUFFER_LIMIT = 250000, 32
    local agents = {
        npc_a = {position = {x = 0, y = 1, z = 0}, yaw = 0, pose_revision = "before-turn",
                 profile = profiles.npc_a, buffer = {}, frames = {}, incomplete = {}},
        npc_b = {position = {x = 1, y = 1, z = 0}, yaw = 0, pose_revision = "before-turn",
                 profile = profiles.npc_b, buffer = {}, frames = {}, incomplete = {}},
    }
    local source_position = {x = 0, y = 1, z = 4}

    local function window_start(time_us)
        return math.floor(time_us / WINDOW_US) * WINDOW_US
    end

    local function quantized_interval(value, width)
        local lower = math.floor(value / width) * width
        return {lower, lower + width}
    end

    local function local_azimuth(agent, source)
        local delta = vector.subtract(source, agent.position)
        local forward = core.yaw_to_dir(agent.yaw)
        local right = {x = forward.z, y = 0, z = -forward.x}
        local angle = math.deg(math.atan2(vector.dot(delta, right), vector.dot(delta, forward)))
        if angle >= 180 then angle = angle - 360 end
        return angle
    end

    local function transmission(observer, source)
        local delta = vector.subtract(source, observer)
        local distance = vector.length(delta)
        local direction = vector.normalize(delta)
        local source_node = vector.round(source)
        local factor, previous_node_key = 1, nil
        for index = 1, math.min(128, math.ceil(distance / 0.5)) do
            local position = vector.round(vector.add(observer, vector.multiply(direction, index * 0.5)))
            if position.x == source_node.x and position.y == source_node.y and
                    position.z == source_node.z then return factor end
            local key = string.format("%d:%d:%d", position.x, position.y, position.z)
            if key ~= previous_node_key then
                local node = core.get_node_or_nil(position)
                if not node or node.name == "ignore" then return nil end
                if node.name == "rdl_bridge:opaque_wall" then
                    factor = factor * 0.5
                elseif node.name ~= "air" and node.name ~= "rdl_bridge:observation_space" then
                    return nil
                end
                previous_node_key = key
            end
        end
        return nil
    end

    local function emit_world_sound(event)
        local start_us = window_start(event.occurred_us)
        for agent_id, agent in pairs(agents) do
            local path_factor = transmission(agent.position, event.position)
            if not path_factor or #agent.buffer >= BUFFER_LIMIT then
                agent.incomplete[start_us] = true
            else
                local distance = vector.distance(agent.position, event.position)
                local attenuation = 1 / (1 + (distance / 4) ^ 2)
                local angle_interval = quantized_interval(
                    local_azimuth(agent, event.position), agent.profile.audition.direction_bin_deg)
                local pose_ref = agent_id .. ":ear-pose:" .. agent.pose_revision
                table.insert(agent.buffer, {
                    window_start_us = start_us,
                    received_start_us = event.occurred_us,
                    received_end_us = event.occurred_us + event.duration_us,
                    observer_frame_ref = pose_ref,
                    cell_key = string.format("%d:%d:%s", angle_interval[1], angle_interval[2], pose_ref),
                    azimuth_interval_deg = angle_interval,
                    low = event.band_energy.low * attenuation * path_factor,
                    mid = event.band_energy.mid * attenuation * path_factor,
                    high = event.band_energy.high * attenuation * path_factor,
                })
            end
        end
    end

    local function strength_band(value)
        if value < 0.2 then return "weak" end
        if value < 0.6 then return "medium" end
        return "strong"
    end

    local function dominant_band(low, mid, high)
        local maximum = math.max(low, mid, high)
        local count = (low == maximum and 1 or 0) + (mid == maximum and 1 or 0) +
            (high == maximum and 1 or 0)
        if count ~= 1 then return "mixed" end
        if low == maximum then return "low" end
        if mid == maximum then return "mid" end
        return "high"
    end

    local function close_window(agent_id, start_us)
        local agent, cells, retained = agents[agent_id], {}, {}
        for _, receipt in ipairs(agent.buffer) do
            if receipt.window_start_us == start_us then
                local cell = cells[receipt.cell_key]
                if not cell then
                    cell = {
                        received_start_us = receipt.received_start_us,
                        received_end_us = receipt.received_end_us,
                        observer_frame_ref = receipt.observer_frame_ref,
                        azimuth_interval_deg = receipt.azimuth_interval_deg,
                        low = 0, mid = 0, high = 0,
                    }
                    cells[receipt.cell_key] = cell
                end
                cell.received_start_us = math.min(cell.received_start_us, receipt.received_start_us)
                cell.received_end_us = math.max(cell.received_end_us, receipt.received_end_us)
                cell.low, cell.mid, cell.high = cell.low + receipt.low,
                    cell.mid + receipt.mid, cell.high + receipt.high
            else
                table.insert(retained, receipt)
            end
        end
        agent.buffer = retained

        local detections, keys = {}, {}
        for key in pairs(cells) do table.insert(keys, key) end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local cell = cells[key]
            local low = math.min(1, cell.low * agent.profile.audition.gain)
            local mid = math.min(1, cell.mid * agent.profile.audition.gain)
            local high = math.min(1, cell.high * agent.profile.audition.gain)
            local maximum = math.max(low, mid, high)
            local threshold = math.max(agent.profile.audition.detection_threshold,
                agent.profile.audition.noise_floor * agent.profile.audition.noise_ratio)
            if maximum >= threshold and #detections < 8 then
                table.insert(detections, {
                    detection_id = "d" .. tostring(#detections),
                    received_interval_us = {cell.received_start_us, cell.received_end_us},
                    observer_frame_ref = cell.observer_frame_ref,
                    azimuth_interval_deg = cell.azimuth_interval_deg,
                    elevation_band = "level", received_strength_band = strength_band(maximum),
                    dominant_band = dominant_band(low, mid, high), temporal_form = "brief",
                })
            end
        end

        local incomplete = agent.incomplete[start_us] == true
        agent.incomplete[start_us] = nil
        local sequence = #agent.frames + 1
        table.insert(agent.frames, {
            frame_id = string.format("fixture-run-1:1:%s:ears:audition:%d", agent_id, sequence),
            agent_id = agent_id, sensor_id = "ears", channel = "audition",
            profile_id = agent.profile.profile_id, profile_revision = agent.profile.profile_revision,
            sensor_model_revision = "direct_band_energy_v0", sample_seq = sequence,
            clock_id = "world-sim-v1",
            capture_window = {kind = "interval", start_us = start_us, end_us = start_us + WINDOW_US},
            sampled_world_tick = sequence,
            observer_frame_ref = agent_id .. ":ear-window:" .. tostring(sequence),
            status = "SAMPLED", coverage = incomplete and "PARTIAL" or "COMPLETE_WITHIN_PLAN",
            output_limited = incomplete, payload = {detections = detections},
        })
    end

    local function packet_for(agent_id)
        local observation_id = "luanti-audition-000003-" .. agent_id
        return {
            schema_version = "rdl-luanti-observation-v1", observation_id = observation_id,
            tick = 3, agent_id = agent_id,
            observation = {
                perception_rule = "audition receive-window fixture; no legacy targets",
                visible_agents = {}, visible_objects = {}, visible_places = {},
                visible_regions = {}, recent_events = {}, external_statements = {},
                sensory_extension = {
                    schema_version = "rdl-sensory-extension-v1", run_id = "fixture-run-1",
                    world_epoch = 1, agent_id = agent_id,
                    delivery_observation_id = observation_id, delivery_world_tick = 3,
                    delivery_time_us = 750000, frames = agents[agent_id].frames,
                },
            },
            adapter = {backend = "luanti", version = "rdl-luanti-audition-v0.2",
                       authority = "finite-world-observation-only"},
        }
    end

    local function send(agent_ids, index)
        if index > #agent_ids then return end
        local agent_id = agent_ids[index]
        local body = core.write_json(packet_for(agent_id))
        for _, field in ipairs({"visible_agents", "visible_objects", "visible_places",
                                "visible_regions", "recent_events", "external_statements", "detections"}) do
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
                    "[RDL_LUANTI_OBS4B] delivered agent=%s frames=%d delayed=true",
                    agent_id, #agents[agent_id].frames))
                send(agent_ids, index + 1)
            end)
    end

    local function sound_event(time_us, energy)
        return {
            occurred_us = time_us, duration_us = 10000, position = table.copy(source_position),
            band_energy = {low = 0, mid = energy, high = 0},
        }
    end

    local function ensure_fixture()
        local vm = VoxelManip()
        local min_edge, max_edge = vm:read_from_map({x = -1, y = 1, z = 0}, {x = 1, y = 1, z = 4})
        local area = VoxelArea:new({MinEdge = min_edge, MaxEdge = max_edge})
        local data = vm:get_data()
        local open_id = core.get_content_id("rdl_bridge:observation_space")
        local wall_id = core.get_content_id("rdl_bridge:opaque_wall")
        for x = -1, 1 do
            for z = 0, 4 do data[area:index(x, 1, z)] = open_id end
        end
        data[area:index(0, 1, 2)], data[area:index(1, 1, 2)] = wall_id, wall_id
        data[area:index(0, 1, 4)] = core.get_content_id("rdl_bridge:distant_red")
        vm:set_data(data)
        vm:write_to_map()
        vm:update_map()

        core.after(0.05, function() emit_world_sound(sound_event(100000, 0.3)) end)
        core.after(0.10, function()
            emit_world_sound(sound_event(110000, 0.3))
            core.set_node(source_position, {name = "rdl_bridge:observation_space"})
        end)
        core.after(0.15, function()
            agents.npc_a.yaw, agents.npc_b.yaw = math.pi, math.pi
            agents.npc_a.pose_revision, agents.npc_b.pose_revision = "after-turn", "after-turn"
        end)
        core.after(0.20, function()
            close_window("npc_a", 0)
            close_window("npc_b", 0)
        end)
        core.after(0.25, function()
            for index = 1, 33 do
                emit_world_sound(sound_event(250000 + index - 1, 0.01))
            end
        end)
        core.after(0.35, function()
            close_window("npc_a", 250000)
            close_window("npc_b", 250000)
        end)
        core.after(0.60, function() send({"npc_a", "npc_b"}, 1) end)
    end

    core.register_on_mods_loaded(function()
        core.forceload_block({x = 0, y = 0, z = 0}, true)
        core.after(0, ensure_fixture)
    end)
end
