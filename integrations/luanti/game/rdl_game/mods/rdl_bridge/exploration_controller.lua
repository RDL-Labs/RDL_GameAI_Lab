-- World-step-only consumer. The private adapter reports measured body state.
local M={}
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function wrap(x) return (x+180)%360-180 end
function M.new(run,adapter)
    local agent=adapter.agent_id or "npc_a"
    local capacity=adapter.capacity or 64
    local limit=adapter.limit_us or 16000000
    local self={entries={},count=0,effects=0,distance=0,rotation=0,stopped=false}
    function self:consume(c,p,now)
        assert(c.run_id==run and c.world_epoch==1 and c.agent_id==agent,"context")
        assert(p.run_id==run and p.world_epoch==1 and p.agent_id==agent and p.clock_id=="world-sim-v1","packet context")
        assert(c.source_id==p.observation_id and c.operation_id=="op:" .. p.observation_id,"source")
        assert(c.capture_us==p.capture_us and c.pose_ref==p.pose_ref and c.body_revision==p.body_revision,"body binding")
        local expiry=math.min(p.capture_us+500000,limit)
        if adapter.period_us then expiry=math.min(expiry,(math.floor(p.capture_us/adapter.period_us)+1)*adapter.period_us) end
        if adapter.cycle_boundaries then
            local start=math.floor(p.capture_us/adapter.period_us)*adapter.period_us
            for _,boundary in ipairs(adapter.cycle_boundaries) do
                if start+boundary>p.capture_us then expiry=math.min(expiry,start+boundary);break end
            end
        end
        assert(c.expires_us==expiry,"expiry binding")
        assert(now>=p.capture_us,"time reversal")
        local turn_ok=math.abs(c.amount)==90 or (adapter.landmarks and c.amount~=0 and math.abs(c.amount)<=90 and c.amount%5==0)
        assert((c.kind=="move" and c.amount==1) or (c.kind=="turn" and turn_ok)
            or ((c.kind=="pickup" or c.kind=="wait") and c.amount==0),"action")
        if c.kind=="pickup" then
            local target
            for _,item in ipairs(p.food.visible) do if item.ref==c.target_ref then target=item end end
            assert(p.food.coverage=="complete" and target and target.distance<=1.25
                and (adapter.resources or #p.food.visible==1),"unobserved pickup")
            if adapter.resources then assert(target.appearance==adapter.taught_appearance,"untaught material") end
        else assert(c.target_ref=="","unobserved target") end
        local old=self.entries[c.operation_id]
        if old then assert(equal(old.command,c),"operation conflict");return old.result,false end
        assert(self.count<capacity,"operation budget")
        local entry={command=table.copy(c)}
        self.entries[c.operation_id]=entry;self.count=self.count+1 -- before effects/reentrant calls
        local before=adapter.body()
        local status
        if self.stopped then status="stopped"
        elseif now>=c.expires_us then status="expired"
        elseif before.revision~=c.body_revision or before.pose_ref~=c.pose_ref then status="stale"
        else
            local step=adapter.natural and math.sqrt(2) or 1
            assert(self.distance+(c.kind=="move" and step or 0)<=capacity*step+.00001 and self.rotation+(c.kind=="turn" and math.abs(c.amount) or 0)<=capacity*90)
            status=adapter.execute(c)
        end
        local after=adapter.body()
        local delta=vector.subtract(after.position,before.position)
        local forward=core.yaw_to_dir(before.yaw)
        local right={x=forward.z,y=0,z=-forward.x}
        local yaw=wrap(-math.deg(after.yaw-before.yaw))
        local distance=vector.length(delta)
        self.distance=self.distance+distance;self.rotation=self.rotation+math.abs(yaw)
        if status=="moved" or status=="turned" or status=="picked_up" then self.effects=self.effects+1 end
        entry.result={run_id=run,world_epoch=1,agent_id=agent,operation_id=c.operation_id,source_id=c.source_id,
            executed_us=now,before_pose_ref=before.pose_ref,after_pose_ref=after.pose_ref,before_revision=before.revision,
            after_revision=after.revision,status=status,forward=vector.dot(delta,forward),right=vector.dot(delta,right),
            yaw=yaw,acquired=status=="picked_up"}
        if adapter.natural then entry.result.up=delta.y end
        return table.copy(entry.result),true
    end
    return self
end
return M
