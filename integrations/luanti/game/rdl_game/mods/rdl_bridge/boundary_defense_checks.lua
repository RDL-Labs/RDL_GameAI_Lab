return function(module)
    local checks=0
    local function test(value) assert(value);checks=checks+1 end
    local c={run_id="run",world_epoch=1,defender="A",actor="B",site_ref="site",clock_id="clock"}
    local n=table.copy(c);n.notice_id="notice";n.capture_us=100
    local p=table.copy(c);p.notice_id=n.notice_id;p.capture_us=100;p.operation_id="notice:warning";p.expires_us=1000100;p.duration_us=250000
    local value,count="",0
    local trial
    local adapter={set=function(v) value=v;if v=="WARNING" then count=count+1;test(not trial:consume(p,n,200)) end end,get=function() return value end}
    trial=module.new(c,adapter)
    for _,k in ipairs({"run_id","world_epoch","defender","actor","site_ref","clock_id","notice_id","operation_id","capture_us","expires_us","duration_us"}) do
        local bad=table.copy(p);bad[k]="foreign";test(not trial:consume(bad,n,200));test(count==0)
    end
    test(not trial:consume(p,n,99))
    test(trial:consume(p,n,1000100));test(count==1 and value=="WARNING")
    trial:step(1250099);test(value=="WARNING" and trial.result==nil)
    trial:step(1250100);test(value=="" and trial.result.status=="displayed")
    test(not trial:consume(p,n,1250101));test(count==1)
    local expired=module.new(c,adapter)
    local applied,reason=expired:consume(p,n,1000101)
    test(not applied and reason=="action_expired");test(expired.count==0 and expired.result.status=="action_expired")
    test(not expired:consume(p,n,1000100));test(count==1)
    local other=table.copy(n);other.actor="C"
    local fresh=module.new(c,adapter);test(not fresh:consume(p,other,200));test(fresh.consumed==nil)
    return checks
end
