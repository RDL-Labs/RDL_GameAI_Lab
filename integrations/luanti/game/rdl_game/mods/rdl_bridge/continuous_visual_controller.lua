-- OBS-8B continuous-clock controller. No World target information enters this module.
local M = {}
local function wrap(x) return (x + 180) % 360 - 180 end
M.wrap = wrap
M.plan = dofile(core.get_modpath("rdl_bridge") .. "/visual_probe.lua").plan
function M.new(run_id, epoch, agent, rule)
    rule = rule or "obs8b-v1"
    assert(rule == "obs8b-v1" or rule == "obs9-v1", "unsupported_rule")
    local allowed_profiles = rule == "obs9-v1" and {["fixture-life-sensory"]=true,["fixture-life-sensory-compact"]=true} or {["fixture-distant-enabled"]=true}
    local planner = dofile(core.get_modpath("rdl_bridge") .. "/visual_probe.lua").plan_for_profiles
    local ledger, count, active = {}, 0, nil
    local controller = {}
    function controller.start(request, frame, body)
        assert(request.run_id == run_id and request.world_epoch == epoch and request.agent_id == agent, "context_mismatch")
        assert(request.purpose == "visual_reacquisition_after_yaw" and request.rule_version == rule, "invalid_question")
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
        entry.profile_id = frame.profile_id
        entry.plan, entry.reasons = planner(frame, feature, request, body, allowed_profiles)
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
        if body.profile_id ~= entry.profile_id or body.profile_revision ~= 1 then controller.abort(entry, "profile_changed"); return false end
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
        if tick ~= entry.next_sample_tick or math.floor(body.now_us / 250000) ~= tick then controller.abort(entry, "invalid_acquisition_slot"); return nil end
        entry.operation_status = "sampling"; entry.samples = 1; entry.sample_tick = tick
        entry.frame = acquire(); entry.operation_status = "sampled"; active = nil
        return entry.frame
    end
    return controller
end
return M
