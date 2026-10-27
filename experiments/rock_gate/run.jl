using JSON3, Test, SHA
const root=normpath(joinpath(@__DIR__,"../.."))
const out=abspath(ARGS[1]);ispath(out) && error("fresh output required");mkpath(out)
const stop_exhausted="--stop-exhausted" in ARGS
const prepare_only="--prepare-only" in ARGS
const gate_diagnostics="--gate-diagnostics" in ARGS
if gate_diagnostics
    include(joinpath(@__DIR__,"gate_diagnostics.jl"))
end
const mixed_transfer="--mixed-transfer" in ARGS
const ordinary_only="--ordinary-only" in ARGS
const staged_food="--staged-food" in ARGS
const distinctive_world="--distinctive-landmarks" in ARGS
@assert !(staged_food && "--nearby-food" in ARGS)
@assert !(staged_food || distinctive_world) || ordinary_only
const nearby_food="--nearby-food" in ARGS
@assert !nearby_food || ordinary_only "nearby food requires the ordinary open camp"
@assert !(ordinary_only && "--narrow-only" in ARGS)
const provisions_arg=findfirst(==("--camp-provisions"),ARGS)
const camp_provisions=provisions_arg===nothing ? 0 : parse(Int,ARGS[provisions_arg+1])
@assert 0<=camp_provisions<=100
const days_arg=findfirst(==("--days"),ARGS)
const run_days=days_arg===nothing ? 3 : parse(Int,ARGS[days_arg+1])
@assert 1<=run_days<=30
const snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(root,"src"),joinpath(snapshot,"src"))
cp(joinpath(root,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
if mixed_transfer
    @assert ordinary_only && "--far-transfer-map" in ARGS && "--transfer-from" in ARGS
    write(joinpath(snapshot,"src/data/lw_actor_ids.jl"),"# Isolated six-actor experiment, interleaved cohorts.\nconst IDS=(\"npc_a\",\"npc_d\",\"npc_b\",\"npc_e\",\"npc_c\",\"npc_f\")\n")
end
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
if "--mb-diagnostics" in ARGS
    include(joinpath(@__DIR__,"mb_diagnostics.jl"))
    patched=instrument_mb_day(patched)
    instrument_mb_files(snapshot)
end
gate_diagnostics && (patched=instrument_gate_day(patched))
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
    if gate_diagnostics && sec>=121681
        write(joinpath(out,"diagnostic-stop.json"),JSON3.write((reason="requested_gate_snapshot",sec=sec,positions=w.positions)))
        flush(gate_diag_io)
        throw(GateDiagnosticStop())
    end
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
include(joinpath(@__DIR__,"nearby_food.jl"))
include(joinpath(@__DIR__,"staged_world.jl"))
include(joinpath(@__DIR__,"transfer_world.jl"))
include(joinpath(@__DIR__,"mixed_transfer.jl"))
const base=JSON3.read(read(joinpath(root,"experiments/julia_migration/lw_integrated/search_review_spec.json"),String),Dict{String,Any})
const world_seed_arg=findfirst(==("--world-seed"),ARGS)
const world_seed=world_seed_arg===nothing ? nothing : parse(Int,ARGS[world_seed_arg+1])
if world_seed!==nothing
    @assert ordinary_only && staged_food && world_seed>=0
    base["scene"]=JSON3.read(JSON3.write(native_landscape_scene(world_seed)),Dict{String,Any})
    base["scene"]["world_generation_seed"]=world_seed
end
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
body_arg=findfirst(==("--body-purpose"),ARGS)
base["config"]["body_purpose"]=body_arg===nothing ? "off" : ARGS[body_arg+1]
@assert base["config"]["body_purpose"] in ("off","on")
mb_arg=findfirst(==("--mb-simulation"),ARGS)
base["config"]["mb_simulation"]=mb_arg===nothing ? "off" : ARGS[mb_arg+1]
@assert base["config"]["mb_simulation"] in ("off","on")
chunk_arg=findfirst(==("--mb-chunks"),ARGS)
base["config"]["mb_chunks"]=chunk_arg===nothing ? "off" : ARGS[chunk_arg+1]
@assert base["config"]["mb_chunks"] in ("off","on")
sleep_arg=findfirst(==("--mb-sleep"),ARGS)
base["config"]["mb_sleep"]=sleep_arg===nothing ? "off" : ARGS[sleep_arg+1]
@assert base["config"]["mb_sleep"] in ("off","on")
observation_arg=findfirst(==("--home-observation"),ARGS)
base["config"]["home_observation"]=observation_arg===nothing ? "off" : ARGS[observation_arg+1]
@assert base["config"]["home_observation"] in ("off","on")
# Fixed per-actor personality gains, loaded into the recorded experiment input.
sensitivity_arg=findfirst(==("--mb-sensitivities"),ARGS)
if sensitivity_arg!==nothing
    profiles=JSON3.read(read(ARGS[sensitivity_arg+1],String),Dict{String,Any})
    @assert all(k in IDS for k in keys(profiles))
    for profile in values(profiles);mb_sensitivity(profile);end
    base["config"]["mb_sensitivities"]=profiles
end
similarity_arg=findfirst(==("--similarity-learning"),ARGS)
if similarity_arg!==nothing
    @assert ARGS[similarity_arg+1] in ("on","off")
    base["config"]["mb_similarity_learning"]=ARGS[similarity_arg+1]
end
rest_reward_arg=findfirst(==("--home-rest-reward"),ARGS)
if rest_reward_arg!==nothing
    @assert ARGS[rest_reward_arg+1] in ("on","off")
    base["config"]["home_rest_reward"]=ARGS[rest_reward_arg+1]
end
embedded_rest_arg=findfirst(==("--embedded-rest"),ARGS)
if embedded_rest_arg!==nothing
    @assert ARGS[embedded_rest_arg+1] in ("on","off")
    base["config"]["embedded_rest"]=ARGS[embedded_rest_arg+1]
end
night_fear_arg=findfirst(==("--night-fear"),ARGS)
if night_fear_arg!==nothing
    @assert ARGS[night_fear_arg+1] in ("on","off")
    base["config"]["night_fear"]=ARGS[night_fear_arg+1]
end
daily_delivery_arg=findfirst(==("--daily-delivery"),ARGS)
if daily_delivery_arg!==nothing
    @assert ARGS[daily_delivery_arg+1] in ("on","off")
    base["config"]["daily_delivery"]=ARGS[daily_delivery_arg+1]
end
safe_arg=findfirst(==("--camp-safe-zone"),ARGS)
if safe_arg!==nothing
    @assert ARGS[safe_arg+1] in ("on","off")
    base["config"]["camp_safe_zone"]=ARGS[safe_arg+1]
end
hazards_arg=findfirst(==("--hazards"),ARGS)
if hazards_arg!==nothing
    @assert ARGS[hazards_arg+1] in ("off","mixed","territorial")
    base["config"]["hazards"]=ARGS[hazards_arg+1]
end
const reports=Any[]
for (label,omitted) in (ordinary_only ? (("ordinary",Set([0])),) : (("wide",Set([0,1,23])),("narrow",Set([0]))))
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
    if "--world-features" in ARGS
        idx=findfirst(==("--world-features"),ARGS)
        @assert ARGS[idx+1] in ("off","on")
        if ARGS[idx+1]=="on"
            enriched=WorldFeatures.enrich_scene(JSON3.read(JSON3.write(input["scene"]));seed=world_seed===nothing ? input["config"]["seed"] : world_seed)
            input["scene"]=JSON3.read(JSON3.write(enriched),Dict{String,Any})
            # Keep the benchmark wall and entrance geometry; only background objects vary in size.
            for o in input["scene"]["obstacles"], stone in stones
                if o["x"]==stone["x"] && o["z"]==stone["z"]
                    o["radius"]=stone["radius"];o["height"]=stone["height"]
                end
            end
            input["config"]["world_features"]="color-size-patches-v1"
        end
    end
    if ordinary_only
        # Remove only the benchmark enclosure AFTER enrichment, preserving its RNG
        # sequence and therefore the same background features and food stocks.
        filter!(o->!any(o["x"]==s["x"] && o["z"]==s["z"] for s in stones),input["scene"]["obstacles"])
        empty!(stones)
    end
    staged_food && staged_food_layout!(input)
    distinctive_world && distinctive_landmarks!(input)
    staged_food && check_staged_world(input)
    # Finite piles beside initial observation positions; normal pickup/eat physics.
    if camp_provisions>0
        for p in input["scene"]["positions"]
            push!(input["scene"]["food"],D("x"=>p[1],"z"=>p[2],"stock"=>camp_provisions,"renewable"=>false))
        end
    end
    nearby_food && nearby_food_layout!(input)
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
        if ordinary_only
            @test isempty(walls)
            @test all(!segment_hit((3.,6.),(7.,6.),o,.2) for o in allhigh)
            @test all(!segment_hit((-3.,6.),(-7.,6.),o,.2) for o in allhigh)
        else
            @test any(o->segment_hit((3.,6.),(7.,6.),o,.2),walls)
        end
        # Adjacent non-gate stones overlap; there are no unintended gaps elsewhere.
        for i in 1:length(walls)-1
            @test hypot(walls[i].x-walls[i+1].x,walls[i].z-walls[i+1].z)<1.6
        end
    end
    if "--far-transfer-map" in ARGS
        @assert ordinary_only && staged_food && camp_provisions==0
        far_transfer_world!(input)
    end
    if "--enclosed-camp" in ARGS
        @assert ordinary_only && "--far-transfer-map" in ARGS
        s=input["scene"];hx,hz=Float64.(s["home"])
        nextid=maximum([get(o,"world_id",0) for o in vcat(s["obstacles"],get(s,"low_obstacles",Any[]))];init=0)
        enclosure=[D("x"=>hx-5sin(2pi*i/24),"z"=>hz+5cos(2pi*i/24),
            "radius"=>.8,"height"=>3.,"color"=>"gray","solid"=>true,
            "kind"=>2,"world_id"=>nextid+i,"food_index"=>0) for i in 1:23 if !("--wide-enclosure" in ARGS && i in (1,23))]
        if "--medium-enclosure" in ARGS
            @assert "--wide-enclosure" in ARGS
            width_arg=findfirst(==("--entrance-width"),ARGS)
            entrance_width=width_arg===nothing ? 2.0 : parse(Float64,ARGS[width_arg+1])
            @assert isfinite(entrance_width) && 0.5<=entrance_width<=3.4
            # Keep the wall connected: enlarge the two end rocks in place.
            first(enclosure)["radius"]=(5.0-entrance_width)/2
            last(enclosure)["radius"]=(5.0-entrance_width)/2
        end
        append!(s["obstacles"],enclosure)
        circles=[RDLMigrationProbe.Circle(o["x"],o["z"],o["radius"]) for o in s["obstacles"]]
        @testset "enclosed camp final geometry" begin
            @test length(enclosure)==("--wide-enclosure" in ARGS ? 21 : 23)
            "--medium-enclosure" in ARGS && (@test last(enclosure)["x"]-first(enclosure)["x"]-first(enclosure)["radius"]-last(enclosure)["radius"] ≈ entrance_width)
            @test all(!segment_hit((hx,hz),(hx,hz+10),o,.2) for o in circles)
            @test any(segment_hit((hx,hz),(hx+8,hz),o,.2) for o in circles)
            @test any(segment_hit((hx,hz),(hx-8,hz),o,.2) for o in circles)
            for p in s["positions"]
                @test all(hypot(p[1]-o.x,p[2]-o.z)>o.radius+.2 for o in circles)
            end
            for i in 1:length(enclosure)-1
                @test hypot(enclosure[i]["x"]-enclosure[i+1]["x"],enclosure[i]["z"]-enclosure[i+1]["z"])<1.6
            end
            ids=[o["world_id"] for o in s["obstacles"]]
            @test length(ids)==length(unique(ids))
        end
    end
    if "--exit-visible-food" in ARGS
        @assert "--enclosed-camp" in ARGS
        s=input["scene"];hx,hz=Float64.(s["home"])
        @assert length(s["food"])==3
        distant_food=deepcopy(s["food"])
        for (f,dx) in zip(s["food"],(-2.,0.,2.))
            f["x"]=hx+dx;f["z"]=hz+9.5
            if "--finite-near-three-day" in ARGS
                f["stock"]=4;f["renewable"]=false
            end
        end
        scene=JSON3.read(JSON3.write(s));world=moving_world(scene)
        append!(world.obstacles,[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in scene.low_obstacles])
        @testset "food visible immediately at north exit" begin
            for dz in (4.8,5.,5.5),heading in (-10.,0.,10.)
                world.positions[first(IDS)]=(hx,hz+dz)
                view=perceive_movement(world,first(IDS),Dict(a=>heading for a in IDS),scene.food,[f.stock for f in scene.food])
                @test length(view.visible)==3
            end
            for f in scene.food
                route=[(hx,hz),(hx,hz+7.5),(Float64(f.x),Float64(f.z))]
                for i in 1:2
                    p,q=route[i],route[i+1]
                    @test all(!segment_hit(p,q,o,.2) for o in world.obstacles)
                    @test all(landscape_material(scene.landscape,(p[1]+t*(q[1]-p[1]),p[2]+t*(q[2]-p[2])))!="water" for t in 0:.025:1)
                end
            end
        end
        if "--finite-near-three-day" in ARGS
            append!(s["food"],distant_food)
            @testset "finite near supplies and renewable distant food" begin
                foods=JSON3.read(JSON3.write(s["food"]))
                @test sum(f.stock for f in foods[1:3])==12
                @test all(!f.renewable for f in foods[1:3])
                @test all(f.renewable for f in foods[4:6])
                stocks=zeros(Int,6);replenish_food!(stocks,foods;capacity=12)
                @test stocks==[0,0,0,12,12,12]
            end
        end
    end
    if "--central-bonfire" in ARGS
        @assert "--enclosed-camp" in ARGS
        s=input["scene"];hx,hz=Float64.(s["home"])
        s["visual_landmarks"]=[D("x"=>hx,"z"=>hz,"radius"=>1.2,"height"=>6.,
            "color"=>"orange","solid"=>false,"light_source"=>16.)]
        scene=JSON3.read(JSON3.write(s))
        visual=prepare_landmark_objects(vcat(collect(scene.obstacles),collect(scene.visual_landmarks)))
        @testset "central bonfire visual connection" begin
            @test length(moving_world(scene).obstacles)==length(scene.obstacles)
            for dz in (4.8,5.5,6.7),night in (false,true)
                p=(hx,hz+dz)
                before=light_fan(prepare_landmark_objects(scene.obstacles),p,180.;night=night)
                after=light_fan(visual,p,180.;night=night)
                @test length(after)==length(before)+1
                @test after[end]["brightness"]=="bright"
            end
            @test any(f->f["color"]=="orange",landmark_fan(visual,(hx,hz+5.5),180.,"test";all_colors=true)["features"])
        end
    end
    transfer_arg=findfirst(==("--transfer-from"),ARGS)
    if transfer_arg!==nothing
        learned=JSON3.read(read(ARGS[transfer_arg+1],String),Dict{String,Any})
        input["scene"]["learned_mb_transfer"]=D("maps"=>learned["mb_map"],"ended_us"=>learned["ended_us"],
            "methods"=>D(a=>last(learned["daily"])["physical"][a]["loops"] for a in keys(learned["mb_map"])),
            "source_sha256"=>bytes2hex(sha256(read(ARGS[transfer_arg+1]))))
    end
    mixed_transfer && mixed_transfer_population!(input)
    # Remove authored pavement only after layout checks; retain natural wear.
    if "--no-artificial-roads" in ARGS
        input["scene"]["artificial_roads"]=Any[]
    end
    spec=JSON3.read(JSON3.write(input))
    caseout=joinpath(out,label);mkpath(caseout)
    specpath=joinpath(caseout,"input.json");write(specpath,JSON3.write(input))
    if food_layout!==nothing && !("--far-transfer-map" in ARGS)
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
        native_args=[joinpath(caseout,"run"),"--spec",specpath]
        "--checkpoints" in ARGS && append!(native_args,["--checkpoint-dir",joinpath(caseout,"checkpoints")])
        resume_arg=findfirst(==("--resume-from"),ARGS)
        if resume_arg!==nothing
            append!(native_args,["--resume-from",abspath(ARGS[resume_arg+1])])
            write(joinpath(caseout,"observer-scope.json"),JSON3.write((scope="positions and crossings cover resumed interval only; result daily history covers full run",resume_from=abspath(ARGS[resume_arg+1]))))
        end
        native_main(native_args)
    catch err
        if gate_diagnostics && err isa GateDiagnosticStop
            write(joinpath(caseout,"positions.json"),JSON3.write(positions))
            println("COMPLETE requested gate diagnostic stop at 121681 seconds")
            exit(0)
        end
        rethrow()
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
        !ordinary_only && (@test all(e.from[2]<home[2] && e.to[2]<home[2] for e in crossings))
    end
    write(joinpath(caseout,"termination.json"),JSON3.write((limit_days=run_days,completed_days=length(r.daily),reason=stop_day[]>0 ? "all_zero_reserve_and_full_day_rest" : "day_limit",stop_exhausted=stop_exhausted)))
    report=(case=label,rocks=length(stones),entrance_markers=torches,gap_width=ordinary_only ? nothing : label=="wide" ? 3.4 : 10sin(pi/12)-1.6,
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
write(joinpath(out,"provenance.json"),JSON3.write((commit=strip(read(`git -C $root rev-parse HEAD`,String)),julia=string(VERSION),source_day_sha256=bytes2hex(sha256(original)),scope=ordinary_only ? "same LW; open camp without benchmark rock enclosure; same roads, lights and food; read-only radius-5 observer" : "same LW; circular rock wall, paved interior and orange entrance post; read-only observer",prepared_only=prepare_only)))
println(prepare_only ? "COMPLETE rock gate preparation" : "COMPLETE rock gate comparison")
