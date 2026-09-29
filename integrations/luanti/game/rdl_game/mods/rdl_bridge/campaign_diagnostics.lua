-- Observer-only diagnostics. No clock correction, forced GC, or action input.
return function(run)
    local d={schema="campaign-timing-v1",run_id=run,days={},recent={},slow={},export_us=0}
    local start,mark,entry,previous_end,next_sample,last_flush=0,0,nil,nil,0,-1
    local function push(xs,x,cap) xs[#xs+1]=x;if #xs>cap then table.remove(xs,1) end end
    function d.begin(sim,dt,last_slot)
        start=core.get_us_time();mark=start
        entry={sim_before_us=sim,dt_us=math.floor(dt*1000000+.5),last_slot_before=last_slot,
            gap_since_previous_end_us=previous_end and start-previous_end or 0,phases={}}
    end
    function d.mark(name)
        local now=core.get_us_time();entry.phases[name]=(entry.phases[name] or 0)+now-mark;mark=now
    end
    function d.flush(sim,phase,failure)
        d.sim_us=sim;d.phase=phase;d.failure=failure;d.lua_heap_kib=collectgarbage("count")
        local began=core.get_us_time()
        local name=phase=="after_export" and "campaign-diagnostics-complete.json" or "campaign-diagnostics.json"
        core.safe_file_write(core.get_worldpath() .. "/" .. name,core.write_json({schema=d.schema,run_id=run,days=d.days,recent=d.recent,slow=d.slow,
            export_us=d.export_us,sim_us=sim,phase=phase,failure=failure,lua_heap_kib=d.lua_heap_kib,last_flush_us=d.last_flush_us}))
        d.last_flush_us=core.get_us_time()-began
    end
    function d.finish(sim,slot,failure)
        local now=core.get_us_time();entry.work_us=now-start;entry.sim_us=sim;entry.slot=slot;entry.failure=failure
        local key=tostring(math.min(32,math.floor(sim/64000000)+1))
        local day=d.days[key] or {steps=0,max_dt_us=0,max_work_us=0,max_gap_us=0,phases={}}
        d.days[key]=day;day.steps=day.steps+1
        day.max_dt_us=math.max(day.max_dt_us,entry.dt_us);day.max_work_us=math.max(day.max_work_us,entry.work_us)
        day.max_gap_us=math.max(day.max_gap_us,entry.gap_since_previous_end_us)
        for name,value in pairs(entry.phases) do
            local stat=day.phases[name] or {count=0,total_us=0,max_us=0};day.phases[name]=stat
            stat.count=stat.count+1;stat.total_us=stat.total_us+value;stat.max_us=math.max(stat.max_us,value)
        end
        if sim>=next_sample or entry.dt_us>=100000 or entry.work_us>=100000 or failure then
            entry.lua_heap_kib=collectgarbage("count");day.last_heap_kib=entry.lua_heap_kib
            push(d.recent,entry,128);next_sample=sim+1000000
            if entry.dt_us>=100000 or entry.work_us>=100000 or failure then push(d.slow,entry,128) end
        end
        local period=math.floor(sim/64000000)
        if period~=last_flush then last_flush=period;d.flush(sim,"running",failure) end
        previous_end=core.get_us_time()
    end
    return d
end
