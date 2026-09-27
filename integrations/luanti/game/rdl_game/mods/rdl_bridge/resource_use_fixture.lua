-- L12: return/hold schedule stays inside the experimenter's World adapter.
return function(http,runtime_url,profiles)
    local root=core.get_modpath("rdl_bridge")
    local actions=dofile(root .. "/resource_use_trial.lua")
    local warnings=dofile(root .. "/boundary_defense_trial.lua")
    local run=assert(core.settings:get("rdl_learning_run_id"))
    local scenario=assert(core.settings:get("rdl_resource_scenario"))
    local defender=core.settings:get("rdl_boundary_defender") or "npc_a"
    local actor=defender=="npc_a" and "npc_b" or "npc_a"
    local fault=core.settings:get_bool("rdl_resource_loss",false)
    local prefix=runtime_url:gsub("/v1/observe$","")
    local p=profiles[defender]
    local profile={id=p.profile_id,revision=p.profile_revision,radius=p.vision_local.radius}
    local config={schema="l12-resource-use-learning-v1",run_id=run,world_epoch=1,defender=defender,actor=actor,
        site_ref=run .. ":site",clock_id=run .. ":clock",profile=profile,
        registration={source="l12-explicit-apparatus-registration-v1",unit_refs={}}}
    for i=1,7 do config.registration.unit_refs[i]=run .. ":unit:" .. i end
    local evidence={run_id=run,scenario=scenario,config=config,loss_requested=fault,episodes={},deliveries={},guards={}}
    local sim,stage,index=0,"setup",0
    local npc,other,food,warning,trial,entry
    local jobs,busy,job,mailbox={},false,nil,nil
    local function encode(x) return (core.write_json(x):gsub('"visible":null','"visible":[]')) end
    local function enqueue(kind,payload,meta) jobs[#jobs+1]={kind=kind,payload=table.copy(payload),meta=meta or {}} end
    local function finish(reason)
        evidence.failure=reason;evidence.finished_us=sim;evidence.warning_count=warning and warning.count or 0
        evidence.warning_result=warning and warning.result or nil
        core.safe_file_write(core.get_worldpath() .. "/l12-evidence.json",encode(evidence));stage="done"
    end
    local function hand(obj) return obj:get_luaentity().l12_hand or 0 end
    local function sethand(obj,value) obj:get_luaentity().l12_hand=value end
    local function conservation(phase)
        local present=food and food:get_pos() and 1 or 0
        assert(present+hand(npc)+hand(other)==1,"unit conservation")
        entry.conservation[#entry.conservation+1]={phase=phase,capture_us=sim,site=present,observer=hand(npc),actor=hand(other),unit_ref=entry.unit_ref}
    end
    local function packet(phase,side)
        local visible={};local origin=npc:get_pos()
        local function add(obj,ref,kind)
            if not obj or not obj:get_pos() then return end
            local pos=obj:get_pos();local distance=vector.distance(pos,origin)
            if distance<=profile.radius then visible[#visible+1]={ref=ref,kind=kind,distance=distance,relative_position=vector.subtract(pos,origin)} end
        end
        add(other,actor,"npc");add(food,entry.unit_ref,"food")
        return {packet_id=entry.episode_id .. ":" .. phase .. ":" .. side,observer=defender,capture_us=sim,seq=index,
            order=side=="before" and 1 or 3,pose_ref=run .. ":stationary",profile=table.copy(profile),coverage="complete",visible=visible}
    end
    local function setup_episode()
        index=index+1
        if food and food:get_pos() then food:remove() end
        sethand(npc,0);sethand(other,0)
        food=assert(core.add_entity({x=1,y=1,z=0},"rdl_bridge:food",config.registration.unit_refs[index]))
        local T=(math.floor(sim/250000)+1)*250000
        trial=actions.new(T)
        local returns=index==7 or not scenario:find("negative",1,true)
        if scenario=="heldout_counterexample" and index==6 then returns=false end
        entry={episode_id=run .. ":episode:" .. index,unit_ref=config.registration.unit_refs[index],scheduled_us=T,
            return_scheduled=returns,conservation={},initial_observer=npc:get_pos(),initial_actor=other:get_pos(),counts=trial.counts}
        evidence.episodes[index]=entry;conservation("setup");stage="episode"
    end
    local function peer()
        local before=packet("peer","before")
        assert(vector.distance(other:get_pos(),food:get_pos())<=1.25)
        food:remove();assert(food:get_pos()==nil);food=nil;sethand(other,1)
        local after=packet("peer","after");conservation("peer_pickup")
        local n={run_id=run,world_epoch=1,defender=defender,actor=actor,site_ref=config.site_ref,clock_id=config.clock_id,
            notice_id=entry.episode_id .. ":notice",event_id=entry.episode_id .. ":peer-pickup",unit_ref=entry.unit_ref,
            capture_us=sim,seq=index,profile=table.copy(profile),pose_ref=before.pose_ref,before_id=before.packet_id,after_id=after.packet_id,
            action="observed_unit_taken",units=1,coverage="complete",limitations="fixture-instrumented-local-use-v1"}
        local effect={event_id=n.event_id,actor=actor,site_ref=config.site_ref,unit_ref=entry.unit_ref,capture_us=sim,seq=index,order=2,
            action=n.action,units=1,established=true,source=n.limitations}
        entry.use={episode_id=entry.episode_id,scheduled_us=entry.scheduled_us,now_us=sim,
            record={notice=n,before=before,effect=effect,after=after}}
        enqueue("observe",entry.use,{episode=index})
    end
    local function return_unit()
        assert(hand(other)==1 and food==nil)
        sethand(other,0);food=assert(core.add_entity({x=1,y=1,z=0},"rdl_bridge:food",entry.unit_ref))
        entry.return_us=sim;conservation("returned_same_unit")
    end
    local function own()
        local before=packet("own","before");local acquired=false
        if food and food:get_pos() and vector.distance(npc:get_pos(),food:get_pos())<=1.25 then
            food:remove();assert(food:get_pos()==nil);food=nil;sethand(npc,1);acquired=true
        end
        local after=packet("own","after");conservation("own_attempt")
        local n=entry.use.record.notice
        local result={episode_id=entry.episode_id,notice_id=n.notice_id,operation_id=entry.episode_id .. ":own-op",
            event_id=entry.episode_id .. ":own-event",capture_us=sim,now_us=sim,attempted=true,acquired=acquired,
            coverage=scenario=="heldout_incomplete" and index==6 and "partial" or "complete",before=before,after=after}
        result.effect={source="l12-direct-pickup-v1",observer=defender,event_id=result.event_id,operation_id=result.operation_id,
            notice_id=result.notice_id,capture_us=sim,attempted=true,acquired=acquired,hand_before=0,hand_after=hand(npc)}
        entry.result=result;entry.actual_acquired=acquired
        enqueue("record",result,{episode=index});stage="await_result"
    end
    local function send()
        if busy or #jobs==0 then return end
        job=table.remove(jobs,1);busy=true
        local payload=table.copy(job.payload)
        if job.kind=="observe" or job.kind=="record" then payload.now_us=sim end
        job.sent=payload;job.sent_us=sim
        http.fetch({url=prefix .. "/v1/resource-use/" .. job.kind,method="POST",extra_headers={"Content-Type: application/json"},
            data=encode(payload),timeout=2},function(r)
                mailbox={ok=r.succeeded and r.code==200,wire=r.data,
                    release_us=sim+((fault and job.kind=="observe" and job.meta.episode==7) and 100000 or 0)}
            end)
    end
    core.register_on_mods_loaded(function() core.after(0,function()
        core.load_area({x=-2,y=0,z=-2},{x=3,y=3,z=2})
        for x=-2,3 do for y=0,3 do for z=-2,2 do core.set_node({x=x,y=y,z=z},{name="air"}) end end end
        core.forceload_block({x=0,y=1,z=0},true)
        npc=assert(core.add_entity({x=0,y=1,z=0},"rdl_bridge:npc",defender))
        other=assert(core.add_entity({x=1,y=1,z=0},"rdl_bridge:npc",actor))
        for _,obj in ipairs({npc,other}) do obj:set_properties({physical=false,nametag=""});obj:set_yaw(0) end
        warning=warnings.new(config,{set=function(v) npc:set_properties({nametag=v}) end,get=function() return npc:get_properties().nametag end})
        evidence.lua_checks=dofile(root .. "/resource_use_checks.lua")(actions)
        evidence.warning_checks=dofile(root .. "/boundary_defense_checks.lua")(warnings)
        enqueue("configure",config);stage="configuring"
    end) end)
    core.register_globalstep(function(dt)
        if stage=="done" then return end
        sim=sim+math.floor(dt*1000000+.5)
        local ok,err=pcall(function()
            assert(sim<=35000000,"run deadline")
            if warning then warning:step(sim) end
            if mailbox and sim>=mailbox.release_us then
                local reply=mailbox;mailbox=nil;busy=false;local done=job;job=nil
                assert(reply.ok,"HTTP failed " .. tostring(reply.wire))
                local response=core.parse_json(reply.wire)
                evidence.deliveries[#evidence.deliveries+1]={kind=done.kind,request=done.sent,response_wire=reply.wire,sent_us=done.sent_us,received_us=sim}
                if done.kind=="configure" then setup_episode()
                elseif done.kind=="observe" then
                    if fault and done.meta.episode==7 and not evidence.lost_response then
                        assert(response.new_event);evidence.lost_response=true;table.insert(jobs,1,done)
                    else
                        if fault and done.meta.episode==7 then assert(not response.new_event);evidence.loss_recovered=true end
                        local r=response.receipt;local notice=done.payload.record.notice
                        if r.permit then
                            local foreign=table.copy(r.permit);foreign.defender=actor
                            assert(not warning:consume(foreign,notice,sim));evidence.guards.foreign_rejected=true
                            local old=table.copy(notice);old.notice_id="old"
                            assert(not warning:consume(r.permit,old,sim));evidence.guards.old_rejected=true
                            assert(warning:consume(r.permit,notice,sim));assert(not warning:consume(r.permit,notice,sim))
                            evidence.guards.replay_rejected=true
                        end
                    end
                elseif done.kind=="record" then
                    assert(response.new_result)
                    entry.result_accepted_us=sim
                    if index==1 then enqueue("review",{episode_id=entry.episode_id,reviewer="l12-explicit-harness",basis="fixture object-count unresolved residual 1",evidence=entry.use.record.notice.notice_id})
                    elseif index==6 then
                        local req={learning_id=run .. ":learning",formation_episodes={},validation_episodes={},activate=not scenario:find("inactive",1,true)}
                        for i=1,3 do req.formation_episodes[i]=evidence.episodes[i].episode_id;req.validation_episodes[i]=evidence.episodes[i+3].episode_id end
                        enqueue("learn",req)
                    elseif index==7 then stage="finishing"
                    else setup_episode() end
                elseif done.kind=="review" then setup_episode()
                elseif done.kind=="learn" then
                    if not evidence.learning_replayed then evidence.learning_replayed=true;enqueue("learn",done.payload)
                    else enqueue("begin",{operation_id=run .. ":reaction",learning_id=run .. ":learning"}) end
                elseif done.kind=="begin" then setup_episode()
                elseif done.kind=="result" then
                    if not evidence.result_replayed then evidence.result_replayed=true;enqueue("result",warning.result)
                    else assert(not response.new_result);evidence.result_confirmed=true end
                end
            end
            if stage=="episode" then
                trial:once("peer",sim,0,peer)
                if entry.return_scheduled then trial:once("return_unit",sim,1500000,return_unit) end
                trial:once("own",sim,2000000,own)
            end
            if stage=="episode" or stage=="await_result" then assert(sim<entry.scheduled_us+3500000,"episode deadline") end
            if warning and warning.result and not evidence.result_sent then
                enqueue("result",warning.result);evidence.result_sent=true
                assert(not warning:consume(warning.result.permit,entry.use.record.notice,sim));evidence.guards.completed_replay_rejected=true
            end
            send()
            if stage=="finishing" and not busy and #jobs==0 and not warning.active then
                assert(not warning.result or evidence.result_confirmed);finish()
            end
        end)
        if not ok then finish(tostring(err)) end
    end)
end
