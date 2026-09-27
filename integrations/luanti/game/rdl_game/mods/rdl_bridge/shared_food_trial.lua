-- L10C bounded World execution. The adapter owns entities; no outcome oracle.
local M = {}
local SLOT = 250000
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function M.new(spec,adapter)
    assert(spec.ready_us<=spec.capture_us+500000,"start barrier expired")
    assert(spec.first=="npc_a" or spec.first=="npc_b")
    local self={start_us=(math.floor(spec.ready_us/SLOT)+1)*SLOT,last_slot=-1,
        actors={},claims=0,complete=false,adapter=adapter}
    for _,agent in ipairs({"npc_a","npc_b"}) do
        local d=spec.decisions[agent]
        assert(d.agent_id==agent and (d.action=="attempt_food" or d.action=="defer"))
        assert(d.basis~="acquisition_conditions_unavailable","acquisition unavailable")
        assert(d.expires_us==spec.capture_us+1000000)
        self.actors[agent]={decision=table.copy(d),release_us=self.start_us+(agent==spec.first and 0 or SLOT),
            actions=0,authority_consumptions=0,attempted=false,acquired=false,deposited=false,trace={}}
    end
    function self:consume(agent,d,now)
        local a=self.actors[agent]
        if self.aborted or not a or a.used or not equal(d,a.decision) then return false end
        if now<a.release_us or now>=a.release_us+SLOT or now>d.expires_us then return false end
        a.used=true; a.authority_consumptions=a.authority_consumptions+1
        a.started_us=now
        return true
    end
    function self:abort(reason)
        self.aborted=reason
    end
    function self:step(now,order)
        if self.complete or self.aborted or now<self.start_us then return end
        local slot=math.floor((now-self.start_us)/SLOT)
        if slot==self.last_slot then return end
        if slot~=self.last_slot+1 then self:abort("missed_execution_slot"); return end
        self.last_slot=slot -- consume the slot before invoking any adapter
        for _,agent in ipairs(order or {"npc_a","npc_b"}) do
            local a=self.actors[agent]
            if not a.done and now>=a.release_us then
                if not a.used then
                    if not self:consume(agent,a.decision,now) then self:abort("action_expired"); return end
                    if a.decision.action=="defer" then a.done=true; a.completed_us=now
                    else a.attempted=true end
                end
                if not a.done then
                    if a.actions>=16 then self:abort("body_budget"); return end
                    a.actions=a.actions+1
                    local x=adapter.position(agent)
                    local entry={at_us=now,slot=slot,before_x=x}
                    a.trace[#a.trace+1]=entry
                    if a.acquired then
                        local home=adapter.home(agent)
                        if math.abs(x-home)<=1.25 then
                            a.done=true; a.deposited=true; a.completed_us=now
                            entry.kind="deposit";adapter.deposit(agent)
                        else
                            entry.kind="return";adapter.move(agent,x+(home>x and 1 or -1))
                        end
                    elseif math.abs(x)<=1.25 then
                        entry.kind="pickup_attempt"
                        a.acquired=adapter.claim(agent)
                        entry.acquired=a.acquired
                        if a.acquired then
                            self.claims=self.claims+1;assert(self.claims==1,"duplicate shared Food claim")
                            self.claimant=agent;self.claimed_us=now
                        else a.done=true;a.completed_us=now end
                    else
                        entry.kind="approach";adapter.move(agent,x+(x<0 and 1 or -1))
                    end
                    entry.after_x=adapter.position(agent)
                end
            end
        end
        self.complete=self.actors.npc_a.done and self.actors.npc_b.done or false
    end
    function self:snapshot()
        return table.copy({start_us=self.start_us,last_slot=self.last_slot,actors=self.actors,
            claimant=self.claimant,claimed_us=self.claimed_us,claims=self.claims,complete=self.complete,aborted=self.aborted})
    end
    return self
end
return M
