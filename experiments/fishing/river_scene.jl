# Authored world fixture, not a policy or forced travel route.
function add_river_fishing!(scene;total=240,catch_profile="ordinary")
 catch_profile in ("ordinary","relaxed","abundant") || error("unknown catch profile")
 land=scene["landscape"];phase=land["phase"]
 points=Tuple{Float64,Float64}[]
 for z in -12.:3.:33.
  center=12+5sin((z-6)/22+phase)
  width=1.2+.4*(1+sin(z/13))
  for side in (-1.,1.)
   x=center+side*(width/2+.8)
   clear=all(o->!get(o,"solid",true) || hypot(x-o["x"],z-o["z"])>get(o,"radius",.5)+.65,scene["obstacles"])
   if clear;push!(points,(x,z));break;end
  end
 end
 length(points)>=8 || error("insufficient clear river bank positions")
 rates=[(.02,.03,.04,.05)[mod1(i,4)] for i in eachindex(points)]
 rates[div(length(points),3)]=.10;rates[div(2length(points),3)]=.15;rates[end]=.25
 if catch_profile=="relaxed"
  rates=[(.05,.06,.07,.08)[mod1(i,4)] for i in eachindex(points)]
  rates[div(length(points),3)]=.15;rates[div(2length(points),3)]=.20;rates[end]=.30
 end
 if catch_profile=="abundant"
  rates=[(.50,.55,.60,.65)[mod1(i,4)] for i in eachindex(points)]
  rates[div(length(points),3)]=.70;rates[div(2length(points),3)]=.75;rates[end]=.80
 end
 cells=Any[]
 for (i,(x,z)) in enumerate(points)
  push!(cells,Dict("x"=>x,"z"=>z,"stock"=>div(total,length(points))+(i<=mod(total,length(points))),
   "renewable"=>false,"food_kind"=>5,"appearance"=>"river_water","acquisition"=>"fishing",
   "river_id"=>"main_river","fishing_base_probability"=>rates[i],"fishing_radius"=>7.5))
 end
 append!(scene["food"],cells)
 Dict("catch_profile"=>catch_profile,"total_stock"=>sum(f["stock"] for f in cells),"sites"=>length(cells),"base_probabilities"=>rates,
  "radius"=>7.5,"placement"=>"existing riparian river, clear bank points","renewal"=>false)
end
