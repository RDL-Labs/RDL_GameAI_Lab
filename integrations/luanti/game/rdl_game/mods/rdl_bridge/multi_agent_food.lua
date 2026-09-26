return function(http, runtime_url, interval)
    local reach_distance = 1.25
    local agents = {
        npc_a = {start = {x = 0, y = 1, z = -3}, food_id = "food_a",
                 food_pos = {x = 4, y = 1, z = -3}},
        npc_b = {start = {x = 0, y = 1, z = 3}, food_id = "food_b",
                 food_pos = {x = 4, y = 1, z = 3}},
    }
    local state = {tick = 0, elapsed = 0, ready = false, evidence_logged = false}
    for _, config in pairs(agents) do
        config.in_flight = false
        config.revision = 0
        config.held_food_ids = {}
        config.picked_up = false
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
        end
        if not state.ready and all_ready then
            state.ready = true
            core.log("action", "[RDL_LUANTI_MULTI] fixture_ready agents=2")
        end
    end

    local function build_observation(agent_id, config)
        local npc = find_by_id("rdl_bridge:npc", agent_id)
        if not npc then return nil end
        local npc_pos = npc:get_pos()
        local visible_agents = {}
        for other_id, _ in pairs(agents) do
            if other_id ~= agent_id then
                local other = find_by_id("rdl_bridge:npc", other_id)
                if other then
                    local delta = vector.subtract(other:get_pos(), npc_pos)
                    table.insert(visible_agents, {
                        id = other_id,
                        relative_position = vector_packet(delta),
                        distance = rounded(vector.length(delta)),
                        within_reach = vector.length(delta) <= reach_distance,
                    })
                end
            end
        end
        local visible_objects = {}
        local food = find_by_id("rdl_bridge:food", config.food_id)
        if food then
            local delta = vector.subtract(food:get_pos(), npc_pos)
            local distance = vector.length(delta)
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
        return {
            schema_version = "rdl-luanti-observation-v1",
            observation_id = string.format("luanti-multi-%06d-%s", state.tick, agent_id),
            tick = state.tick,
            agent_id = agent_id,
            observation = {
                perception_rule = "multi-agent finite fixture; assigned food only; radius <= 12",
                visible_agents = visible_agents,
                visible_objects = visible_objects,
                visible_places = {}, visible_regions = {}, recent_events = {},
                inventory = {held_food_ids = table.copy(config.held_food_ids)},
                external_statements = {},
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
                backend = "luanti", version = "rdl-luanti-multi-agent-adapter-v1",
                authority = "finite-world-observation-only",
            },
        }
    end

    local function resolve_action(agent_id, config, response)
        local npc = find_by_id("rdl_bridge:npc", agent_id)
        local action = response and response.action
        if not npc or type(action) ~= "table" then return end
        if action.type == "approach" and action.target_id == config.food_id then
            local food = find_by_id("rdl_bridge:food", config.food_id)
            if not food then return end
            local delta = vector.subtract(food:get_pos(), npc:get_pos())
            local distance = vector.length(delta)
            if distance > reach_distance then
                local step = math.min(1.0, distance - reach_distance)
                npc:set_pos(vector.add(npc:get_pos(), vector.multiply(vector.normalize(delta), step)))
                config.revision = config.revision + 1
            end
            core.log("action", "[RDL_LUANTI_MULTI] approach agent=" .. agent_id ..
                " target=" .. config.food_id)
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
        end
        if not state.evidence_logged and agents.npc_a.picked_up and agents.npc_b.picked_up then
            state.evidence_logged = true
            core.log("action", "[RDL_LUANTI_MULTI_EVIDENCE] complete agents=2 independent_pickups=true")
        end
    end

    local function exchange(agent_id, config)
        if config.in_flight then return end
        local packet = build_observation(agent_id, config)
        if not packet then return end
        local body = core.write_json(packet)
        if not body then return end
        for _, field in ipairs({"visible_agents", "visible_objects", "visible_places",
                                "visible_regions", "recent_events", "held_food_ids",
                                "external_statements"}) do
            body = body:gsub('("' .. field .. '"%s*:%s*)null', '%1[]')
        end
        body = body:gsub('("last_rescue_delivery"%s*:%s*)null', '%1{}')
        config.in_flight = true
        http.fetch({
            url = runtime_url, method = "POST", timeout = 3,
            extra_headers = {"Content-Type: application/json"}, data = body,
        }, function(result)
            config.in_flight = false
            if not result.succeeded or result.code ~= 200 then
                core.log("error", "[rdl_bridge] multi Runtime response " ..
                    tostring(result.code) .. " agent=" .. agent_id .. ": " .. tostring(result.data))
                return
            end
            resolve_action(agent_id, config, core.parse_json(result.data))
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
    end)
end
