cargo_ground()=D("origins"=>Dict{Int,Any}(),"last"=>D(),"empty_at"=>Dict{Int,Int}(),"dropped"=>0,"recovered"=>0,"cross_actor"=>0,"records"=>Any[])

function cargo_transfer!(g,w,cargo,food,stock,a,op,now,kind;index=0)
    request=(kind=kind,index=index,position=w.positions[a])
    if haskey(g["last"],a)
        old=g["last"][a]
        if old.now==now
            check(old.op==op && old.request==request,"cargo_conflict");return old.status
        end
        check(now>old.now,"cargo_old_operation")
    end
    status="unavailable"
    if kind=="drop" && w.inventory[a]>0
        reusable=findfirst(i->stock[i]==0 && get(g["empty_at"],i,now)>=0 && get(g["empty_at"],i,now)<now,sort(collect(keys(g["origins"]))))
        ids=sort(collect(keys(g["origins"])))
        j=reusable===nothing ? length(food)+1 : ids[reusable]
        if reusable!==nothing || length(ids)<256
            p=w.positions[a];item=(x=p[1],z=p[2],stock=0,appearance="loose_food")
            if j>length(food);push!(food,item);push!(stock,0);else;food[j]=item;end
            source=popfirst!(cargo[a]);w.inventory[a]-=1;stock[j]=1
            g["origins"][j]=(source=source,dropper=a,drop_operation=op)
            g["dropped"]+=1;status="dropped"
        else
            status="ground_capacity"
        end
    elseif kind=="recover" && haskey(g["origins"],index) && stock[index]>0
        f=food[index];p=w.positions[a]
        if hypot(f.x-p[1],f.z-p[2])<=1.25 && !any(o->segment_hit(p,(Float64(f.x),Float64(f.z)),o,0.),w.obstacles)
            origin=g["origins"][index];stock[index]-=1;w.inventory[a]+=1;g["empty_at"][index]=now
            push!(cargo[a],origin.source);g["recovered"]+=1
            origin.dropper!=a && (g["cross_actor"]+=1)
            status="recovered"
        end
    end
    g["last"][a]=(now=now,op=op,request=request,status=status)
    push!(g["records"],D("actor"=>a,"operation"=>op,"kind"=>kind,"status"=>status,"us"=>now))
    length(g["records"])>32 && popfirst!(g["records"])
    status
end

function drop_candidates(samples,body,load,target)
    load>0 && target!==nothing || return Any[]
    out=Any[]
    for row in samples
        capacity=.6*(1-body.damage)/(1+.1*(load-1))
        row["height"]>row["capacity"]+1e-12 && row["height"]<=capacity+1e-12 || continue
        row["landing_clear"] && row["path_clear"] || continue
        step(body,"climb",load-1,row["resistance"],true)[2]=="performed" || continue
        angle=deg2rad(Float64(ANGLES[row["direction"]+1]))
        alignment=cos(atan(target["right"],target["forward"])-angle)
        push!(out,D("method"=>"drop_for_$(ANGLES[row["direction"]+1])","action"=>"drop",
            "priority"=>3.0+alignment-.2,"question"=>"load_reduced"))
    end
    out
end
