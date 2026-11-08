using Serialization,JSON3
const root=ARGS[1]
include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function main()
 rows=Any[]
 for day in sort(unique(vcat(collect(0:30:360),[67,70,79,240,244,245,275,288])))
  s=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world
  life=s.life;a=s.animals;R=G.RABBIT_LIFE
  mature(i)=s.ticks-life.born[i]>=R.maturity_days*R.day_ticks
  function counts(ids)
   (female=count(i->life.sex[i]==1,ids),male=count(i->life.sex[i]==2,ids),adult_female=count(i->life.sex[i]==1&&mature(i),ids),adult_male=count(i->life.sex[i]==2&&mature(i),ids),pregnant=count(i->life.due[i]>0,ids),adult_female_energy_ready=count(i->life.sex[i]==1&&mature(i)&&a.energy[i]>=R.breeding_energy,ids))
  end
  alive=findall(s.alive);west(i)=a.x[i]<12+5sin((a.z[i]-6)/22+s.world.phase)
  absolute_day=div(s.ticks,R.day_ticks)
  row=(day,absolute_day,season_phase=mod(absolute_day,R.year_days),breeding_season=mod(absolute_day,R.year_days)<R.season_days,total=counts(alive),west=counts(filter(west,alive)),east=counts(filter(i->!west(i),alive)),conceptions=life.conceptions,births=life.births)
  push!(rows,row);println(JSON3.write(row));flush(stdout)
 end
 write(ARGS[2],JSON3.write((root,rule=G.RABBIT_LIFE,rows)))
end
main()
