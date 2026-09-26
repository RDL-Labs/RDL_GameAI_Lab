local M = {}

function M.factor(observer, source)
    local delta = vector.subtract(source, observer)
    local distance, direction = vector.length(delta), vector.normalize(delta)
    local source_node, factor, previous = vector.round(source), 1, nil
    for index = 1, math.min(128, math.ceil(distance / 0.5)) do
        local position = vector.round(vector.add(observer, vector.multiply(direction, index * 0.5)))
        if position.x == source_node.x and position.y == source_node.y and
                position.z == source_node.z then return factor end
        local key = string.format("%d:%d:%d", position.x, position.y, position.z)
        if key ~= previous then
            local node = core.get_node_or_nil(position)
            if not node or node.name == "ignore" then return nil end
            if node.name == "rdl_bridge:opaque_wall" then
                factor = factor * 0.5
            elseif node.name ~= "air" and node.name ~= "rdl_bridge:observation_space" then
                return nil
            end
            previous = key
        end
    end
    return nil
end

return M
