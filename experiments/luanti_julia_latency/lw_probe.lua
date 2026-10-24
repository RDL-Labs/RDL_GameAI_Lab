local http=assert(core.request_http_api())
local rows={}
local seq,busy,ended=0,false,false
local started=core.get_us_time()
local function save(ok,reason)
  if ended then return end
  ended=true
  local f=assert(io.open(core.get_worldpath().."/latency.json","w"))
  f:write(core.write_json({ok=ok,reason=reason,rows=rows,elapsed_ms=(core.get_us_time()-started)/1000}))
  f:close()
  core.request_shutdown("LW latency experiment ended",false,0)
end
core.register_globalstep(function()
  if busy or ended then return end
  seq=seq+1;busy=true
  local sent=core.get_us_time()
  http.fetch({url="http://127.0.0.1:18765/step",method="POST",timeout=30,
    extra_headers={"Content-Type: application/json"},data=core.write_json({seq=seq})},function(r)
    local rtt=(core.get_us_time()-sent)/1000
    local data=r.succeeded and r.code==200 and core.parse_json(r.data) or nil
    if not data or data.error then save(false,data and data.error or "HTTP failure");return end
    if data.complete then save(data.full_result_equal,"complete");return end
    if data.seq~=seq or not data.matched then save(false,"sequence/parity failure");return end
    rows[#rows+1]={seq=seq,rtt_ms=rtt,compute_ms=data.compute_ms}
    busy=false
  end)
end)
