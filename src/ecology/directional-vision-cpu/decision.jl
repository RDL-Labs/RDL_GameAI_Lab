function decide!(p,observations,t,rng)
    if p.state==REST || p.state==RECOVER
        p.timer-=1
        if p.timer<=0; p.state=SEARCH; end
    elseif p.state!=ATTACK
        best=0;dmin=Inf;seen=nothing
        for o in observations
            if o.distance<dmin;best=o.id;dmin=o.distance;seen=o;end
        end
        if best!=0
            p.target=best; p.seen_x=seen.x; p.seen_z=seen.z; p.expires=t+20
            p.state=CHASE
        elseif t>=p.expires
            p.target=0; p.state=SEARCH; p.pursuit=0
        end
        if p.state==CHASE
            p.heading=atan(p.seen_z-p.z,p.seen_x-p.x); p.pursuit+=1
            if p.pursuit>=60
                recover!(p)
            elseif best!=0 && dmin<=2.5
                p.state=ATTACK; p.timer=3; p.attacks+=1
            end
        elseif t%20==0
            p.heading+=(rand(rng)-.5)*pi
        end
    end
    p.counts[p.state]+=1
end
