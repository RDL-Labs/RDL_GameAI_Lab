# World-side equipment availability. Capability is not an actor's learned recipe.
function food_facilities(spec)
 facilities=collect(get(spec,:food_facilities,Any[]))
 ids=Int[]
 for f in facilities
  f.id isa Integer && f.id>0 && !(f.id in ids) || error("food facility unique positive id")
  push!(ids,f.id)
  get(f,:accepts_waste,false) isa Bool || error("accepts_waste must be Bool")
  all(isfinite,(f.x,f.z,f.work_radius,f.height,f.radius)) && f.work_radius>0 && f.height>0 && f.radius>0 || error("food facility geometry")
  all(k->k isa Integer && k in RDLBody.FOOD_KIND_IDS && RDLBody.FOOD_PROCESS_OUTPUT[k]!=0,f.processing_kinds) || error("food facility recipe kinds")
 end
 facilities
end
function food_facility_for(facilities,position,kind)
 for f in facilities
  kind in f.processing_kinds && hypot(position[1]-f.x,position[2]-f.z)<=f.work_radius && return f
 end
 nothing
end
food_facility_visuals(facilities)=[(x=f.x,z=f.z,height=f.height,radius=f.radius,color=f.color,solid=false,light_source=0.) for f in facilities]

food_waste_total(r)=r===nothing ? 0 : sum(r.waste["counts"])
function food_disposal_for(facilities,position)
 findfirst(f->get(f,:accepts_waste,false) && hypot(position[1]-f.x,position[2]-f.z)<=f.work_radius,facilities)
end
# Physical transfer, independent of the actor's judgement of the food.
function food_discard!(r,w,cargo,stores,facilities,a,kind,quality,at_home,shared_stores,op,now)
 last=get(r.waste["last"],a,nothing)
 request=(kind,quality,at_home,shared_stores,w.positions[a])
 if last!==nothing
  now==last.now && (last.op==op && last.request==request ? (return last.status) : error("discard conflict"))
  now>last.now || error("old discard operation")
 end
 facility=food_disposal_for(facilities,w.positions[a]);status="disposal_unavailable"
 if facility!==nothing
  i=findfirst(i->r.inventory[a][i]==kind && food_quality(r,a,i)==quality,eachindex(r.inventory[a]))
  owner=shared_stores ? "shared" : a;stock=shared_stores ? r.shared : r.personal[a]
  if i!==nothing
   food_remove!(r,a,i);deleteat!(cargo[a],i);w.inventory[a]-=1;status="discarded"
  elseif at_home && food_stored_quality_count(r,a,stock,kind,quality)>0
   food_quality_store_take!(r,owner,kind,stock[kind];q=quality);stock[kind]-=1
   shared_stores || (stores[a]-=1)
   status="discarded"
  end
  if status=="discarded"
   r.waste["counts"][kind]+=1
   bin=get!(() -> zeros(Int,length(RDLBody.FOOD_KIND_IDS)),r.waste["facilities"],string(facilities[facility].id))
   bin[kind]+=1
  end
 end
 r.waste["last"][a]=(now=now,op=op,request=request,status=status)
 push!(r.waste["records"],D("actor"=>a,"kind"=>kind,"quality"=>quality,"status"=>status,"us"=>now,"facility"=>facility===nothing ? nothing : facilities[facility].id))
 length(r.waste["records"])>64 && popfirst!(r.waste["records"])
 status
end
