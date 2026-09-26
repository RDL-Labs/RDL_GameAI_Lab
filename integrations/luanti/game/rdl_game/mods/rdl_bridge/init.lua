local http = core.request_http_api()
if not http then
    error("rdl_bridge requires secure.http_mods = rdl_bridge")
end

local runtime_url = core.settings:get("rdl_runtime_url") or "http://127.0.0.1:8765/v1/observe"
local life_result_url = core.settings:get("rdl_life_result_url") or "http://127.0.0.1:8765/v1/life-result"
local territory_result_url = core.settings:get("rdl_territory_result_url") or "http://127.0.0.1:8765/v1/luanti-territory-result"
local interval = tonumber(core.settings:get("rdl_bridge_interval")) or 0.25
local fixture_mode = core.settings:get("rdl_fixture_mode") or "ordinary_food"
local outcome_learning_enabled = core.settings:get_bool("rdl_outcome_learning", false)
local outcome_cycle_limit = tonumber(core.settings:get("rdl_outcome_cycle_limit")) or 1
local max_visible = 16
local observation_radius = 12
local reach_distance = 1.25

local state = {
    tick = 0,
    elapsed = 0,
    in_flight = false,
    revision = 0,
    held_food_ids = {},
    base_food_stock = 0,
    injury_level = "none",
    territory_steps = 0,
    territory_result_in_flight = false,
    territory_result_count = 0,
    tasty_food_hidden_once = false,
    recent_events = {},
    fixture_ready = false,
}

local function push_event(event_type, fields)
    local event = {
        event_type = event_type,
        tick = state.tick,
        source = "luanti-world-resolution",
    }
    for key, value in pairs(fields or {}) do
        event[key] = value
    end
    table.insert(state.recent_events, event)
    while #state.recent_events > 8 do
        table.remove(state.recent_events, 1)
    end
end

core.register_entity("rdl_bridge:npc", {
    initial_properties = {
        visual = "sprite",
        textures = {"unknown_node.png"},
        physical = true,
        collide_with_objects = true,
        pointable = false,
        static_save = false,
    },
    on_activate = function(self, staticdata)
        self.rdl_id = staticdata ~= "" and staticdata or "npc_a"
    end,
})

core.register_entity("rdl_bridge:food", {
    initial_properties = {
        visual = "sprite",
        textures = {"unknown_item.png"},
        physical = false,
        pointable = false,
        static_save = false,
    },
    on_activate = function(self, staticdata)
        self.rdl_id = staticdata ~= "" and staticdata or "ordinary_food_1"
        self.rdl_kind = "food"
    end,
})

core.register_entity("rdl_bridge:beast", {
    initial_properties = {
        visual = "sprite",
        textures = {"unknown_object.png"},
        physical = false,
        pointable = false,
        static_save = false,
    },
    on_activate = function(self, staticdata)
        self.rdl_id = staticdata ~= "" and staticdata or "beast_1"
        self.rdl_kind = "beast"
    end,
})

core.register_entity("rdl_bridge:base", {
    initial_properties = {
        visual = "sprite",
        textures = {"unknown_node.png"},
        physical = false,
        pointable = false,
        static_save = false,
    },
    on_activate = function(self, staticdata)
        self.rdl_id = staticdata ~= "" and staticdata or "base"
        self.rdl_kind = "base"
    end,
})

core.register_node("rdl_bridge:distant_dark", {
    description = "RDL Distant Dark Fixture",
    tiles = {"unknown_node.png"},
    walkable = true,
    pointable = false,
})

core.register_node("rdl_bridge:distant_red", {
    description = "RDL Distant Red Fixture",
    tiles = {"unknown_object.png"},
    walkable = true,
    pointable = false,
})

core.register_node("rdl_bridge:opaque_wall", {
    description = "RDL Opaque Wall Fixture",
    tiles = {"unknown_node.png"},
    walkable = true,
    pointable = false,
})

if fixture_mode == "multi_agent_food" then
    local sensor_profiles = dofile(core.get_modpath("rdl_bridge") .. "/sensor_profiles.lua")
    local profile_assignments = sensor_profiles.load(core.settings, {"npc_a", "npc_b"})
    local start_multi_agent = dofile(core.get_modpath("rdl_bridge") .. "/multi_agent_food.lua")
    start_multi_agent(http, runtime_url, life_result_url, interval, profile_assignments,
        core.settings:get_bool("rdl_sensor_profile_probe", false))
    return
end

