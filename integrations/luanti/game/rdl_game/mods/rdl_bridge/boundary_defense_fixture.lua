-- Dedicated instrumented pickup experiment; not a general action-recognition sensor.
return function(http, runtime_url, profiles)
    local root=core.get_modpath("rdl_bridge")
    local trial_module=dofile(root .. "/boundary_defense_trial.lua")
    local run=assert(core.settings:get("rdl_learning_run_id"))
    local defender=core.settings:get("rdl_boundary_defender") or "npc_a"
    local actor=defender=="npc_a" and "npc_b" or "npc_a"
    local schedule=core.settings:get("rdl_boundary_schedule") or "dense"
    local inclusion=tonumber(core.settings:get("rdl_boundary_inclusion") or "0")
    local base=tonumber(core.settings:get("rdl_boundary_threshold") or "3")
    local fault=core.settings:get_bool("rdl_boundary_loss",false)
    local negative=core.settings:get("rdl_boundary_negative") or ""
    local offsets=schedule=="single" and {0} or (schedule=="dense" and {0,250000,500000} or {0,5000000,10000000})
    if negative~="" then offsets={0} end
    local sim_us,stage,T,index=0,"setup",nil,1
    local npc,other,trial,food
    local busy,mailbox,active_job=false,nil,nil
    local jobs={}
    local prefix=runtime_url:gsub("/v1/observe$","")
    local profile={id=profiles[defender].profile_id,revision=profiles[defender].profile_revision,radius=profiles[defender].vision_local.radius}
    local config={schema="l11-boundary-defense-v1",run_id=run,world_epoch=1,defender=defender,actor=actor,
        site_ref=run .. ":site",clock_id=run .. ":clock",registration={source="l11-explicit-apparatus-registration-v1",unit_refs={}},
        profile=profile,reaction={profile_id=base==3 and "lower_threshold" or "higher_threshold",source="l11-fixed-fixture-v1",base_threshold=base},
        relation={relation_id=run .. ":relation",source="l11-fixed-fixture-v1",action="observed_unit_taken",beneficiary_inclusion=inclusion},
        site_relation={source="l11-fixed-site-v1",continued_use=true}}
    for i=1,#offsets do config.registration.unit_refs[i]=run .. ":food:" .. i end
    local evidence={run_id=run,config=config,schedule=schedule,negative=negative,loss_requested=fault,
        uses={},deliveries={},guards={},acquired=0,spawned=0,removed=0}
    local function encode(x) return (core.write_json(x):gsub('"visible":null','"visible":[]')) end
    local function finish(reason)
        evidence.failure=reason;evidence.finished_us=sim_us;evidence.warning_count=trial and trial.count or 0
        evidence.action_result=trial and trial.result or nil
        core.safe_file_write(core.get_worldpath() .. "/l11-evidence.json",encode(evidence))
        stage="done"
    end
    local function enqueue(kind,payload,meta)
        jobs[#jobs+1]={kind=kind,payload=table.copy(payload),meta=meta or {}}
    end
    local function send()
        if busy or #jobs==0 then return end
        active_job=table.remove(jobs,1);busy=true
        local payload=table.copy(active_job.payload)
        if active_job.kind=="observe" then payload.now_us=sim_us end
        active_job.sent=payload;active_job.sent_us=sim_us
        http.fetch({url=prefix .. "/v1/boundary-defense/" .. active_job.kind,method="POST",
            extra_headers={"Content-Type: application/json"},data=encode(payload),timeout=2},function(r)
                mailbox={ok=r.succeeded and r.code==200,wire=r.data} -- no effect in callback
            end)
    end
    local function bounded(unit,seq,side)
        local visible={};local origin=npc:get_pos()
        local function add(obj,ref,kind)
            if not obj then return end
            local pos=obj:get_pos();if not pos then return end
            local distance=vector.distance(origin,pos)
            if distance<=profile.radius then visible[#visible+1]={ref=ref,kind=kind,distance=distance,relative_position=vector.subtract(pos,origin)} end
        end
        add(other,actor,"npc");add(food,unit,"food")
        return {packet_id=run .. ":packet:" .. seq .. ":" .. side,observer=defender,capture_us=sim_us,seq=seq,
            order=side=="before" and 1 or 3,pose_ref=run .. ":pose:stationary",profile=table.copy(profile),coverage="complete",visible=visible}
    end
    local function use()
        local unit=config.registration.unit_refs[index]
        local location=other:get_pos()
        food=assert(core.add_entity(location,"rdl_bridge:food",unit));evidence.spawned=evidence.spawned+1
        local before=bounded(unit,index,"before")
        local entry={scheduled_us=T+offsets[index],capture_us=sim_us,unit_ref=unit,
            defender_position=npc:get_pos(),actor_position=other:get_pos(),quantity_before=1,acquired_before=evidence.acquired}
        if negative=="presence" then
            entry.no_pickup=true;entry.quantity_after=1;entry.acquired_after=evidence.acquired
            entry.before=before;entry.after=bounded(unit,index,"after")
        else
            local old=food;food=nil;old:remove()
            assert(old:get_pos()==nil,"Food was not removed")
            evidence.acquired=evidence.acquired+1;evidence.removed=evidence.removed+1
            other:get_luaentity().rdl_acquired=evidence.acquired
            local after=bounded(unit,index,"after")
            local notice=table.copy(config)
            notice={run_id=run,world_epoch=1,defender=defender,actor=actor,site_ref=config.site_ref,clock_id=config.clock_id,
                notice_id=run .. ":notice:" .. index,event_id=run .. ":pickup:" .. index,unit_ref=unit,capture_us=sim_us,seq=index,
                profile=table.copy(profile),pose_ref=before.pose_ref,before_id=before.packet_id,after_id=after.packet_id,
                action="observed_unit_taken",units=1,coverage="complete",limitations="fixture-instrumented-local-use-v1"}
            local effect={event_id=notice.event_id,actor=actor,site_ref=config.site_ref,unit_ref=unit,capture_us=sim_us,seq=index,order=2,
                action=notice.action,units=1,established=true,source=notice.limitations}
            entry.record={notice=notice,before=before,effect=effect,after=after}
            entry.quantity_after=0;entry.acquired_after=other:get_luaentity().rdl_acquired
            enqueue("observe",{record=entry.record,now_us=sim_us},{index=index})
        end
        evidence.uses[#evidence.uses+1]=entry;index=index+1
    end
    core.register_on_mods_loaded(function() core.after(0,function()
        core.load_area({x=-2,y=0,z=-2},{x=18,y=3,z=2})
        for x=-2,18 do for y=0,3 do for z=-2,2 do core.set_node({x=x,y=y,z=z},{name="air"}) end end end
        core.forceload_block({x=0,y=1,z=0},true);core.forceload_block({x=16,y=1,z=0},true)
        npc=assert(core.add_entity({x=0,y=1,z=0},"rdl_bridge:npc",defender))
        other=assert(core.add_entity({x=negative=="outside" and 16 or 2,y=1,z=0},"rdl_bridge:npc",actor))
        npc:set_properties({physical=false,nametag=""});other:set_properties({physical=false,nametag=""})
        npc:set_yaw(0);other:set_yaw(0);other:get_luaentity().rdl_acquired=0
        trial=trial_module.new(config,{set=function(value) npc:set_properties({nametag=value}) end,
            get=function() return npc:get_properties().nametag end})
        evidence.lua_checks=dofile(root .. "/boundary_defense_checks.lua")(trial_module)
        enqueue("configure",config);stage="configuring"
    end) end)
    core.register_globalstep(function(dt)
        if stage=="done" then return end
        sim_us=sim_us+math.floor(dt*1000000+0.5)
        local ok,err=pcall(function()
            if sim_us>(T or 0)+17000000 then error("run deadline") end
            if trial then trial:step(sim_us) end
            if mailbox then
                local reply=mailbox;mailbox=nil;busy=false
                assert(reply.ok,"HTTP failure " .. tostring(reply.wire))
                local job=active_job;active_job=nil
                local response=core.parse_json(reply.wire)
                evidence.deliveries[#evidence.deliveries+1]={kind=job.kind,request=job.sent,response_wire=reply.wire,
                    sent_us=job.sent_us,received_us=sim_us}
                if job.kind=="configure" then
                    assert(response.configured);T=sim_us+250000;evidence.start_us=T;stage="running"
                elseif job.kind=="observe" then
                    local n=job.payload.record.notice;local r=response.receipt
                    assert(r.notice_id==n.notice_id)
                    if fault and job.meta.index==1 and not evidence.lost_response then
                        assert(response.new_event);evidence.lost_response=true
                        table.insert(jobs,1,job) -- original capture and IDs; retry ahead of new uses
                    else
                        if fault and job.meta.index==1 then assert(not response.new_event);evidence.loss_recovered=true end
                        if r.permit then
                            local foreign=table.copy(r.permit);foreign.defender=actor
                            local applied=trial:consume(foreign,n,sim_us)
                            assert(not applied);evidence.guards.foreign_rejected=true
                            local first,reason=trial:consume(r.permit,n,sim_us)
                            assert(first,"warning not applied: " .. tostring(reason))
                            assert(not trial:consume(r.permit,n,sim_us));evidence.guards.replay_rejected=true
                            evidence.warning_notice=n.notice_id
                        end
                    end
                else
                    if not evidence.result_replayed then enqueue("result",trial.result);evidence.result_replayed=true
                    else assert(not response.new_result);evidence.result_confirmed=true end
                end
            end
            if stage=="running" and index<=#offsets and sim_us>=T+offsets[index] then
                assert(sim_us<T+offsets[index]+250000,"missed use slot")
                use()
            end
            if trial and trial.result and not evidence.result_sent then
                enqueue("result",trial.result);evidence.result_sent=true
                -- Completed callback replay is separate from accepted-response loss.
                local n
                for _,u in ipairs(evidence.uses) do if u.record and u.record.notice.notice_id==trial.result.permit.notice_id then n=u.record.notice end end
                assert(not trial:consume(trial.result.permit,n,sim_us));evidence.guards.completed_replay_rejected=true
            end
            send()
            if T and index>#offsets and sim_us>=T+offsets[#offsets]+1250000 and not busy and #jobs==0 and not trial.active then
                assert(not trial.result or evidence.result_confirmed)
                assert(sim_us<=T+12000000,"World deadline")
                finish()
            end
        end)
        if not ok then finish(tostring(err)) end
    end)
end
