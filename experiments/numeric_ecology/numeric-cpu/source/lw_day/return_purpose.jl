# A local parent-purpose lifetime; method success cannot end it.
return_purpose()=D("active"=>false,"started_us"=>nothing,"entries"=>0,"completed"=>0)
function returning!(s,phase,load,at_home,now)
    if s["active"] && at_home && load==0
        s["active"]=false;s["completed"]+=1
    end
    triggered=phase in ("return","night") || load>=6
    if !s["active"] && triggered && (!at_home || load>0)
        s["active"]=true;s["started_us"]=now;s["entries"]+=1
    end
    # Scheduled home rest remains the existing policy after completion.
    s["active"] || triggered
end
