-- OBS-8 finite controller. No World target information enters this module.
local M = {}
local function wrap(x) return (x + 180) % 360 - 180 end
M.wrap = wrap
function M.plan_for_profiles(frame, feature, request, body, allowed_profiles)
    local reasons = {}
    local function need(ok, why) if not ok then reasons[#reasons + 1] = why end end
    need(body.now_us >= frame.capture_window.start_us and body.now_us - frame.capture_window.start_us <= 2000000, "stale_source")
    need(not body.life_busy, "life_busy")
    need(body.mapping_valid and body.source_pose == frame.observer_frame_ref and body.mapping_expires_us >= body.now_us, "pose_mapping_unavailable")
    need(body.translation <= 0.000001 and body.tilt_deg <= 0.01, "body_changed")
    need(body.profile_id == frame.profile_id and body.profile_revision == frame.profile_revision, "profile_changed")
    need(allowed_profiles[frame.profile_id] and frame.profile_revision == 1 and frame.sensor_id == "eye" and frame.channel == "vision_distant" and frame.sensor_model_revision == "sampled-surface-v0.2", "unsupported_conditions")
    need(frame.status == "SAMPLED" and frame.coverage == "COMPLETE_WITHIN_PLAN" and not frame.output_limited and frame.capture_window.kind == "instant", "source_incomplete")
    need(body.clock_id == frame.clock_id, "clock_mismatch")
    need(type(feature.azimuth_interval_deg) == "table" and type(feature.elevation_interval_deg) == "table" and feature.color_band ~= "unknown", "unknown_feature")
    if #reasons > 0 then return nil, reasons end
    local a = feature.azimuth_interval_deg
    local command = wrap((a[1] + a[2]) / 2 - body.source_to_start_deg)
    need(math.abs(command) <= 45, "rotation_budget")
    if #reasons > 0 then return nil, reasons end
    return {command_deg = command, started_us = body.now_us, deadline_us = body.now_us + 1500000,
            source_us = frame.capture_window.start_us, source_to_start_deg = body.source_to_start_deg,
            start_pose = body.pose_ref, source_pose = frame.observer_frame_ref}, {}
end
function M.plan(frame, feature, request, body)
    return M.plan_for_profiles(frame, feature, request, body, {["fixture-distant-enabled"]=true})
end
function M.new(run_id, epoch, agent)
    local ledger, count, active = {}, 0, nil
    local controller = {}
    function controller.start(request, frame, body)
        assert(request.run_id == run_id and request.world_epoch == epoch and request.agent_id == agent, "context_mismatch")
        assert(request.purpose == "visual_reacquisition_after_yaw" and request.rule_version == "obs8-v1", "invalid_question")
        assert(type(request.operation_id) == "string" and #request.operation_id > 0 and #request.operation_id <= 128, "invalid_operation_id")
        assert(request.source_frame_id == frame.frame_id and frame.agent_id == agent, "invalid_reference")
        local feature
        for _, f in ipairs(frame.payload.features or {}) do
            if f.feature_id == request.feature_id then assert(not feature, "ambiguous_feature"); feature = f end
        end
        assert(feature and feature.color_band == request.color_band, "invalid_feature")
        local fields = {"operation_id", "run_id", "world_epoch", "agent_id", "purpose", "rule_version", "source_frame_id", "feature_id", "color_band"}
        local allowed = {}; for _, k in ipairs(fields) do allowed[k] = true end
        for k in pairs(request) do assert(allowed[k], "invalid_request") end
        local previous = ledger[request.operation_id]
        if previous then
            for _, k in ipairs(fields) do assert(previous.request[k] == request[k], "operation_conflict") end
            return previous, false
        end
        assert(count < 16, "ledger_full")
        count = count + 1
        local entry = {request = table.copy(request), operation_status = "not_executed", reasons = {}, rotations = 0, samples = 0}
        ledger[request.operation_id] = entry
        if active then entry.reasons = {"operation_busy"}; return entry, false end
        entry.plan, entry.reasons = M.plan(frame, feature, request, body)
        if not entry.plan then return entry, false end
        entry.operation_status = "validated"; active = entry
        return entry, true
    end
    function controller.abort(entry, reason)
        entry.operation_status = "aborted"; entry.reasons[#entry.reasons + 1] = reason
        if active == entry then active = nil end
    end
    function controller.guard(entry, body)
        local p = entry.plan
        if body.now_us < p.started_us or body.now_us > p.deadline_us or body.now_us - p.source_us > 2000000 then controller.abort(entry, "deadline"); return false end
        if body.life_busy then controller.abort(entry, "life_priority"); return false end
        if not body.mapping_valid or body.mapping_expires_us < body.now_us then controller.abort(entry, "pose_mapping_unavailable"); return false end
        if body.translation > 0.000001 or body.tilt_deg > 0.01 then controller.abort(entry, "body_changed"); return false end
        if body.profile_id ~= "fixture-distant-enabled" or body.profile_revision ~= 1 then controller.abort(entry, "profile_changed"); return false end
        if entry.operation_status == "validated" and math.abs(M.wrap(body.source_to_start_deg - p.source_to_start_deg)) > 0.01 then controller.abort(entry, "pose_changed"); return false end
        if entry.operation_status == "rotated" and (type(body.measured_right_deg) ~= "number" or math.abs(body.measured_right_deg - entry.actual_deg) > 0.01) then controller.abort(entry, "pose_changed"); return false end
        if body.clock_id ~= "world-sim-v1" then controller.abort(entry, "clock_mismatch"); return false end
        return true
    end
    function controller.rotate(entry, body, set_right_yaw, measure)
        if entry ~= active or entry.operation_status ~= "validated" then return false end
        if not controller.guard(entry, body) then return false end
        -- Mark before the side effect; reentrant delivery cannot repeat it.
        entry.operation_status = "rotating"
        if entry.plan.command_deg ~= 0 then entry.rotations = 1; set_right_yaw(entry.plan.command_deg) end
        local actual = measure()
        entry.actual_deg = actual; entry.rotation_completed_us = body.now_us
        entry.next_sample_tick = (math.floor(body.now_us / 1000000) + 1) * 4
        if type(actual) ~= "number" or actual ~= actual or math.abs(actual) > 45 or math.abs(actual - entry.plan.command_deg) > 0.01 then
            controller.abort(entry, "rotation_unconfirmed"); return false
        end
        entry.operation_status = "rotated"; return true
    end
    function controller.sample(entry, tick, body, acquire)
        if entry ~= active or entry.operation_status ~= "rotated" then return nil end
        if not controller.guard(entry, body) then return nil end
        if tick > entry.next_sample_tick then controller.abort(entry, "missed_acquisition_slot"); return nil end
        if tick % 4 ~= 0 or body.now_us <= entry.rotation_completed_us then return nil end
        if tick ~= entry.next_sample_tick or body.now_us ~= tick * 250000 then controller.abort(entry, "invalid_acquisition_slot"); return nil end
        entry.operation_status = "sampling"; entry.samples = 1; entry.sample_tick = tick
        entry.frame = acquire(); entry.operation_status = "sampled"; active = nil
        return entry.frame
    end
    return controller
end
return M
