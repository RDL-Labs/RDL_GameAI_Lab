-- One acquisition owner; delivery and Probe never create additional frames.
local M={}
function M.new(run, profiles, find, build, agents, targets)
    local root=core.get_modpath("rdl_bridge")
    local distant=dofile(root .. "/distant_sensor.lua")
    local transmission=dofile(root .. "/audition_transmission.lua")
    local hearing=dofile(root .. "/audition_window_sensor.lua").new(250000,32,8)
    local s={packets={},frames={},samples={},seq={},last_local={},next_window=0,missed={}}
    local function frame(id,channel,tick,start,finish,payload,partial,limited)
        local key=id .. ":" .. channel;s.seq[key]=(s.seq[key] or 0)+1
        local sensor=channel=="audition" and "ear" or "eye"
        local f={frame_id=run .. ":" .. key .. ":" .. s.seq[key],agent_id=id,sensor_id=sensor,channel=channel,
            profile_id=profiles[id].profile_id,profile_revision=profiles[id].profile_revision,
            sensor_model_revision=channel=="vision_local" and "legacy_radius_v1" or channel=="vision_distant" and "sampled-surface-v0.2" or "direct_band_energy_v0",
            sample_seq=s.seq[key],clock_id="world-sim-v1",sampled_world_tick=tick,
            capture_window={kind=channel=="audition" and "interval" or "instant",start_us=start,end_us=finish},
            observer_frame_ref=run .. ":" .. id .. ":" .. sensor .. ":" .. tick,
            status="SAMPLED",coverage=partial and "PARTIAL" or "COMPLETE_WITHIN_PLAN",output_limited=limited or false,payload=payload}
        assert(#s.frames<108,"acquisition_budget")
        s.frames[#s.frames+1]=f;s.samples[#s.samples+1]={agent_id=id,channel=channel,tick=tick,time_us=start,frame_id=f.frame_id}
        return f
    end
    function s.local_frame(id,tick,now)
        if s.last_local[id]==tick then return nil end
        s.last_local[id]=tick
        local p=build(id,agents[id]);s.packets[id]=p;local o=p.observation
        return frame(id,"vision_local",tick,now,now,{visible_count=#o.visible_objects+#o.visible_places+#o.visible_agents},false,false)
    end
    function s.distant_frame(id,tick,now)
        local values,partial,limited=distant.sample(find("rdl_bridge:npc",id),profiles[id].vision_distant,targets[id])
        return frame(id,"vision_distant",tick,now,now,{features=values},partial,limited)
    end
    function s.sound(position,now,energy,except)
        for _,id in ipairs({"npc_a","npc_b"}) do
            if id~=except then
                local npc=find("rdl_bridge:npc",id);local ear=npc:get_pos()
                local factor=transmission.factor(ear,position)
                if not factor then hearing:mark_incomplete(id,now)
                else
                    local delta=vector.subtract(position,ear);local forward=core.yaw_to_dir(npc:get_yaw())
                    local right={x=forward.z,y=0,z=-forward.x}
                    local az=math.deg(math.atan2(vector.dot(delta,right),vector.dot(delta,forward)))
                    local bin=math.floor(az/30)*30
                    local pose=run .. ":" .. id .. ":ear-at:" .. now
                    hearing:emit(id,{occurred_us=now,duration_us=10000,cell_key=bin .. ":" .. pose,
                        observer_frame_ref=pose,azimuth_interval_deg={bin,bin+30},
                        low=0,mid=energy*factor/(1+(vector.length(delta)/4)^2),high=0})
                end
            end
        end
    end
    function s.close(now,enqueue,previous)
        -- At most the finite run's 24 windows; skipped acquisition steps are explicit gaps.
        local count=0
        while s.next_window+250000<=math.min(now,6000000) do
            local start=s.next_window;s.next_window=start+250000;count=count+1
            assert(count<=24,"window_budget")
            for _,id in ipairs({"npc_a","npc_b"}) do
                if now-previous>250000 then hearing:mark_incomplete(id,start) end
                local closed=hearing:close(id,start,profiles[id].audition)
                enqueue(id,frame(id,"audition",math.floor(start/250000),start,start+250000,
                    {detections=closed.detections},closed.incomplete,closed.incomplete))
            end
        end
    end
    return s
end
return M