if fixture_mode == "distant_observation" then
    local sensor_profiles = dofile(core.get_modpath("rdl_bridge") .. "/sensor_profiles.lua")
    local profile_assignments = sensor_profiles.load(core.settings, {"npc_a"})
    local start_distant = dofile(core.get_modpath("rdl_bridge") .. "/distant_observation.lua")
    start_distant(http, runtime_url, interval, profile_assignments.npc_a)
    return
end

local function find_entity(name)
    for _, object in ipairs(core.get_objects_inside_radius({x = 0, y = 1, z = 0}, 64)) do
        local entity = object:get_luaentity()
        if entity and entity.name == name then
            return object, entity
        end
    end
    return nil, nil
end

local function ensure_fixture()
    if state.fixture_ready then
        local npc = find_entity("rdl_bridge:npc")
        if not npc then
            core.add_entity({x = 0, y = 1, z = 0}, "rdl_bridge:npc", "npc_a")
            push_event("fixture_npc_restored", {agent_id = "npc_a"})
        end
        local food = find_entity("rdl_bridge:food")
        if not food and #state.held_food_ids == 0 and not state.tasty_food_hidden_once then
            local food_id = fixture_mode == "risky_tasty" and "tasty_food" or "ordinary_food_1"
            local position = fixture_mode == "risky_tasty" and {x = 8, y = 1, z = 0} or {x = 4, y = 1, z = 0}
            core.add_entity(position, "rdl_bridge:food", food_id)
            push_event("fixture_food_restored", {object_id = food_id})
        end
        if not find_entity("rdl_bridge:base") then
            core.add_entity({x = 0, y = 1, z = 0}, "rdl_bridge:base", "base")
        end
        if fixture_mode == "risky_tasty" and not find_entity("rdl_bridge:beast") then
            core.add_entity({x = 8, y = 1, z = 0}, "rdl_bridge:beast", "beast_1")
        end
        return
    end
    local npc = find_entity("rdl_bridge:npc")
    if not npc then
        npc = core.add_entity({x = 0, y = 1, z = 0}, "rdl_bridge:npc", "npc_a")
    end
    local food_id = fixture_mode == "risky_tasty" and "tasty_food" or "ordinary_food_1"
    local food_position = fixture_mode == "risky_tasty" and {x = 8, y = 1, z = 0} or {x = 4, y = 1, z = 0}
    local food = find_entity("rdl_bridge:food")
    if not food and #state.held_food_ids == 0 then
        food = core.add_entity(food_position, "rdl_bridge:food", food_id)
    end
    local base = find_entity("rdl_bridge:base")
    if not base then
        base = core.add_entity({x = 0, y = 1, z = 0}, "rdl_bridge:base", "base")
    end
    local beast = true
    if fixture_mode == "risky_tasty" then
        beast = find_entity("rdl_bridge:beast")
        if not beast then
            beast = core.add_entity({x = 8, y = 1, z = 0}, "rdl_bridge:beast", "beast_1")
        end
    end
    if npc and food and base and beast then
        state.fixture_ready = true
        push_event("fixture_ready", {agent_id = "npc_a", object_id = food_id})
        core.log("action", "[rdl_bridge] fixture ready mode=" .. fixture_mode)
    end
end

local function rounded(value)
    return math.floor(value * 1000 + 0.5) / 1000
end

local function vector_packet(position)
    return {x = rounded(position.x), y = rounded(position.y), z = rounded(position.z)}
end

