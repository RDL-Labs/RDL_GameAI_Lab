using JSON3, Test, SHA
const root=normpath(joinpath(@__DIR__,"../.."))
const out=abspath(ARGS[1]);ispath(out) && error("fresh output required");mkpath(out)
const stop_exhausted="--stop-exhausted" in ARGS
const prepare_only="--prepare-only" in ARGS
const days_arg=findfirst(==("--days"),ARGS)
const run_days=days_arg===nothing ? 3 : parse(Int,ARGS[days_arg+1])
@assert 1<=run_days<=30
const snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(root,"src"),joinpath(snapshot,"src"))
cp(joinpath(root,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
const path=joinpath(snapshot,"src/lw/simulation/day.jl")
const original=read(path,String)
const anchor="        advance_physiology!(w,metabolism,guts,food_body)"
@assert count(anchor,original)==1
patched=replace(original,anchor=>anchor*"\n        Main.gate_probe!(sec,w,purposes,counts,spec.home)")
if stop_exhausted
    daily_anchor="\"shared_stock\"=>shared,\"ground\"=>sum(stock),\"consumed\"=>w.consumed,\"replenished_food\"=>replenished))"
    @assert count(daily_anchor,patched)==1
    patched=replace(patched,daily_anchor=>daily_anchor*"\n            if Main.cohort_exhausted(daily,clock.day_us)\n                days=length(daily)\n                Main.stop_day[]=days\n                break\n            end")
end
write(path,patched)
const stop_day=Ref(0)
function cohort_exhausted(daily,day_us)
    last=daily[end];previous=length(daily)>1 ? daily[end-1]["counts"] : nothing
    all(a->last["physical"][a]["body"]["reserve"]<=0 &&
        get(last["counts"][a],"rest",0)-(previous===nothing ? 0 : get(previous[a],"rest",0))==div(day_us,1_000_000),keys(last["physical"]))
end
const current=Ref("")
const logref=Ref{IO}()
const prev=Dict{String,Tuple{Float64,Float64}}()
const crossings=Any[]
const maxradius=Dict{String,Float64}()
const positions=Any[]
const started=Ref(0.)
function gate_probe!(sec,w,purposes,counts,home)
    for a in keys(w.positions)
        p=w.positions[a];r=hypot(p[1]-home[1],p[2]-home[2]);maxradius[a]=max(get(maxradius,a,0.),r)
        if haskey(prev,a)
            old=prev[a];before=hypot(old[1]-home[1],old[2]-home[2])
            if (before<=5 && r>5) || (before>5 && r<=5)
                event=(sec=sec+1,actor=a,direction=r>5 ? "out" : "in",from=old,to=p,return_active=purposes[a]["active"])
                push!(crossings,event);JSON3.write(logref[],event);println(logref[]);flush(logref[])
            end
        end
        prev[a]=p
        ("--trace-every-tick" in ARGS || mod(sec+1,60)==0) && push!(positions,(sec=sec+1,actor=a,position=p,reserve=w.bodies[a].reserve,return_active=purposes[a]["active"]))
    end
    if mod(sec+1,17280)==0
        println("$(current[]) DAY $(div(sec+1,17280)) elapsed=$(round(time()-started[],digits=1))s");flush(stdout)
    end
end
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
include(joinpath(@__DIR__,"food_roads.jl"))
const base=JSON3.read(read(joinpath(root,"experiments/julia_migration/lw_integrated/search_review_spec.json"),String),Dict{String,Any})
base["config"]["days"]=run_days
rho_arg=findfirst(==("--rho"),ARGS)
base["config"]["rho_profile"]=rho_arg===nothing ? "off" : ARGS[rho_arg+1]
openings_arg=findfirst(==("--rho-openings"),ARGS)
base["config"]["rho_openings"]=openings_arg===nothing ? "on" : ARGS[openings_arg+1]
food_roads_arg=findfirst(==("--food-roads"),ARGS)
food_roads_mode=food_roads_arg===nothing ? "unchanged" : ARGS[food_roads_arg+1]
@assert food_roads_mode in ("unchanged","off","on")
cue_arg=findfirst(==("--general-landmarks"),ARGS)
base["config"]["general_landmarks"]=cue_arg===nothing ? "off" : ARGS[cue_arg+1]
@assert base["config"]["general_landmarks"] in ("off","on")
const reports=Any[]
for (label,omitted) in (("wide",Set([0,1,23])),("narrow",Set([0])))
    "--narrow-only" in ARGS && label!="narrow" && continue
    stop_day[]=0
    current[]=label;empty!(prev);empty!(crossings);empty!(maxradius);empty!(positions)
    input=deepcopy(base);home=input["scene"]["home"]
    stones=[D("x"=>home[1]+5sin(2pi*i/24),"z"=>home[2]-5cos(2pi*i/24),"radius"=>.8,"height"=>3.,"color"=>"gray","solid"=>true) for i in 0:23 if !(i in omitted)]
    append!(input["scene"]["obstacles"],stones)
    # Symmetric orange light sources inside/outside both shoulders of the entrance.
    # Policy sees its ordinary color/bearing, never an entrance identifier.
    torches=[D("x"=>home[1]+side*5sin(label=="wide" ? pi/6 : pi/12),
        "z"=>home[2]-offset,"radius"=>.3,"height"=>2.,"color"=>"orange","solid"=>true,"light_source"=>1.) for offset in (3.8,5.8) for side in (-1,1)]
    append!(input["scene"]["obstacles"],torches)
    # Pave whole grid cells inside the wall's inner edge, leaving solid objects clear.
    road_cells=[[x,z] for x in floor(Int,home[1]-4.2):ceil(Int,home[1]+4.2)-1
        for z in floor(Int,home[2]-4.2):ceil(Int,home[2]+4.2)-1
        if all(hypot(cx-home[1],cz-home[2])<=4.2 for cx in (x,x+1) for cz in (z,z+1)) &&
        all(hypot(o["x"]-clamp(o["x"],x,x+1),o["z"]-clamp(o["z"],z,z+1))>o["radius"] for o in input["scene"]["obstacles"])]
    input["scene"]["artificial_roads"]=[D("cells"=>road_cells,"lifetime_days"=>3650)]
    input["scene"]["name"]="riparian-rock-gate-"*label
    food_layout=food_roads_mode=="unchanged" ? nothing : food_road_layout!(input;enabled=food_roads_mode=="on")
    food_layout!==nothing && check_food_roads(input,food_layout)
    spec=JSON3.read(JSON3.write(input))
    walls=[RDLMigrationProbe.Circle(s["x"],s["z"],s["radius"]) for s in stones]
    allhigh=[RDLMigrationProbe.Circle(s.x,s.z,s.radius) for s in spec.scene.obstacles]
    # Body margin matches existing movement collision (.2). Test actual finite segments.
    @testset "$label geometry" begin
        @test !isempty(road_cells)
        @test all(hypot(x-home[1],z-home[2])<=4.2 for c in road_cells for x in (c[1],c[1]+1) for z in (c[2],c[2]+1))
        pavement=GroundWear(Int(spec.clock.day_us))
        place_roads!(pavement,spec.scene.artificial_roads)
        @test all(wear_factor(pavement,(c[1]+.5,c[2]+.5))==.5 for c in road_cells)
        @test wear_factor(pavement,(home[1],home[2]-5.5))==(food_roads_mode=="on" ? .5 : 1.)
        objects=prepare_landmark_objects(spec.scene.obstacles)
        for (position,yaw) in (((home[1],home[2]-3),180.),((home[1],home[2]-8),0.))
            seen=landmark_fan(objects,position,yaw,"gate-marker-check")
            @test any(f->f["color"]=="orange",seen["features"])
        end
        @test all(!segment_hit((home[1],home[2]-3),(home[1],home[2]-8),o,.2) for o in allhigh)
        @test all(!any(o->hypot(p[1]-o.x,p[2]-o.z)<=o.radius+.2,walls) for p in spec.scene.positions)
        @test all(!segment_hit((0.,3.),(0.,-1.),o,.2) for o in allhigh)
        @test all(!segment_hit((0.,-1.),(0.,3.),o,.2) for o in allhigh)
        @test any(o->segment_hit((3.,6.),(7.,6.),o,.2),walls)
        # Adjacent non-gate stones overlap; there are no unintended gaps elsewhere.
        for i in 1:length(walls)-1
            @test hypot(walls[i].x-walls[i+1].x,walls[i].z-walls[i+1].z)<1.6
        end
    end
    caseout=joinpath(out,label);mkpath(caseout)
    specpath=joinpath(caseout,"input.json");write(specpath,JSON3.write(input))
    if food_layout!==nothing
        write(joinpath(caseout,"food-roads.json"),JSON3.write(food_layout))
        render_food_roads(joinpath(caseout,"food-roads.svg"),input,food_layout)
    end
    if prepare_only
        println("PREPARED $label: $(length(road_cells)) artificial-road cells")
        continue
    end
    logref[]=open(joinpath(caseout,"crossings.jsonl"),"w")
    started[]=time()
    try
        native_main([joinpath(caseout,"run"),"--spec",specpath])
    finally
        close(logref[])
    end
    r=JSON3.read(read(joinpath(caseout,"run/result.json"),String))
    @testset "$label life invariants" begin
        @test length(r.daily)==(stop_day[]>0 ? stop_day[] : run_days)
        for (i,d) in enumerate(r.daily)
            @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(s.inventory+s.personal_stock for s in values(d.physical))
            i>1 && (@test r.day_starts[i]==r.daily[i-1].physical)
            for a in IDS
                previous=i==1 ? 0 : sum(values(r.daily[i-1].counts[a]))
                @test sum(values(d.counts[a]))-previous==17280
            end
        end
        @test all(isfinite(v) for s in values(r.final_agents) for v in values(s.body) if v isa Number)
        # All observed wall crossings must use the southern opening, including its arc shoulders.
        @test all(e.from[2]<home[2] && e.to[2]<home[2] for e in crossings)
    end
    write(joinpath(caseout,"termination.json"),JSON3.write((limit_days=run_days,completed_days=length(r.daily),reason=stop_day[]>0 ? "all_zero_reserve_and_full_day_rest" : "day_limit",stop_exhausted=stop_exhausted)))
    report=(case=label,rocks=length(stones),entrance_markers=torches,gap_width=label=="wide" ? 3.4 : 10sin(pi/12)-1.6,
        food=(initial=r.initial_food,ground=r.ground,shared=r.shared_stock,consumed=r.consumed),
        actors=Dict(a=>(outward=count(e->e.actor==a && e.direction=="out",crossings),
            inward=count(e->e.actor==a && e.direction=="in",crossings),max_radius=maxradius[a],
            final_position=r.final_agents[a].position,reserve=r.final_agents[a].body.reserve,
            counts=r.counts[a],return_purpose=r.final_agents[a].return_purpose,
            daily=[(day=i,reserve=d.physical[a].body.reserve,position=d.physical[a].position,return_purpose=d.physical[a].return_purpose) for (i,d) in enumerate(r.daily)]) for a in IDS))
    push!(reports,report)
    write(joinpath(caseout,"positions.json"),JSON3.write(positions))
    write(joinpath(caseout,"report.json"),JSON3.write(report))
    println("CASE COMPLETE $label");flush(stdout)
end
!prepare_only && write(joinpath(out,"comparison.json"),JSON3.write(reports))
write(joinpath(out,"provenance.json"),JSON3.write((commit=strip(read(`git -C $root rev-parse HEAD`,String)),julia=string(VERSION),source_day_sha256=bytes2hex(sha256(original)),scope="same LW; circular rock wall, paved interior and orange entrance post; read-only observer",prepared_only=prepare_only)))
println(prepare_only ? "COMPLETE rock gate preparation" : "COMPLETE rock gate comparison")
