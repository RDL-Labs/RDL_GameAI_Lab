# 暫定固定の出産前準備。既定ON、enabled=falseで旧「現在地出産」へ戻す。
# 妊娠残日数と近傍の草/衝突判定を直接参照する認知ショートカット。
# 母の既存nest欄を候補記憶に使用。出産後の子のnestは実際の出生位置。
# 将来は観測された場所MB・安全性・掘削コストと共通の選択/学習へ置換。
const RABBIT_NEST_PREPARATION=(enabled=true,lead_days=3,observe_radius=8.,
    forage_radius=3.,distance_cost=.12,choice_temperature=.5,
    minimum_reserve=70.,sleep_limit=1.,arrival_radius=.6)
# 暫定固定: 境界帯には巣を作らない。既定ON。世界境界の直接参照。
# 反発幅8+身体余白0.25を共用。将来は場所の安全性MBへ置換。
# 出産予定日に圏外なら出産を保留し、通常移動で巣準備を続ける。
# 保留中に妊娠投資を増やさない。出生位置の瞬間移動は行わない。
const RABBIT_NEST_BOUNDARY=(enabled=true,)
function configured_rabbit_nest_allowed(w,p;enabled=RABBIT_NEST_BOUNDARY.enabled,extra_margin=0.)
    !enabled && return true
    margin=H.WILDLIFE_BOUNDARY.width+H.WILDLIFE_BOUNDARY.body_margin+extra_margin
    min(p[1]-w.xmin,w.xmax-p[1],p[2]-w.zmin,w.zmax-p[2])>=margin
end
function configured_rabbit_nest_candidates(s,mother,t)
    w=s.world;a=s.animals;r=RABBIT_NEST_PREPARATION;origin=(a.x[mother],a.z[mother])
    visible=Int[];reach=ceil(Int,r.observe_radius/w.cellsize)
    cell=H.cell(w,origin...);ix=mod(cell-1,w.nx)+1;iz=div(cell-1,w.nx)+1
    for dz in -reach:reach,dx in -reach:reach
        jx=ix+dx;jz=iz+dz
        1<=jx<=w.nx && 1<=jz<=w.nz || continue
        k=jx+(jz-1)*w.nx;p=H.center(w,k)
        w.walkable[k] && hypot(p[1]-origin[1],p[2]-origin[2])<=r.observe_radius && H.clear(w,origin,p) && push!(visible,k)
    end
    observed_grass=[H.grass!(w,k,t) for k in visible]
    candidates=NamedTuple[]
    for k in visible
        p=H.center(w,k);food=0.;cells=0
        configured_rabbit_nest_allowed(w,p;extra_margin=r.arrival_radius) || continue
        for (slot,j) in enumerate(visible)
            q=H.center(w,j)
            hypot(p[1]-q[1],p[2]-q[2])<=r.forage_radius && H.clear(w,p,q) || continue
            food+=observed_grass[slot];cells+=1
        end
        score=log1p(food/max(1,cells))-r.distance_cost*hypot(p[1]-origin[1],p[2]-origin[2])
        push!(candidates,(position=p,score=score,observed_grass=food))
    end
    candidates
end
function configured_rabbit_nest_preparation!(s,t;enabled=RABBIT_NEST_PREPARATION.enabled)
    enabled && s.life!==nothing || return
    life=s.life;a=s.animals;r=RABBIT_NEST_PREPARATION
    for mother in eachindex(s.alive)
        s.alive[mother] && life.due[mother]>0 && life.due[mother]-t<=r.lead_days*RABBIT_LIFE.day_ticks || continue
        # One observation/choice per pregnancy, or the initial late-pregnancy fixture.
        if t==max(0,life.due[mother]-r.lead_days*RABBIT_LIFE.day_ticks) || (t%RABBIT_LIFE.day_ticks==0 && !configured_rabbit_nest_allowed(s.world,life.nest[mother]))
            life.nest[mother]=(a.x[mother],a.z[mother])
            if s.overrides[mother]==0
                candidates=configured_rabbit_nest_candidates(s,mother,t)
                if !isempty(candidates)
                    peak=maximum(c.score for c in candidates)
                    weights=[exp((c.score-peak)/r.choice_temperature) for c in candidates]
                    draw=rand(life.rng)*sum(weights);selected=length(candidates)
                    for j in eachindex(weights)
                        draw-=weights[j]
                        if draw<=0;selected=j;break;end
                    end
                    life.nest[mother]=candidates[selected].position
                end
            end
        end
        s.overrides[mother]==0 && a.energy[mother]>=r.minimum_reserve && a.sleepy[mother]<r.sleep_limit && a.state[mother]!=H.SLEEP || continue
        goal=life.nest[mother];origin=(a.x[mother],a.z[mother])
        H.clear(s.world,origin,goal) || continue
        hypot(origin[1]-goal[1],origin[2]-goal[2])>r.arrival_radius || continue
        s.overrides[mother]=H.SEARCH;a.target[mother]=H.cell(s.world,goal...);a.next_sense[mother]=t+1
    end
end
