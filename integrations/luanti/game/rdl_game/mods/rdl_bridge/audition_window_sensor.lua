local M = {}

function M.new(window_us, buffer_limit, detection_limit)
    local state = {window_us = window_us, buffer_limit = buffer_limit,
                   detection_limit = detection_limit, agents = {}}

    local function agent_state(agent_id)
        state.agents[agent_id] = state.agents[agent_id] or
            {buffer = {}, incomplete = {}, closed = {}, late_rejections = 0}
        return state.agents[agent_id]
    end

    local function window_start(time_us)
        return math.floor(time_us / state.window_us) * state.window_us
    end

    function state:emit(agent_id, event)
        assert(event.duration_us > 0, "sound duration must be positive")
        local agent, cursor = agent_state(agent_id), event.occurred_us
        local event_end = event.occurred_us + event.duration_us
        while cursor < event_end do
            local start = window_start(cursor)
            local overlap_end = math.min(event_end, start + self.window_us)
            if agent.closed[start] then
                agent.late_rejections = agent.late_rejections + 1
            else
                local count = 0
                for _, item in ipairs(agent.buffer) do
                    if item.window_start_us == start then count = count + 1 end
                end
                if count >= self.buffer_limit then agent.incomplete[start] = true
                else
                    local receipt = table.copy(event)
                    local fraction = (overlap_end - cursor) / event.duration_us
                    receipt.window_start_us = start
                    receipt.received_start_us, receipt.received_end_us = cursor, overlap_end
                    receipt.low = event.low * fraction
                    receipt.mid = event.mid * fraction
                    receipt.high = event.high * fraction
                    table.insert(agent.buffer, receipt)
                end
            end
            cursor = overlap_end
        end
    end

    function state:mark_incomplete(agent_id, time_us)
        local agent = agent_state(agent_id)
        agent.incomplete[window_start(time_us)] = true
    end

    function state:late_rejections(agent_id)
        return agent_state(agent_id).late_rejections
    end

    function state:close(agent_id, start_us, profile)
        local agent = agent_state(agent_id)
        if agent.closed[start_us] then return agent.closed[start_us] end
        local cells, retained = {}, {}
        for _, receipt in ipairs(agent.buffer) do
            if receipt.window_start_us == start_us then
                local cell = cells[receipt.cell_key]
                if not cell then
                    cell = table.copy(receipt); cell.low, cell.mid, cell.high = 0, 0, 0
                    cells[receipt.cell_key] = cell
                end
                cell.received_start_us = math.min(cell.received_start_us, receipt.received_start_us)
                cell.received_end_us = math.max(cell.received_end_us, receipt.received_end_us)
                cell.low, cell.mid, cell.high = cell.low + receipt.low, cell.mid + receipt.mid,
                    cell.high + receipt.high
            else table.insert(retained, receipt) end
        end
        agent.buffer = retained
        local keys, detections, qualifying = {}, {}, 0
        for key in pairs(cells) do table.insert(keys, key) end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local cell = cells[key]
            local low, mid, high = math.min(1, cell.low * profile.gain),
                math.min(1, cell.mid * profile.gain), math.min(1, cell.high * profile.gain)
            local maximum = math.max(low, mid, high)
            local threshold = math.max(profile.detection_threshold, profile.noise_floor * profile.noise_ratio)
            if maximum >= threshold then
                qualifying = qualifying + 1
                if #detections < self.detection_limit then
                    local maximum_count = (low == maximum and 1 or 0) +
                        (mid == maximum and 1 or 0) + (high == maximum and 1 or 0)
                    local dominant = maximum_count ~= 1 and "mixed" or
                        (low == maximum and "low" or (mid == maximum and "mid" or "high"))
                    table.insert(detections, {
                        detection_id = "d" .. tostring(#detections),
                        received_interval_us = {cell.received_start_us, cell.received_end_us},
                        observer_frame_ref = cell.observer_frame_ref,
                        azimuth_interval_deg = cell.azimuth_interval_deg,
                        elevation_band = "level",
                        received_strength_band = maximum < 0.2 and "weak" or
                            (maximum < 0.6 and "medium" or "strong"),
                        dominant_band = dominant, temporal_form = "brief",
                    })
                end
            end
        end
        local result = {detections = detections,
            incomplete = agent.incomplete[start_us] == true or qualifying > self.detection_limit,
            late_rejections = agent.late_rejections}
        agent.incomplete[start_us] = nil
        agent.closed[start_us] = result
        return result
    end

    return state
end

return M
