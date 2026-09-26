return function(http, runtime_url, interval, profile)
    local state = {tick = 0, elapsed = 0, in_flight = false, sample_seq = 0, sim_time_us = 0}
    local candidates = {}

    local function rounded(value)
        return math.floor(value * 1000 + 0.5) / 1000
    end

    local function quantized_interval(value, width)
        local lower = math.floor(value / width) * width
        return {lower, lower + width}
    end

    local function observer_basis(npc)
        local forward = core.yaw_to_dir(npc:get_yaw() or 0)
        local right = {x = forward.z, y = 0, z = -forward.x}
        return forward, right, {x = 0, y = 1, z = 0}
    end

    local function blocked(eye, target)
        local delta = vector.subtract(target, eye)
        local distance = vector.length(delta)
        local direction = vector.normalize(delta)
        local target_node = vector.round(target)
        local steps = math.min(128, math.ceil(distance / 0.5))
        for index = 1, steps do
            local node_position = vector.round(
                vector.add(eye, vector.multiply(direction, index * 0.5)))
            if node_position.x == target_node.x and node_position.y == target_node.y and
                    node_position.z == target_node.z then
                return false
            end
            local node = core.get_node_or_nil(node_position)
            if not node or node.name == "ignore" then return nil end
            if node.name ~= "air" then return true end
        end
        return false
    end

    local function sample(npc)
        local distant = profile.vision_distant
        local eye = vector.add(npc:get_pos(), {x = 0, y = 0.5, z = 0})
        local forward, right, up = observer_basis(npc)
        local features = {}
        local partial = false
        for _, candidate in ipairs(candidates) do
            local delta = vector.subtract(candidate.position, eye)
            local distance = vector.length(delta)
            local horizontal = math.sqrt(vector.dot(delta, forward) ^ 2 + vector.dot(delta, right) ^ 2)
            local azimuth = math.deg(math.atan2(vector.dot(delta, right), vector.dot(delta, forward)))
            local elevation = math.deg(math.atan2(vector.dot(delta, up), horizontal))
            if distance > distant.range_min_exclusive and distance <= distant.range_max_inclusive and
                    math.abs(azimuth) <= distant.horizontal_fov_deg / 2 and
                    math.abs(elevation) <= distant.vertical_fov_deg / 2 then
                local occluded = blocked(eye, candidate.position)
                if occluded == nil then
                    partial = true
                elseif not occluded and #features < 4 then
                    table.insert(features, {
                        feature_id = "f" .. tostring(#features),
                        azimuth_interval_deg = quantized_interval(azimuth, distant.angle_bin_deg),
                        elevation_interval_deg = quantized_interval(elevation, distant.angle_bin_deg),
                        angular_width_band = "unknown",
                        angular_height_band = "unknown",
                        color_band = candidate.color_band,
                    })
                end
            end
        end
        return features, partial
    end

    local function build_packet(npc)
        local observation_id = string.format("luanti-distant-%06d-npc_a", state.tick)
        local packet = {
            schema_version = "rdl-luanti-observation-v1", observation_id = observation_id,
            tick = state.tick, agent_id = "npc_a",
            observation = {
                perception_rule = "distant observation fixture; no legacy targets",
                visible_agents = {}, visible_objects = {}, visible_places = {},
                visible_regions = {}, recent_events = {}, external_statements = {},
            },
            adapter = {backend = "luanti", version = "rdl-luanti-distant-v0",
                       authority = "finite-world-observation-only"},
        }
        if state.tick % profile.vision_distant.sample_every_world_ticks == 0 then
            local features, partial = sample(npc)
            if partial then
                core.log("action", "[RDL_LUANTI_OBS3] sample pending coverage=PARTIAL")
                return packet
            end
            state.sample_seq = state.sample_seq + 1
            local frame = {
                frame_id = string.format("fixture-run-1:1:npc_a:eye:vision_distant:%d", state.sample_seq),
                agent_id = "npc_a", sensor_id = "eye", channel = "vision_distant",
                profile_id = profile.profile_id, profile_revision = profile.profile_revision,
                sensor_model_revision = "sampled-surface-v0.2", sample_seq = state.sample_seq,
                clock_id = "world-sim-v1",
                capture_window = {kind = "instant", start_us = state.sim_time_us,
                                  end_us = state.sim_time_us},
                sampled_world_tick = state.tick,
                observer_frame_ref = string.format("npc_a:eye-pose:%d", state.sample_seq),
                status = "SAMPLED",
                coverage = "COMPLETE_WITHIN_PLAN",
                output_limited = false, payload = {features = features},
            }
            packet.observation.sensory_extension = {
                schema_version = "rdl-sensory-extension-v1", run_id = "fixture-run-1",
                world_epoch = 1, agent_id = "npc_a",
                delivery_observation_id = observation_id, delivery_world_tick = state.tick,
                delivery_time_us = state.sim_time_us, frames = {frame},
            }
            core.log("action", string.format(
                "[RDL_LUANTI_OBS3] sample seq=%d features=%d coverage=%s",
                state.sample_seq, #features, frame.coverage))
            if state.sample_seq == 1 then npc:set_yaw(math.pi) end
        end
        return packet
    end

    local function ensure_fixture()
        for x = -1, 3 do
            for y = 1, 2 do
                for z = 0, 13 do
                    core.set_node({x = x, y = y, z = z}, {name = "air"})
                end
            end
        end
        local npc = core.add_entity({x = 0, y = 1, z = 0}, "rdl_bridge:npc", "npc_a")
        if not npc then
            core.after(0.1, ensure_fixture)
            return
        end
        npc:set_yaw(0)
        local forward = core.yaw_to_dir(0)
        local right = {x = forward.z, y = 0, z = -forward.x}
        local dark = vector.round(vector.add({x = 0, y = 1, z = 0}, vector.multiply(forward, 13)))
        local wall = vector.round(vector.add({x = 0, y = 1, z = 0}, vector.multiply(forward, 12)))
        local red = vector.round(vector.add(
            vector.add({x = 0, y = 1, z = 0}, vector.multiply(forward, 13)),
            vector.multiply(right, 3)))
        core.set_node(dark, {name = "rdl_bridge:distant_dark"})
        core.set_node(wall, {name = "rdl_bridge:opaque_wall"})
        core.set_node(red, {name = "rdl_bridge:distant_red"})
        candidates = {
            {position = dark, color_band = "dark_gray"},
            {position = red, color_band = "muted_red"},
        }
    end

    core.register_on_mods_loaded(function()
        core.forceload_block({x = 0, y = 0, z = 0}, true)
        core.after(0, function()
            core.load_area({x = -8, y = -2, z = -2}, {x = 8, y = 4, z = 15})
            ensure_fixture()
        end)
    end)

    core.register_globalstep(function(dtime)
        state.elapsed = state.elapsed + dtime
        if state.elapsed < interval then return end
        state.elapsed = state.elapsed - interval
        state.sim_time_us = state.sim_time_us + math.floor(interval * 1000000 + 0.5)
        local npc = nil
        for _, object in ipairs(core.get_objects_inside_radius({x = 0, y = 1, z = 0}, 4)) do
            local entity = object:get_luaentity()
            if entity and entity.name == "rdl_bridge:npc" and entity.rdl_id == "npc_a" then
                npc = object
                break
            end
        end
        if npc and not state.in_flight then
            local body = core.write_json(build_packet(npc))
            for _, field in ipairs({"visible_agents", "visible_objects", "visible_places",
                                    "visible_regions", "recent_events", "external_statements",
                                    "features"}) do
                body = body:gsub('("' .. field .. '"%s*:%s*)null', '%1[]')
            end
            state.in_flight = true
            http.fetch({url = runtime_url, method = "POST", timeout = 3,
                        extra_headers = {"Content-Type: application/json"}, data = body},
                function(result)
                    state.in_flight = false
                    if not result.succeeded or result.code ~= 200 then
                        core.log("error", "[rdl_bridge] distant Runtime response " ..
                            tostring(result.code) .. ": " .. tostring(result.data))
                    end
                end)
        end
        state.tick = state.tick + 1
    end)
end