local function build_observation()
    local npc, npc_entity = find_entity("rdl_bridge:npc")
    if not npc or not npc_entity then
        return nil
    end
    local npc_pos = npc:get_pos()
    local base, base_entity = find_entity("rdl_bridge:base")
    local visible_objects = {}
    for _, object in ipairs(core.get_objects_inside_radius(npc_pos, observation_radius)) do
        local entity = object:get_luaentity()
        if entity and entity.name == "rdl_bridge:food" and #visible_objects < max_visible
                and not (state.tasty_food_hidden_once and entity.rdl_id == "tasty_food") then
            local position = object:get_pos()
            local distance = vector.distance(npc_pos, position)
            table.insert(visible_objects, {
                id = entity.rdl_id,
                kind = entity.rdl_kind,
                relative_position = vector_packet(vector.subtract(position, npc_pos)),
                distance = rounded(distance),
                distance_band = distance <= reach_distance and "within_reach" or "visible",
                within_reach = distance <= reach_distance,
                motion = "stationary",
                desirability_fixture = entity.rdl_id == "tasty_food" and "HIGH" or "NORMAL",
                territory_id = entity.rdl_id == "tasty_food" and "north_grove" or nil,
            })
        end
    end
    if fixture_mode == "risky_tasty" then
        local beast, beast_entity = find_entity("rdl_bridge:beast")
        if beast and beast_entity and #visible_objects < max_visible then
            local position = beast:get_pos()
            local distance = vector.distance(npc_pos, position)
            if distance <= observation_radius then
                table.insert(visible_objects, {
                    id = beast_entity.rdl_id,
                    kind = beast_entity.rdl_kind,
                    relative_position = vector_packet(vector.subtract(position, npc_pos)),
                    distance = rounded(distance),
                    motion = "stationary",
                })
            end
        end
    end
    table.sort(visible_objects, function(left, right) return left.id < right.id end)
    local visible_places = {}
    local at_base = false
    if base and base_entity then
        local base_distance = vector.distance(npc_pos, base:get_pos())
        at_base = base_distance <= reach_distance
        if base_distance <= observation_radius then
            table.insert(visible_places, {
                id = base_entity.rdl_id,
                kind = base_entity.rdl_kind,
                relative_position = vector_packet(vector.subtract(base:get_pos(), npc_pos)),
                distance = rounded(base_distance),
                within_reach = at_base,
            })
        end
    end
    local stock_band = state.base_food_stock > 0 and "enough" or "low"
    local cue = nil
    if stock_band == "low" then
        cue = {
            cue_id = "luanti-morning-base-food-low-1",
            source = "system_assessment",
            topic = "base_food",
            band = "low",
            delivery = "morning",
        }
    end
    return {
        schema_version = "rdl-luanti-observation-v1",
        observation_id = string.format("luanti-%06d-npc_a", state.tick),
        tick = state.tick,
        agent_id = "npc_a",
        observation = {
            perception_rule = "structured radius <= 12; visible entities <= 16",
            visible_agents = {},
            visible_objects = visible_objects,
            visible_places = visible_places,
            visible_regions = fixture_mode == "risky_tasty" and {{
                id = "north_grove",
                relation = "contains",
                object_id = "tasty_food",
                distance_band = "visible",
            }} or {},
            inventory = {held_food_ids = table.copy(state.held_food_ids)},
            recent_events = table.copy(state.recent_events),
            external_statements = fixture_mode == "risky_tasty" and {{
                statement_id = "god-statue-tasty-food-v1",
                schema = "external-value-statement-v1",
                source_type = "external_statement",
                source_id = "god_statue",
                subject_id = "tasty_food",
                predicate = "tasty",
                polarity = "positive",
                value_band = "HIGH",
                authority = "source-attributed-information; not-World-Truth-M_B-H-or-action",
            }} or {},
            life_context = {
                god_statue_cue = cue,
                observed_base_food_band = stock_band,
                known_base = {id = "base"},
                at_base = at_base,
                interrupt_candidates = {},
            },
            body = {
                agent_id = "npc_a",
                snapshot_id = string.format("luanti-body-%06d", state.tick),
                revision = state.revision,
                movement_scale = 1.0,
                injury_level = state.injury_level,
                incapacitated = false,
                carried_agent_id = "",
                last_rescue_delivery = {},
                recovery_stage = "none",
                recovery_steps = 0,
                recovery_place_id = "",
                food_actions_enabled = true,
                food_need = 0.8,
                held_food_ids = table.copy(state.held_food_ids),
            },
        },
        adapter = {
            backend = "luanti",
            version = "rdl-luanti-adapter-v1",
            authority = "finite-world-observation-only",
        },
    }
end

local exchange

local function report_territory_result(event)
    if state.territory_result_in_flight or state.territory_result_count >= outcome_cycle_limit then
        return
    end
    local payload = {
        event = event,
        outcome_facts = {
            food_acquired = false,
            returned_to_base = false,
            injury_level = "medium",
            reward_value = "ZERO",
        },
    }
    local body, error_message = core.write_json(payload)
    if not body then
        core.log("error", "[rdl_bridge] territory result serialization failed: " .. tostring(error_message))
        return
    end
    state.territory_result_in_flight = true
    http.fetch({
        url = territory_result_url,
        method = "POST",
        timeout = 3,
        extra_headers = {"Content-Type: application/json"},
        data = body,
    }, function(result)
        if not result.succeeded or result.code ~= 200 then
            state.territory_result_in_flight = false
            core.log("error", "[rdl_bridge] territory result response " .. tostring(result.code))
            return
        end
        state.territory_result_in_flight = false
        state.territory_result_count = state.territory_result_count + 1
        local response = core.parse_json(result.data)
        local bias_count = response and response.biases and #response.biases or 0
        core.log("action", "[RDL_LUANTI_L5_EVIDENCE] experience_gradient_bias accepted=true biases=" .. bias_count)
        core.log("action", "[rdl_bridge] outcome_cycle=" .. state.territory_result_count)
        if state.territory_result_count < outcome_cycle_limit then
            core.after(interval, exchange)
        end
    end)
