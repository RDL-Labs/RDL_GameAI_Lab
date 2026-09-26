-- One arbiter per agent. Callbacks only submit a single bounded mailbox item.
local M = {}
function M.new(run, epoch, agent, controller)
    local s = {generation=0, idle=false, intent=false, pending={}, reserved=0, transfers={}, transfer_count=0,
               mailbox=nil, in_flight=nil, active=nil, stopped=false, last_slot=-1, log={}, admitted={}, operation_ids={}}
    local function log(kind, fields)
        assert(#s.log < 256, "trace_capacity")
        fields=fields or {}; fields.kind=kind; fields.generation=s.generation; s.log[#s.log+1]=fields
    end
    function s.invalidate(reason, now)
        s.generation=s.generation+1
        if s.active then controller.abort(s.active,reason); s.active=nil; s.reserved=0 end
        log("invalidate",{reason=reason,time_us=now})
    end
    function s.life_intent(now)
        if not s.intent then s.invalidate("life_priority",now) end
        s.intent=true;s.idle=false
    end
    function s.stop(now)
        s.invalidate("run_ended",now);s.stopped=true
    end
    function s.reconcile()
        if s.active and (s.active.operation_status=="aborted" or s.active.operation_status=="not_executed") then s.active=nil;s.reserved=0 end
    end
    function s.start(request, frame, body)
        s.reconcile()
        local blocked = s.stopped or not s.idle or s.intent or s.result_waiting or s.in_flight~=nil or s.mailbox~=nil
        local copied=table.copy(body);copied.life_busy=blocked
        local full=#s.pending+s.reserved>=8
        if full then copied.life_busy=true end
        assert(s.admitted[frame.frame_id],"source_not_admitted")
        local known=s.operation_ids[request.operation_id]
        local e,fresh=controller.start(request,frame,copied)
        s.operation_ids[request.operation_id]=true
        if fresh then
            e.generation=s.generation; s.active=e;s.reserved=1
            local slot=(math.floor(body.now_us/1000000)+1)*1000000
            if slot>e.plan.deadline_us or slot-e.plan.source_us>2000000 then
                controller.abort(e,"slot_outside_deadline");s.active=nil;s.reserved=0;fresh=false
            end
        elseif full and not e.plan and not known then e.reasons={"pending_capacity"} end
        return e,fresh
    end
    function s.enqueue(frame, reserved)
        if reserved then assert(s.reserved==1);s.reserved=0 end
        if #s.pending+s.reserved>=8 then log("drop",{frame_id=frame.frame_id,tick=frame.sampled_world_tick});return false end
        s.pending[#s.pending+1]=frame;return true
    end
    function s.slot(tick)
        if tick%4~=0 or tick<=s.last_slot then return false end
        s.last_slot=tick;return true
    end
    function s.begin(id, now, life)
        if s.in_flight or s.mailbox then return nil end
        assert(not s.transfers[id] and s.transfer_count<32,"transfer_capacity")
        local t={id=id,run_id=run,world_epoch=epoch,agent_id=agent,generation=s.generation,
                 sent_us=now,frames={},ids={},life=life,consumed=false}
        for i=1,math.min(4,#s.pending) do t.frames[i]=s.pending[i];t.ids[s.pending[i].frame_id]=true end
        s.transfers[id]=t;s.transfer_count=s.transfer_count+1;s.in_flight=id
        return t
    end
    function s.submit(id, response, received_us, release_us)
        assert(s.transfers[id],"unknown_delivery")
        assert(not s.mailbox,"mailbox_full")
        s.mailbox={id=id,response=response,received_us=received_us,release_us=release_us}
    end
    function s.consume(now)
        local m=s.mailbox
        if not m or now<m.release_us then return nil end
        s.mailbox=nil
        if s.in_flight==m.id then s.in_flight=nil end
        local t=s.transfers[m.id];local response=m.response
        local matches=response and response.agent_id==agent and response.inspection and response.inspection.observation_id==t.id
        local receipt=matches and response.sensory_receipt
        local removed={}
        if receipt and receipt.accepted and receipt.delivery_observation_id==t.id then
            local keep={}
            for _,f in ipairs(s.pending) do
                if t.ids[f.frame_id] then removed[#removed+1]=f.frame_id else keep[#keep+1]=f end
            end
            s.pending=keep
            for _,f in ipairs(t.frames) do s.admitted[f.frame_id]=f end
        end
        local valid=not not matches and t.life and not t.consumed and not s.stopped and t.generation==s.generation and s.intent
        t.consumed=true
        log("consume",{delivery_id=t.id,sent_us=t.sent_us,received_us=m.received_us,consumed_us=now,
             request_generation=t.generation,action_eligible=valid,removed=removed,new_frames=receipt and receipt.new_frames})
        return {response=response,eligible=valid,transfer=t}
    end
    function s.authorized(result)
        if not result or not result.eligible or s.stopped or not s.intent or result.transfer.generation~=s.generation then return false end
        result.eligible=false -- consume authority before the caller performs a side effect
        return true
    end
    return s
end
return M
