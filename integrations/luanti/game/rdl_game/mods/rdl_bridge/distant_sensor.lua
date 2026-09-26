local M = {}

local function interval(value, width)
    local lower = math.floor(value / width) * width
    return {lower, lower + width}
end

local function blocked(eye, target)
    local delta = vector.subtract(target, eye)
    local distance, direction = vector.length(delta), vector.normalize(delta)
    local target_node = vector.round(target)
    for index = 1, math.min(128, math.ceil(distance / 0.5)) do
        local position = vector.round(vector.add(eye, vector.multiply(direction, index * 0.5)))
        if position.x == target_node.x and position.y == target_node.y and
                position.z == target_node.z then return false end
        local node = core.get_node_or_nil(position)
        if not node or node.name == "ignore" then return nil end
        if node.name ~= "air" and node.name ~= "rdl_bridge:observation_space" then return true end
    end
    return false
end

function M.sample(npc, profile, candidates)
    local eye = vector.add(npc:get_pos(), {x = 0, y = 0.5, z = 0})
    local forward = core.yaw_to_dir(npc:get_yaw() or 0)
    local right, up = {x = forward.z, y = 0, z = -forward.x}, {x = 0, y = 1, z = 0}
    local features, partial, limited = {}, false, false
    for _, candidate in ipairs(candidates) do
        local node = core.get_node_or_nil(vector.round(candidate.position))
        if not node or node.name == "ignore" then
            partial = true
        elseif node.name == candidate.node_name then
            local delta = vector.subtract(candidate.position, eye)
            local distance = vector.length(delta)
            local horizontal = math.sqrt(vector.dot(delta, forward) ^ 2 + vector.dot(delta, right) ^ 2)
            local azimuth = math.deg(math.atan2(vector.dot(delta, right), vector.dot(delta, forward)))
            local elevation = math.deg(math.atan2(vector.dot(delta, up), horizontal))
            if distance > profile.range_min_exclusive and distance <= profile.range_max_inclusive and
                    math.abs(azimuth) <= profile.horizontal_fov_deg / 2 and
                    math.abs(elevation) <= profile.vertical_fov_deg / 2 then
                local occluded = blocked(eye, candidate.position)
                if occluded == nil then partial = true
                elseif not occluded then
                    if #features < 4 then
                        table.insert(features, {
                            feature_id = "f" .. tostring(#features),
                            azimuth_interval_deg = interval(azimuth, profile.angle_bin_deg),
                            elevation_interval_deg = interval(elevation, profile.angle_bin_deg),
                            angular_width_band = "unknown", angular_height_band = "unknown",
                            color_band = candidate.color_band,
                        })
                    else limited = true end
                end
            end
        end
    end
    return features, partial or limited, limited
end

return M
