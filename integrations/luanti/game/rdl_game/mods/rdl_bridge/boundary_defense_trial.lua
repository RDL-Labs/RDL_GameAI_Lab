-- L11 World-step-only warning authority. Callback code must never call consume.
local M = {}
local scope = {"run_id", "world_epoch", "defender", "actor", "site_ref", "clock_id"}
function M.new(config, adapter)
    local self = {config=table.copy(config), adapter=adapter, consumed=nil, active=nil, result=nil, count=0}
    function self:consume(permit, notice, now)
        if type(permit)~="table" or self.consumed then return false,"already_consumed_or_missing" end
        for _,k in ipairs(scope) do
            if permit[k]~=self.config[k] or notice[k]~=self.config[k] then return false,"scope_mismatch" end
        end
        if permit.notice_id~=notice.notice_id or permit.operation_id~=notice.notice_id .. ":warning"
            or permit.capture_us~=notice.capture_us or permit.expires_us~=notice.capture_us+1000000
            or permit.duration_us~=250000 or now<notice.capture_us then return false,"binding_mismatch" end
        self.consumed=permit.operation_id -- before any body/display side effect or reentrant call
        if now>permit.expires_us then
            self.result={permit=table.copy(permit),status="action_expired",started_us=now,ended_us=now,readback="",cleared=""}
            return false,"action_expired"
        end
        self.count=self.count+1
        self.active={permit=table.copy(permit),started_us=now,until_us=now+permit.duration_us}
        self.adapter.set("WARNING")
        self.active.readback=self.adapter.get()
        assert(self.active.readback=="WARNING","warning display readback failed")
        return true
    end
    function self:step(now)
        if self.active and now>=self.active.until_us then
            local a=self.active
            self.adapter.set("")
            local cleared=self.adapter.get()
            assert(cleared=="","warning display clear failed")
            self.result={permit=a.permit,status="displayed",started_us=a.started_us,ended_us=now,
                readback=a.readback,cleared=cleared}
            self.active=nil
        end
    end
    return self
end
return M
