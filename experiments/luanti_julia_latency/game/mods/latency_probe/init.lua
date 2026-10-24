local http = assert(core.request_http_api(), "HTTP permission required")
local count = tonumber(core.settings:get("probe_agents")) or 3
local rows, actors = {}, {}
local pending, peak, skipped, errors, sent, received = 0, 0, 0, 0, 0, 0
local seq, elapsed, clock, finishing = 0, 0, 0, false
for i=1,count do actors[i]={state=1,busy=false} end
local function finish()
  if finishing then return end
  finishing=true
  local f=assert(io.open(core.get_worldpath().."/latency.json","w"))
  f:write(core.write_json({agents=count,rows=rows,sent=sent,received=received,
    errors=errors,pending=pending,peak_pending=peak,skipped=skipped,elapsed=elapsed}))
  f:close()
  core.request_shutdown("finite latency experiment complete",false,0)
end
core.register_globalstep(function(dt)
  elapsed=elapsed+dt
  if elapsed>=22 then
    if pending==0 or elapsed>=30 then finish() end
    return
  end
  clock=clock+dt
  if clock<0.25 then return end
  clock=clock-0.25; seq=seq+1
  for i=1,count do
    local a=actors[i]
    if a.busy then skipped=skipped+1 else
      a.busy=true; pending=pending+1; peak=math.max(peak,pending); sent=sent+1
      local s=seq
      local threat=s%12==0
      local grass=s%3==0 and 0 or 1
      local expected=threat and 5 or (grass==0 and 1 or 2)
      local start=core.get_us_time()
      http.fetch({url="http://127.0.0.1:18765/observe",method="POST",timeout=5,
        extra_headers={"Content-Type: application/json"},
        data=core.write_json({id=i,seq=s,old=a.state,energy=70,gut=0,sleepy=0,grass=grass,threat=threat})},function(r)
        local rtt=(core.get_us_time()-start)/1000
        a.busy=false; pending=pending-1; received=received+1
        local data=r.succeeded and r.code==200 and core.parse_json(r.data) or nil
        local ok=data and data.decision.id==i and data.decision.seq==s and data.decision.state==expected
        if ok then a.state=data.decision.state else errors=errors+1 end
        rows[#rows+1]={id=i,seq=s,rtt_ms=rtt,processing_us=data and data.processing_us or -1,ok=not not ok}
      end)
    end
  end
end)
