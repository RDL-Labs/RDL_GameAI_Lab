local M = {}

local profiles = {
    ["fixture-sensor-default"] = {
        profile_id = "fixture-sensor-default",
        profile_revision = 1,
        vision_local = {enabled = true, mode = "legacy_radius_v1", radius = 12},
    },
    ["fixture-local-compact"] = {
        profile_id = "fixture-local-compact",
        profile_revision = 1,
        vision_local = {enabled = true, mode = "legacy_radius_v1", radius = 8},
    },
}

function M.load(settings, agent_ids)
    local assignments = {}
    for _, agent_id in ipairs(agent_ids) do
        local key = "rdl_sensor_profile_" .. agent_id
        local profile_id = settings:get(key) or "fixture-sensor-default"
        local profile = profiles[profile_id]
        if not profile then
            error("unknown RDL sensor profile for " .. agent_id .. ": " .. profile_id)
        end
        local radius = profile.vision_local.radius
        if type(radius) ~= "number" or radius <= 0 or radius > 64 then
            error("invalid RDL local vision radius for " .. agent_id)
        end
        assignments[agent_id] = table.copy(profile)
        assignments[agent_id].vision_local = table.copy(profile.vision_local)
    end
    return assignments
end

return M
