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
    ["fixture-distant-enabled"] = {
        profile_id = "fixture-distant-enabled",
        profile_revision = 1,
        vision_local = {enabled = true, mode = "legacy_radius_v1", radius = 12},
        vision_distant = {
            enabled = true, mode = "sampled_surface_v0", range_min_exclusive = 12,
            range_max_inclusive = 64, horizontal_fov_deg = 90,
            vertical_fov_deg = 60, angle_bin_deg = 5, sample_every_world_ticks = 4,
        },
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
        if profile.vision_distant then
            assignments[agent_id].vision_distant = table.copy(profile.vision_distant)
        end
    end
    return assignments
end

return M
