using Serialization,JSON3
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
records=Any[]
for day in (0,30,60,90,120,150,180,210,450)
 folder=day<=90 ? root : ARGS[2];localday=day<=90 ? day : day-90
 saved=deserialize(joinpath(folder,"checkpoints/day-"*lpad(localday,3,'0')*".jls"));s=saved.world;a=s.animals;l=s.life;t=s.ticks
 rows=Any[]
 for side in ("all","west","east")
  ids=[i for i in eachindex(s.alive) if s.alive[i] && (side=="all" || (a.x[i]<12+5sin((a.z[i]-6)/22+s.world.phase))==(side=="west"))]
  adult=[i for i in ids if t-l.born[i]>=G.RABBIT_LIFE.maturity_days*17280]
  females=filter(i->l.sex[i]==1,adult);males=filter(i->l.sex[i]==2,adult)
  push!(rows,(side,alive=length(ids),female=count(i->l.sex[i]==1,ids),male=count(i->l.sex[i]==2,ids),adult_female=length(females),adult_male=length(males),pregnant=count(i->l.due[i]>0,ids),recovering=count(i->t<l.next_mate[i],females),female_mean_energy=isempty(females) ? nothing : sum(a.energy[females])/length(females),near_male=count(i->any(j->hypot(a.x[i]-a.x[j],a.z[i]-a.z[j])<=G.RABBIT_LIFE.mate_radius && H.clear(s.world,(a.x[i],a.z[i]),(a.x[j],a.z[j])),males),females)))
 end
 survivors=day==450 ? [(id=i,sex=l.sex[i],age=(t-l.born[i])/17280,energy=a.energy[i],position=(a.x[i],a.z[i])) for i in findall(s.alive)] : nothing
 push!(records,(day,regions=rows,survivors))
end
write(ARGS[3],JSON3.write(records));println(JSON3.write(records))
