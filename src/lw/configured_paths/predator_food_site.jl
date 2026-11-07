# 暫定認知係数。cognition有効時に既定ON、enabled=falseで更新/反発OFF。
# 自己位置と既知餌場の距離だけを用いる（未観測の獲物数は読まない）。
# 半径8m・探索600tickは既存place_cell/episode_ticksを再利用。
# 将来は場所の広がりと探索時間を経験/ρから推定する。行動の強制/禁止はしない。
const PREDATOR_FOOD_SITE=(enabled=true,scale=.25,tau=3.,max_exponent=8.)
food_site_key(site,field)="food_site:"*site*":"*field
function predator_food_site_repulsion(mind,site)
    r=PREDATOR_FOOD_SITE
    r.enabled || return 0.
    unresolved=get(mind.estimates,food_site_key(site,"unresolved"),0.)
    r.scale*expm1(min(r.max_exponent,unresolved/r.tau))
end
function predator_near_food_site(mind,p)
    body=p.visual.body;nearest=nothing;distance=PREDATOR_COGNITION.place_cell
    for site in sort!(collect(keys(mind.places)))
        place=mind.places[site];place.kind=="food" || continue
        d=hypot(place.x-body.x,place.z-body.z)
        if d<=distance;nearest=site;distance=d;end
    end
    nearest
end
# One actual hunting tick belongs to at most one remembered site. Partial effort
# persists across replanning; reaching/visiting/resting never counts as a failed search.
function predator_food_site_effort!(mind,p;elapsed=1.)
    PREDATOR_FOOD_SITE.enabled || return
    site=predator_near_food_site(mind,p);site===nothing && return
    effort_key=food_site_key(site,"effort_ticks");u_key=food_site_key(site,"unresolved")
    effort=get(mind.estimates,effort_key,0.)+elapsed
    episodes=floor(effort/PREDATOR_COGNITION.episode_ticks)
    mind.estimates[effort_key]=effort-episodes*PREDATOR_COGNITION.episode_ticks
    mind.estimates[u_key]=get(mind.estimates,u_key,0.)+episodes
end
function predator_food_site_gain!(mind,p,food_gain)
    PREDATOR_FOOD_SITE.enabled || return
    site=predator_near_food_site(mind,p);site===nothing && return
    u_key=food_site_key(site,"unresolved")
    # Initial hunt estimate is a normalization, not a capture reward. Small meals
    # relieve less than a full expected meal; past unsuccessful effort is not erased.
    relief=max(0.,food_gain)/(PREDATOR_COGNITION.hunt_prior*PREDATOR_COGNITION.food_value_scale)
    effort_key=food_site_key(site,"effort_ticks")
    unresolved=get(mind.estimates,u_key,0.)+get(mind.estimates,effort_key,0.)/PREDATOR_COGNITION.episode_ticks
    remaining=max(0.,unresolved-relief)
    mind.estimates[u_key]=floor(remaining)
    mind.estimates[effort_key]=(remaining-floor(remaining))*PREDATOR_COGNITION.episode_ticks
end