end

local function resolve_territory(npc, target_id)
    if fixture_mode ~= "risky_tasty" or target_id ~= "tasty_food" then
        return
    end
    local beast = find_entity("rdl_bridge:beast")
    if not beast then
        return
    end
    local distance = vector.distance(npc:get_pos(), beast:get_pos())
    if distance > 5 then
        state.territory_steps = 0
        return
    end
    state.territory_steps = state.territory_steps + 1
    local event_type = "territory_entered"
    local response = "warning"
    local outcome = "warning_observed"
    if state.territory_steps >= 2 and distance <= 2 then
        event_type = "close_intrusion_persisted"
        response = "attack"
        outcome = "injured"
        state.injury_level = "medium"
        npc:set_pos({x = 0, y = 1, z = 0})
        state.revision = state.revision + 1
    elseif state.territory_steps >= 2 then
        event_type = "intrusion_continued"
        response = "chase"
        outcome = "chased"
    end
    local event = {
        event_id = string.format("luanti-territory-%06d", state.tick),
        schema = "territory-beast-fact-event-v1",
        tick = state.tick,
        agent_id = "npc_a",
        beast_id = "beast_1",
        territory_id = "north_grove",
        event_type = event_type,
        beast_response = response,
        proximity = distance <= 2 and "close" or "within_territory",
        outcome = outcome,
        world_consequence = response == "attack" and {
            injury_level = "medium",
            forced_retreat = true,
            incapacitated = false,
        } or nil,
        interaction_context = {
            action = "approach",
            food_id = "tasty_food",
            food_desirability_fixture = "HIGH",
            territory_id = "north_grove",
        },
        authority = "World-interaction-fact; not-danger-belief-Experience-H-theta-M_delta-or-action",
    }
    push_event("territory_fact", event)
    core.log("action", "[rdl_bridge] territory_response=" .. response .. " tick=" .. state.tick)
    if response == "attack" then
        core.log("action", "[RDL_LUANTI_L4_EVIDENCE] warning_chase_attack injury=medium forced_retreat=true tick=" .. state.tick)
        if outcome_learning_enabled then
            if state.territory_result_count + 1 < outcome_cycle_limit then
                state.tasty_food_hidden_once = true
            end
            report_territory_result(event)
        end
    end
end

local function target_object(target_id)
    for _, name in ipairs({"rdl_bridge:food", "rdl_bridge:base"}) do
        local object, entity = find_entity(name)
        if entity and entity.rdl_id == target_id then
            return object, entity
        end
    end
    return nil, nil
end

local function report_life_result(response)
    local inspection = response.inspection or {}
    local life = inspection.life or {}
    local cue = life.cue or {}
    local payload = {
        result_id = string.format("luanti-deposit-%06d-npc_a", state.tick),
        agent_id = "npc_a",
        source_observation_id = inspection.observation_id,
        cue_id = cue.cue_id,
        response = "follow",
        outcome = "replenish_success",
    }
    local body = core.write_json(payload)
    http.fetch({
        url = life_result_url,
        method = "POST",
        timeout = 3,
        extra_headers = {"Content-Type: application/json"},
        data = body,
    }, function(result)
        if result.succeeded and result.code == 200 then
            core.log("action", "[RDL_LUANTI_L3_EVIDENCE] deposit_accepted base=base tick=" .. state.tick)
        else
            core.log("error", "[rdl_bridge] life result rejected " .. tostring(result.code) .. ": " .. tostring(result.data))
        end
    end)
end

