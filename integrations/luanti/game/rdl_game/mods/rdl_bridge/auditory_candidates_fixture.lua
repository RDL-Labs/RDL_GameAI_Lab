-- OBS-7B acquisition only: no candidate algorithm or World IDs in SensorFrames.
return function(http, runtime_url, profiles)
    local path = core.get_modpath("rdl_bridge")
    local windows = dofile(path .. "/audition_window_sensor.lua").new(250000, 32, 8)
    local transmission = dofile(path .. "/audition_transmission.lua")
    local profile, frames = profiles.npc_a, {}
    local observer = {x = 0, y = 1, z = 0}
    local yaw, pose = 0, "obs7b:fixed-ear-pose"

    local function emit(time, duration, position)
        local delta = vector.subtract(position, observer)
        local forward = core.yaw_to_dir(yaw)
        local right = {x = forward.z, y = 0, z = -forward.x}
        local angle = math.deg(math.atan2(vector.dot(delta, right), vector.dot(delta, forward)))
        if angle >= 180 then angle = angle - 360 end
        local lower = math.floor(angle / 30) * 30
        local factor = transmission.factor(observer, position)
        assert(factor, "OBS7B fixture path unavailable")
        windows:emit("npc_a", {
            occurred_us = time, duration_us = duration, observer_frame_ref = pose,
            cell_key = tostring(lower) .. ":" .. pose,
            azimuth_interval_deg = {lower, lower + 30},
            low = 0, mid = 0.8 * factor / (1 + (vector.distance(observer, position) / 4) ^ 2), high = 0,
        })
    end

    local function close(start)
        local closed = windows:close("npc_a", start, profile.audition)
        local seq = #frames + 1
        frames[seq] = {
            frame_id = "obs7b:audition:" .. tostring(seq), agent_id = "npc_a",
            sensor_id = "ears", channel = "audition", profile_id = profile.profile_id,
            profile_revision = profile.profile_revision, sensor_model_revision = "direct_band_energy_v0",
            sample_seq = seq, clock_id = "world-sim-v1", sampled_world_tick = seq,
            capture_window = {kind = "interval", start_us = start, end_us = start + 250000},
            observer_frame_ref = "obs7b:window:" .. tostring(seq), status = "SAMPLED",
            coverage = closed.incomplete and "PARTIAL" or "COMPLETE_WITHIN_PLAN",
            output_limited = closed.incomplete, payload = {detections = closed.detections},
        }
    end

    local function send(batch)
        if batch > 2 then
            core.log("action", "[RDL_LUANTI_OBS7B] complete frames=8 accepted=true")
            return
        end
        local selected = {}
        for index = (batch - 1) * 4 + 1, batch * 4 do selected[#selected + 1] = frames[index] end
        local id = "obs7b-delivery-" .. tostring(batch)
        local packet = {
            schema_version = "rdl-luanti-observation-v1", observation_id = id, agent_id = "npc_a", tick = 10,
            observation = {
                perception_rule = "OBS7B fixed-ear acquisition fixture",
                visible_agents = {}, visible_objects = {}, visible_places = {}, visible_regions = {},
                recent_events = {}, external_statements = {},
                sensory_extension = {
                    schema_version = "rdl-sensory-extension-v1", run_id = "fixture-run-1", world_epoch = 1,
                    agent_id = "npc_a", delivery_observation_id = id, delivery_world_tick = 10,
                    delivery_time_us = 2000000, frames = selected,
                },
            },
        }
        local body = core.write_json(packet)
        for _, field in ipairs({"visible_agents", "visible_objects", "visible_places", "visible_regions",
                                "recent_events", "external_statements", "detections"}) do
            body = body:gsub('("' .. field .. '"%s*:%s*)null', '%1[]')
        end
        http.fetch({url = runtime_url, method = "POST", timeout = 3,
                    extra_headers = {"Content-Type: application/json"}, data = body}, function(result)
            local response = result.succeeded and result.code == 200 and core.parse_json(result.data)
            local receipt = response and response.sensory_receipt
            if not receipt or receipt.accepted ~= true or receipt.new_frames ~= 4 then
                core.log("error", "[RDL_LUANTI_OBS7B] admission failed: " .. tostring(result.data))
                return
            end
            send(batch + 1)
        end)
    end

    core.register_on_mods_loaded(function()
        core.forceload_block(observer, true)
        core.after(0, function()
            local vm = VoxelManip()
            local lo, hi = vm:read_from_map({x = -2, y = 0, z = -1}, {x = 2, y = 2, z = 5})
            local area = VoxelArea:new({MinEdge = lo, MaxEdge = hi})
            local data, open = vm:get_data(), core.get_content_id("rdl_bridge:observation_space")
            for x = -2, 2 do for y = 0, 2 do for z = -1, 5 do
                data[area:index(x, y, z)] = open
            end end end
            vm:set_data(data); vm:write_to_map(); vm:update_map()
            for scenario = 1, 4 do
                local start = (scenario - 1) * 500000
                yaw, pose = 0, "obs7b:fixed-ear-pose"
                emit(start + 245000, scenario == 3 and 5000 or 10000, {x = 0, y = 1, z = 4})
                if scenario == 1 then
                    -- A second World position mixes into the same cell. The
                    -- candidate must not claim source separation or identity.
                    emit(start + 245000, 10000, {x = 0, y = 1, z = 3})
                elseif scenario == 2 then
                    emit(start + 250000, 5000, {x = -1, y = 1, z = 4})
                elseif scenario == 4 then
                    yaw, pose = math.pi, "obs7b:turned-ear-pose"
                    emit(start + 250000, 5000, {x = 0, y = 1, z = 4})
                end
                close(start); close(start + 250000)
            end
            send(1)
        end)
    end)
end
