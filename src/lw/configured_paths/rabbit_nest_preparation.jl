# 暫定固定の出産前準備。既定ON、enabled=falseで旧「現在地出産」へ戻す。
# 妊娠残日数と近傍の草/衝突判定を直接参照する認知ショートカット。
# 母の既存nest欄を候補記憶に使用。出産後の子のnestは実際の出生位置。
# 将来は観測された場所MB・安全性・掘削コストと共通の選択/学習へ置換。
const RABBIT_NEST_PREPARATION=(enabled=true,lead_days=3,observe_radius=8.,
    forage_radius=3.,distance_cost=.12,choice_temperature=.5,
    minimum_reserve=70.,sleep_limit=1.,arrival_radius=.6)
# 暫定固定: 境界帯には巣を作らない。既定ON。世界境界の直接参照。
# 反発幅8+身体余白0.25を共用。将来は場所の安全性MBへ置換。
# 巣設置の制約であり、出産という身体現象は止めない。
const RABBIT_NEST_BOUNDARY=(enabled=true,)
# 暫定身体ルール: 予定日の最初の日次処理で現在地出産。場所待ちによる延期なし。
# postpone_for_site=trueは旧挙動比較専用。将来は分娩時間・身体状態のモデルへ置換。
# 旧保存の超過妊娠も次の日次処理で終了し、遡及出生・追加投資はしない。
const RABBIT_BIRTH_TIMING=(postpone_for_site=false,)
# 暫定固定: 出産準備期の母親を境界帯から通常移動で内側へ誘導する。
# 採食・休息より優先、既存の危険割込みは維持。世界境界を直接参照。
# enabled=falseで従来の勾配のみ。将来は安全な出産場所を探すMBへ置換。
const RABBIT_MATERNAL_BOUNDARY=(enabled=true,)
function configured_maternal_boundary_goal(s,mother,t)
    RABBIT_MATERNAL_BOUNDARY.enabled && s.life!==nothing && s.alive[mother] || return nothing
    due=s.life.due[mother]
    due>0 && due-t<=RABBIT_NEST_PREPARATION.lead_days*RABBIT_LIFE.day_ticks || return nothing
    w=s.world;a=s.animals;p=(a.x[mother],a.z[mother])
    margin=H.WILDLIFE_BOUNDARY.width+H.WILDLIFE_BOUNDARY.body_margin
    min(p[1]-w.xmin,w.xmax-p[1],p[2]-w.zmin,w.zmax-p[2])<margin || return nothing
    inset=margin+RABBIT_NEST_PREPARATION.arrival_radius
    (clamp(p[1],w.xmin+inset,w.xmax-inset),clamp(p[2],w.zmin+inset,w.zmax-inset))
end
configured_rabbit_birth_ready(s,mother,t)=t>=s.life.due[mother] &&
    (!RABBIT_BIRTH_TIMING.postpone_for_site || configured_rabbit_nest_allowed(s.world,(s.animals.x[mother],s.animals.z[mother])))
function configured_rabbit_nest_allowed(w,p;enabled=RABBIT_NEST_BOUNDARY.enabled,extra_margin=0.)
    H.material(w.phase,p...)==H.WATER && return false
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
        score=log1p(food/max(1,cells))-r.distance_cost*H.configured_rabbit_terrain_distance(w,origin,p)
        push!(candidates,(position=p,score=score,observed_grass=food))
    end
    candidates
end
function configured_rabbit_nest_preparation!(s,t;enabled=RABBIT_NEST_PREPARATION.enabled)
    enabled && s.life!==nothing || return
    life=s.life;a=s.animals;r=RABBIT_NEST_PREPARATION
    for mother in eachindex(s.alive)
        s.alive[mother] && life.due[mother]>0 && life.due[mother]-t<=r.lead_days*RABBIT_LIFE.day_ticks || continue
        boundary_goal=configured_maternal_boundary_goal(s,mother,t)
        if boundary_goal!==nothing && s.overrides[mother]==0 && a.energy[mother]>0
            s.overrides[mother]=H.SEARCH
            a.target[mother]=H.cell(s.world,boundary_goal...);a.next_sense[mother]=t+1
            continue
        end
        # 暫定固定: 日次の再確認で、境界条件だけでなく現在地からの通行不能も
        # 再選択理由にする。毎tickの全候補生成は避ける。将来は場所MBの失敗評価へ。
        origin=(a.x[mother],a.z[mother])
        if t==max(0,life.due[mother]-r.lead_days*RABBIT_LIFE.day_ticks) || (t%RABBIT_LIFE.day_ticks==0 && (!configured_rabbit_nest_allowed(s.world,life.nest[mother]) || !H.clear(s.world,origin,life.nest[mother])))
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
