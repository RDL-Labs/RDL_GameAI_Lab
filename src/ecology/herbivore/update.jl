function target!(w,a,i,t,policy=StateMachinePolicy())
    observations=observe_neighbors!(w,a,i,t)
    a.target[i]=choose_target(policy,observations,a.heading[i],a.previous_cell[i])
    a.next_sense[i]=t+10
end

function prepare_requests!(w,a,t,demand,requests,active,threat,policy)
    fill!(demand,0.); empty!(active)
    n=length(a.x)
    for i in 1:n
        dig=min(a.gut[i],.02); a.gut[i]-=dig; a.digested[i]+=dig
        a.energy[i]=min(100.,a.energy[i]+3dig)
        a.sleepy[i]=a.state[i]==SLEEP ? max(0.,a.sleepy[i]-1/1200) : min(2.,a.sleepy[i]+1/4000)
        observation=observe_state!(w,a,i,t,threat); k=observation.cell
        a.state[i]=choose_state(policy,observation)
        requests[i]=a.state[i]==GRAZE ? min(.025,4-a.gut[i]) : 0.
        if requests[i]>0
            demand[k]==0 && push!(active,k)
            demand[k]+=requests[i]
        end
    end
end

function allocate_grass!(w,demand,ratio,active)
    # Simultaneous proportional allocation prevents first-agent access bias.
    for k in active
        amount=min(w.grass[k],demand[k]); ratio[k]=amount/demand[k]
        w.grass[k]-=amount; w.eaten+=amount
    end
end

function apply_actions!(w,a,t,ratio,requests,threat,policy)
    for i in eachindex(a.x)
        state=a.state[i]; k=cell(w,a.x[i],a.z[i]); a.counts[i,state]+=1
        if state==GRAZE
            amount=requests[i]*ratio[k]; a.gut[i]+=amount; a.consumed[i]+=amount
        elseif state==SEARCH || state==FLEE
            if state==FLEE
                a.heading[i]=atan(a.z[i]-threat[2],a.x[i]-threat[1])
            else
                (t>=a.next_sense[i] || a.target[i]==0) && target!(w,a,i,t,policy)
                if a.target[i]!=0
                    p=center(w,a.target[i]); a.heading[i]=atan(p[2]-a.z[i],p[1]-a.x[i])
                end
            end
            speed=state==FLEE ? .6 : .2
            p=(a.x[i],a.z[i]); q=(p[1]+speed*cos(a.heading[i]),p[2]+speed*sin(a.heading[i]))
            if clear(w,p,q)
                a.x[i],a.z[i]=q; a.distance[i]+=speed
                next=cell(w,q...)
                if next!=a.current_cell[i]; a.previous_cell[i]=a.current_cell[i]; a.current_cell[i]=next; end
            else
                a.heading[i]+=pi/2; a.target[i]=0; a.next_sense[i]=t+10; a.blocked[i]+=1
            end
        end
        cost=state==SLEEP ? .002 : state==SEARCH ? .012 : state==FLEE ? .03 : .0047
        a.energy[i]=max(0.,a.energy[i]-cost)
        a.energy[i]==0 && (a.starvation_ticks[i]+=1)
    end
end

# One authoritative tick order. Resource arbitration precedes every action.
function step!(w,a,t,demand,ratio,requests,active;threat=nothing,policy=StateMachinePolicy())
    prepare_requests!(w,a,t,demand,requests,active,threat,policy)
    allocate_grass!(w,demand,ratio,active)
    apply_actions!(w,a,t,ratio,requests,threat,policy)
end
