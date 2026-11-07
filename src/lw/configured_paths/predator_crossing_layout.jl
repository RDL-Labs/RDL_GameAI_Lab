# 暫定固定の実験初期配置のみ。明示呼出し時ON。通常世界では使用しない。
# 真の岸/草地で兎を20:80へ配置し母子を同居。行動/認知には配置情報を渡さない。
const CROSSING_LAYOUT=(west_rabbits=20,seed=20261108,bank_margin=3.)
function configured_crossing_layout!(s)
    w=s.world;a=s.animals;life=s.life;r=CROSSING_LAYOUT;rng=Random.Xoshiro(r.seed)
    west(p)=p[1]<12+5sin((p[2]-6)/22+w.phase)
    candidates=filter(k->w.walkable[k] && w.capacity[k]>0 &&
        abs(H.center(w,k)[1]-(12+5sin((H.center(w,k)[2]-6)/22+w.phase)))>r.bank_margin,eachindex(w.walkable))
    banks=Dict(side=>shuffle(rng,filter(k->west(H.center(w,k))==side,candidates)) for side in (true,false))
    used=Dict(true=>0,false=>0);remaining=r.west_rabbits
    for i in eachindex(s.alive)
        life.mother[i]>0 && continue
        family=vcat(i,findall(==(i),life.mother));side=length(family)<=remaining
        side && (remaining-=length(family))
        used[side]+=1;k=banks[side][used[side]];position=H.center(w,k)
        for j in family
            a.x[j],a.z[j]=position;a.current_cell[j]=k;a.previous_cell[j]=0;a.target[j]=0;a.next_sense[j]=0
            life.nest[j]=position
        end
    end
    @assert remaining==0
    @assert count(i->west((a.x[i],a.z[i])),eachindex(s.alive))==r.west_rabbits
    s
end