local function resolve_action(response)
    local npc = find_entity("rdl_bridge:npc")
    local action = response and response.action
    if not npc or type(action) ~= "table" or type(action.type) ~= "string" then
        push_event("action_rejected", {reason = "malformed_runtime_response"})
        return
    end
    local action_type = action.type
    local target_id = action.target_id
    if action_type == "idle" or action_type == "wait" then
        push_event("wait_resolved", {})
    elseif action_type == "turn" then
        local yaw = tonumber(action.yaw)
        if not yaw then
            push_event("action_rejected", {action = action_type, reason = "missing_yaw"})
            return
        end
        npc:set_yaw(yaw)
        push_event("turn_resolved", {yaw = yaw})
    elseif action_type == "move" then
        local direction = action.direction
        if type(direction) ~= "table" then
            push_event("action_rejected", {action = action_type, reason = "missing_direction"})
            return
        end
        local delta = vector.new(tonumber(direction.x) or 0, 0, tonumber(direction.z) or 0)
        if vector.length(delta) == 0 then
            push_event("action_rejected", {action = action_type, reason = "zero_direction"})
            return
        end
        npc:set_pos(vector.add(npc:get_pos(), vector.normalize(delta)))
        state.revision = state.revision + 1
        push_event("move_resolved", {agent_id = "npc_a"})
    elseif action_type == "approach" then
        local target = target_object(target_id)
        if not target then
            push_event("action_rejected", {action = action_type, reason = "target_not_visible"})
            return
        end
        local delta = vector.subtract(target:get_pos(), npc:get_pos())
        local distance = vector.length(delta)
        if distance > reach_distance then
            local step = math.min(1.0, distance - reach_distance)
            npc:set_pos(vector.add(npc:get_pos(), vector.multiply(vector.normalize(delta), step)))
            state.revision = state.revision + 1
        end
        push_event("approach_resolved", {target_id = target_id, distance_before = rounded(distance)})
        resolve_territory(npc, target_id)
    elseif action_type == "pickup" then
        local target = target_object(target_id)
        if not target or vector.distance(npc:get_pos(), target:get_pos()) > reach_distance then
            push_event("pickup_failed", {target_id = target_id, reason = "too_far_or_missing"})
            return
        end
        target:remove()
        table.insert(state.held_food_ids, target_id)
        state.revision = state.revision + 1
        push_event("pickup_succeeded", {target_id = target_id})
        core.log("action", "[RDL_LUANTI_EVIDENCE] pickup_succeeded target=" .. target_id .. " tick=" .. state.tick)
    elseif action_type == "deposit" then
        local target = target_object(target_id)
        if not target or target_id ~= "base" or vector.distance(npc:get_pos(), target:get_pos()) > reach_distance then
            push_event("deposit_failed", {target_id = target_id, reason = "too_far_or_missing"})
            return
        end
        if #state.held_food_ids == 0 then
            push_event("deposit_failed", {target_id = target_id, reason = "inventory_empty"})
            return
        end
        local deposited_id = table.remove(state.held_food_ids, 1)
        state.base_food_stock = state.base_food_stock + 1
        state.revision = state.revision + 1
        push_event("deposit_succeeded", {target_id = target_id, object_id = deposited_id})
        report_life_result(response)
    else
        push_event("action_rejected", {action = action_type, reason = "unsupported_L0_L2_action"})
    end
    if state.tasty_food_hidden_once and action_type == "idle" then
        state.tasty_food_hidden_once = false
        state.territory_steps = 0
        push_event("fixture_food_visible_again", {object_id = "tasty_food"})
    end
end

exchange = function()
    if state.in_flight then
        return
    end
    ensure_fixture()
    local packet = build_observation()
    if not packet then
        core.log("error", "[rdl_bridge] observation unavailable tick=" .. state.tick)
        return
    end
    local body, error_message = core.write_json(packet)
    if not body then
        core.log("error", "[rdl_bridge] observation serialization failed: " .. tostring(error_message))
        return
    end
    -- Luanti encodes an empty Lua table as null. These schema fields are always
    -- arrays, so preserve their JSON type when the bounded set is empty.
    for _, field in ipairs({
        "visible_agents", "visible_objects", "visible_places", "visible_regions",
        "recent_events", "held_food_ids", "interrupt_candidates", "external_statements",
    }) do
        body = body:gsub('(\"' .. field .. '\"%s*:%s*)null', '%1[]')
    end
    body = body:gsub('(\"last_rescue_delivery\"%s*:%s*)null', '%1{}')
    state.in_flight = true
    http.fetch({
        url = runtime_url,
        method = "POST",
        timeout = 3,
        extra_headers = {"Content-Type: application/json"},
        data = body,
    }, function(result)
        state.in_flight = false
        if not result.succeeded or result.code ~= 200 then
            push_event("runtime_unavailable", {http_code = result.code or 0})
            core.log("error", "[rdl_bridge] Runtime response " .. tostring(result.code) .. ": " .. tostring(result.data))
            return
        end
        local response = core.parse_json(result.data)
        resolve_action(response)
        state.tick = state.tick + 1
    end)
end

core.register_on_mods_loaded(function()
    core.forceload_block({x = 0, y = 0, z = 0}, true)
    core.after(0, ensure_fixture)
end)

core.register_globalstep(function(dtime)
    state.elapsed = state.elapsed + dtime
    if state.elapsed >= interval then
        state.elapsed = state.elapsed - interval
        exchange()
    end
end)
