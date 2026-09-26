return function(http, runtime_url, life_result_url, interval, profile_assignments,
                sensor_profile_probe, obs6_sensory)
    local reach_distance = 1.25
    local agents = {
        npc_a = {start = {x = 0, y = 1, z = -3}, food_id = "food_a",
                 food_pos = {x = 4, y = 1, z = -3}, base_id = "base_a",
                 base_pos = {x = 0, y = 1, z = -3}},
        npc_b = {start = {x = 0, y = 1, z = 3}, food_id = "food_b",
                 food_pos = {x = 4, y = 1, z = 3}, base_id = "base_b",
                 base_pos = {x = 0, y = 1, z = 3}},
    }
    local state = {tick = 0, elapsed = 0, ready = false, evidence_logged = false}
    local sensory_probe_complete = false
    local sensory_rejection_probe_sent = false
    local sensory_transport_probe_sent = false
    local sensory_response_loss_sent = false
    local visibility_markers = {
        {id = "boundary_agent", position = {x = 13.25, y = 1, z = -3}},
        {id = "outside_agent", position = {x = 13.5, y = 1, z = -3}},
    }
    if sensor_profile_probe then
        table.insert(visibility_markers, {
            id = "profile_probe_agent", position = {x = 10.7894, y = 1, z = 0},
        })
    end
    for _, config in pairs(agents) do
        config.in_flight = false
        config.revision = 0
        config.held_food_ids = {}
        config.picked_up = false
        config.base_food_stock = 0
        config.deposited = false
        config.result_in_flight = false
        config.result_accepted = false
    end
    for agent_id, config in pairs(agents) do
        config.sensor_profile = profile_assignments[agent_id]
    end
    local sensory = nil
    if obs6_sensory then
        sensory = dofile(core.get_modpath("rdl_bridge") .. "/life_sensory.lua").new(
            profile_assignments, interval)
    end

    local function rounded(value)
        return math.floor(value * 1000 + 0.5) / 1000
    end

    local function vector_packet(position)
        return {x = rounded(position.x), y = rounded(position.y), z = rounded(position.z)}
    end

    local function find_by_id(entity_name, rdl_id)
        for _, object in ipairs(core.get_objects_inside_radius({x = 2, y = 1, z = 0}, 32)) do
            local entity = object:get_luaentity()
            if entity and entity.name == entity_name and entity.rdl_id == rdl_id then
                return object, entity
            end
        end
        return nil, nil
    end

    local function ensure_fixture()
        if sensory then sensory:initialize_world() end
        local all_ready = true
        for agent_id, config in pairs(agents) do
            if not find_by_id("rdl_bridge:npc", agent_id) then
                core.add_entity(config.start, "rdl_bridge:npc", agent_id)
                all_ready = false
            end
            if not config.picked_up and not find_by_id("rdl_bridge:food", config.food_id) then
                core.add_entity(config.food_pos, "rdl_bridge:food", config.food_id)
                all_ready = false
            end
            if not find_by_id("rdl_bridge:base", config.base_id) then
                core.add_entity(config.base_pos, "rdl_bridge:base", config.base_id)
                all_ready = false
            end
        end
        for _, marker in ipairs(visibility_markers) do
            if not find_by_id("rdl_bridge:npc", marker.id) then
                core.add_entity(marker.position, "rdl_bridge:npc", marker.id)
                all_ready = false
            end
        end
        if not state.ready and all_ready then
            state.ready = true
            core.log("action", "[RDL_LUANTI_MULTI] fixture_ready agents=2")
        end
        if sensory and all_ready and not sensory_probe_complete then
            local npcs = {npc_a = find_by_id("rdl_bridge:npc", "npc_a"),
                          npc_b = find_by_id("rdl_bridge:npc", "npc_b")}
            sensory_probe_complete = sensory:verify_world_changes(npcs)
        end
    end

    local function build_observation(agent_id, config)
        local npc = find_by_id("rdl_bridge:npc", agent_id)
        if not npc then return nil end
        local npc_pos = npc:get_pos()
        local observation_radius = config.sensor_profile.vision_local.radius
        local visible_agents = {}
        local function append_visible_agent(other_id, other)
            local delta = vector.subtract(other:get_pos(), npc_pos)
            local distance = vector.length(delta)
            if distance <= observation_radius then
                table.insert(visible_agents, {
                    id = other_id,
                    relative_position = vector_packet(delta),
                    distance = rounded(distance),
                    within_reach = distance <= reach_distance,
                })
            end
        end
        for other_id, _ in pairs(agents) do
            if other_id ~= agent_id then
                local other = find_by_id("rdl_bridge:npc", other_id)
                if other then
                    append_visible_agent(other_id, other)
                end
            end
        end
        for _, marker in ipairs(visibility_markers) do
            local object = find_by_id("rdl_bridge:npc", marker.id)
            if object then append_visible_agent(marker.id, object) end
        end
        local visible_objects = {}
        local food = find_by_id("rdl_bridge:food", config.food_id)
        if food then
            local delta = vector.subtract(food:get_pos(), npc_pos)
            local distance = vector.length(delta)
            if distance <= observation_radius then
                table.insert(visible_objects, {
                    id = config.food_id,
                    kind = "food",
                    relative_position = vector_packet(delta),
                    distance = rounded(distance),
                    distance_band = distance <= reach_distance and "within_reach" or "visible",
                    within_reach = distance <= reach_distance,
                    motion = "stationary",
                })
            end
        end
        local visible_places = {}
        local base = find_by_id("rdl_bridge:base", config.base_id)
        local at_base = false
        if base then
            local delta = vector.subtract(base:get_pos(), npc_pos)
            local distance = vector.length(delta)
            at_base = distance <= reach_distance
            if distance <= observation_radius then
                table.insert(visible_places, {
                    id = config.base_id,
                    kind = "base",
                    relative_position = vector_packet(delta),
                    distance = rounded(distance),
                    within_reach = at_base,
                })
            end
        end
        local stock_band = config.base_food_stock > 0 and "enough" or "low"
        local cue = nil
        if stock_band == "low" then
            cue = {
                cue_id = "luanti-multi-base-food-low-" .. agent_id,
                source = "system_assessment",
                topic = "base_food",
                band = "low",
                delivery = "morning",
            }
        end
        local packet = {
            schema_version = "rdl-luanti-observation-v1",
            observation_id = string.format("luanti-multi-%06d-%s", state.tick, agent_id),
            tick = state.tick,
            agent_id = agent_id,
            observation = {
                perception_rule = "multi-agent finite life fixture; assigned Food/Base only; radius <= 12",
                visible_agents = visible_agents,
                visible_objects = visible_objects,
                visible_places = visible_places, visible_regions = {}, recent_events = {},
                inventory = {held_food_ids = table.copy(config.held_food_ids)},
                external_statements = {},
                life_context = {
                    god_statue_cue = cue,
                    observed_base_food_band = stock_band,
                    known_base = {id = config.base_id},
                    at_base = at_base,
                    interrupt_candidates = {},
                },
                body = {
                    agent_id = agent_id,
                    snapshot_id = string.format("luanti-multi-body-%06d-%s", state.tick, agent_id),
                    revision = config.revision,
                    movement_scale = 1.0,
                    injury_level = "none", incapacitated = false,
                    carried_agent_id = "", last_rescue_delivery = {},
                    recovery_stage = "none", recovery_steps = 0, recovery_place_id = "",
                    food_actions_enabled = true, food_need = 0.8,
                    held_food_ids = table.copy(config.held_food_ids),
                },
            },
            adapter = {
                backend = "luanti", version = "rdl-luanti-multi-agent-life-adapter-v1",
                authority = "finite-world-observation-only",
            },
        }
        local delay_probe = sensory and agent_id == "npc_b" and
            state.tick >= 1 and state.tick <= 4
        if sensory and not delay_probe then
            sensory:attach(packet, agent_id, npc,
                #visible_agents + #visible_objects + #visible_places, state.tick)
            if agent_id == "npc_a" and state.tick == 1 and
                    not sensory_rejection_probe_sent then
                packet.observation.sensory_extension.delivery_world_tick = state.tick + 1
                sensory_rejection_probe_sent = true
            end
        end
        return packet
    end

    local function report_life_result(agent_id, config, response)
        if config.result_in_flight or config.result_accepted then return end
        local inspection = response.inspection or {}
        local life = inspection.life or {}
        local cue = life.cue or {}
        local payload = {
            result_id = string.format("luanti-multi-deposit-%06d-%s", state.tick, agent_id),
            agent_id = agent_id,
            source_observation_id = inspection.observation_id,
            cue_id = cue.cue_id,
            response = "follow",
            outcome = "replenish_success",
        }
        config.result_in_flight = true
        http.fetch({
            url = life_result_url, method = "POST", timeout = 3,
            extra_headers = {"Content-Type: application/json"},
            data = core.write_json(payload),
        }, function(result)
            config.result_in_flight = false
            if result.succeeded and result.code == 200 then
                config.result_accepted = true
                core.log("action", "[RDL_LUANTI_MULTI_LIFE_EVIDENCE] deposit agent=" .. agent_id ..
                    " base=" .. config.base_id .. " accepted=true")
                if not state.evidence_logged and agents.npc_a.result_accepted and agents.npc_b.result_accepted then
                    state.evidence_logged = true
                    core.log("action", "[RDL_LUANTI_MULTI_LIFE_EVIDENCE] complete agents=2 results=2")
                end
            else
                core.log("error", "[rdl_bridge] multi life result rejected " ..
                    tostring(result.code) .. " agent=" .. agent_id .. ": " .. tostring(result.data))
            end
        end)
    end

    local function resolve_action(agent_id, config, response)
        local npc = find_by_id("rdl_bridge:npc", agent_id)
        local action = response and response.action
        if not npc or type(action) ~= "table" then return end
        if action.type == "approach" and
                (action.target_id == config.food_id or action.target_id == config.base_id) then
            local entity_name = action.target_id == config.food_id and "rdl_bridge:food" or "rdl_bridge:base"
            local target = find_by_id(entity_name, action.target_id)
            if not target then return end
            local delta = vector.subtract(target:get_pos(), npc:get_pos())
            local distance = vector.length(delta)
            npc:set_yaw(core.dir_to_yaw(vector.normalize(delta)))
            if distance > reach_distance then
                local step = math.min(1.0, distance - reach_distance)
                npc:set_pos(vector.add(npc:get_pos(), vector.multiply(vector.normalize(delta), step)))
                config.revision = config.revision + 1
            end
            core.log("action", "[RDL_LUANTI_MULTI] approach agent=" .. agent_id ..
                " target=" .. action.target_id)
            if sensory then
                local npcs = {
                    npc_a = find_by_id("rdl_bridge:npc", "npc_a"),
                    npc_b = find_by_id("rdl_bridge:npc", "npc_b"),
                }
                sensory:record_action_sound(agent_id, npcs, state.tick)
            end
        elseif action.type == "pickup" and action.target_id == config.food_id then
            local food = find_by_id("rdl_bridge:food", config.food_id)
            if food and vector.distance(npc:get_pos(), food:get_pos()) <= reach_distance then
                food:remove()
                table.insert(config.held_food_ids, config.food_id)
                config.picked_up = true
                config.revision = config.revision + 1
                core.log("action", "[RDL_LUANTI_MULTI_EVIDENCE] pickup agent=" .. agent_id ..
                    " target=" .. config.food_id)
            end
        elseif action.type == "deposit" and action.target_id == config.base_id then
            local base = find_by_id("rdl_bridge:base", config.base_id)
            if base and #config.held_food_ids > 0 and
                    vector.distance(npc:get_pos(), base:get_pos()) <= reach_distance then
                config.held_food_ids = {}
                config.base_food_stock = config.base_food_stock + 1
                config.deposited = true
                config.revision = config.revision + 1
                report_life_result(agent_id, config, response)
            end
        end
    end

    local function exchange(agent_id, config)
        if config.in_flight then return end
        local packet = build_observation(agent_id, config)
        if not packet then return end
        local retrying = sensory and sensory.retry_ids[agent_id] ~= nil
        local body = core.write_json(packet)
        if not body then return end
        for _, field in ipairs({"visible_agents", "visible_objects", "visible_places",
                                "visible_regions", "recent_events", "held_food_ids",
                                "external_statements", "interrupt_candidates",
                                "features", "detections"}) do
            body = body:gsub('("' .. field .. '"%s*:%s*)null', '%1[]')
        end
        body = body:gsub('("last_rescue_delivery"%s*:%s*)null', '%1{}')
        if sensory and agent_id == "npc_a" and state.tick == 2 and
                not sensory_transport_probe_sent then
            sensory_transport_probe_sent = true
            sensory:release(agent_id)
            core.log("action", "[RDL_LUANTI_OBS6D] simulated transport failure; retained agent=npc_a")
            return
        end
        config.in_flight = true
        http.fetch({
            url = runtime_url, method = "POST", timeout = 3,
            extra_headers = {"Content-Type: application/json"}, data = body,
        }, function(result)
            config.in_flight = false
            if not result.succeeded or result.code ~= 200 then
                if sensory then sensory:release(agent_id) end
                core.log("error", "[rdl_bridge] multi Runtime response " ..
                    tostring(result.code) .. " agent=" .. agent_id .. ": " .. tostring(result.data))
                return
            end
            local response = core.parse_json(result.data)
            local receipt = response and response.sensory_receipt
            local extension = packet.observation.sensory_extension
            if sensory and agent_id == "npc_a" and not sensory_response_loss_sent and
                    receipt and receipt.accepted == true and receipt.new_frames > 0 and
                    extension.delivery_world_tick >= 3 then
                sensory_response_loss_sent = true
                -- Discard the whole response before ack or action resolution.
                sensory:lose_response(agent_id)
                sensory:probe(agent_id, "response_lost", extension.frames, receipt)
                return
            end
            if retrying then sensory:probe(agent_id, "before_ack", extension.frames, receipt) end
            if sensory then sensory:ack(agent_id, receipt) end
            if retrying then sensory:probe(agent_id, "after_ack", extension.frames, receipt) end
            resolve_action(agent_id, config, response)
        end)
    end

    core.register_on_mods_loaded(function()
        core.forceload_block({x = 0, y = 0, z = 0}, true)
        core.after(0, ensure_fixture)
    end)

    core.register_globalstep(function(dtime)
        state.elapsed = state.elapsed + dtime
        if state.elapsed < interval then return end
        state.elapsed = state.elapsed - interval
        ensure_fixture()
        exchange("npc_a", agents.npc_a)
        exchange("npc_b", agents.npc_b)
        state.tick = state.tick + 1
        if sensory then sensory:advance(state.tick) end
    end)
end
