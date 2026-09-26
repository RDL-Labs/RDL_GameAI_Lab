local http = core.request_http_api()
if not http then
    error("rdl_bridge requires secure.http_mods = rdl_bridge")
end

local runtime_url = core.settings:get("rdl_runtime_url") or "http://127.0.0.1:8765/v1/observe"
local interval = tonumber(core.settings:get("rdl_bridge_interval")) or 0.25
local max_visible = 16
local observation_radius = 12
local reach_distance = 1.25

local state = {
    tick = 0,
    elapsed = 0,
    in_flight = false,
    revision = 0,
    held_food_ids = {},
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
        return
    end
    local npc = find_entity("rdl_bridge:npc")
    if not npc then
        npc = core.add_entity({x = 0, y = 1, z = 0}, "rdl_bridge:npc", "npc_a")
    end
    local food = find_entity("rdl_bridge:food")
    if not food and #state.held_food_ids == 0 then
        food = core.add_entity({x = 4, y = 1, z = 0}, "rdl_bridge:food", "ordinary_food_1")
    end
    if npc and food then
        state.fixture_ready = true
        push_event("fixture_ready", {agent_id = "npc_a", object_id = "ordinary_food_1"})
        core.log("action", "[rdl_bridge] L0 fixture ready")
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
    local visible_objects = {}
    for _, object in ipairs(core.get_objects_inside_radius(npc_pos, observation_radius)) do
        local entity = object:get_luaentity()
        if entity and entity.name == "rdl_bridge:food" and #visible_objects < max_visible then
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
            })
        end
    end
    table.sort(visible_objects, function(left, right) return left.id < right.id end)
    return {
        schema_version = "rdl-luanti-observation-v1",
        observation_id = string.format("luanti-%06d-npc_a", state.tick),
        tick = state.tick,
        agent_id = "npc_a",
        observation = {
            perception_rule = "structured radius <= 12; visible entities <= 16",
            visible_agents = {},
            visible_objects = visible_objects,
            visible_places = {},
            visible_regions = {},
            inventory = {held_food_ids = table.copy(state.held_food_ids)},
            recent_events = table.copy(state.recent_events),
            body = {
                agent_id = "npc_a",
                snapshot_id = string.format("luanti-body-%06d", state.tick),
                revision = state.revision,
                movement_scale = 1.0,
                injury_level = "none",
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

local function target_object(target_id)
    local object, entity = find_entity("rdl_bridge:food")
    if entity and entity.rdl_id == target_id then
        return object, entity
    end
    return nil, nil
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
    else
        push_event("action_rejected", {action = action_type, reason = "unsupported_L0_L2_action"})
    end
end

local function exchange()
    if state.in_flight then
        return
    end
    ensure_fixture()
    local packet = build_observation()
    if not packet then
        return
    end
    local body, error_message = core.write_json(packet)
    if not body then
        core.log("error", "[rdl_bridge] observation serialization failed: " .. tostring(error_message))
        return
    end
    -- Luanti encodes an empty Lua table as an object. These schema fields are
    -- always arrays, so preserve their JSON type when the bounded set is empty.
    for _, field in ipairs({
        "visible_agents", "visible_objects", "visible_places", "visible_regions",
        "recent_events", "held_food_ids",
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
    core.after(0, ensure_fixture)
end)

core.register_globalstep(function(dtime)
    state.elapsed = state.elapsed + dtime
    if state.elapsed >= interval then
        state.elapsed = state.elapsed - interval
        exchange()
    end
end)
