# Native entry: no Python process, Python imports, or Python-generated input required.
include(joinpath(@__DIR__,"run.jl"))
include(joinpath(@__DIR__,"world.jl"))
using SHA

function native_options(args)
    isempty(args) && error("usage: native.jl OUTPUT [--days 1..30 --seed N --food finite|renewable --learning off|full --hazards off|crossing|territorial|mixed --orientation off|on --relation-field off|on --safety-methods legacy|continuous --food-body off|on --ground-continuity off|on --ground-perception off|on --ground-wear off|on --ground flat|shadow|patches --running off|on --climbing off|on --sleep-maintenance off|on --sleep-retention recent|strata --general-sleep off|review|apply --social-response legacy|experience --dropping off|on --low-obstacles off|on --spec FILE]")
    out=args[1];opts=Dict("days"=>"3","seed"=>"20261004","food"=>"finite","learning"=>"full","hazards"=>"off","ground"=>"flat","ground-wear"=>"off","ground-perception"=>"off","ground-continuity"=>"off","layout"=>"sparse","skyline"=>"off","reposition"=>"off","selection-trails"=>"off","bundle-credit"=>"off","experience-bundles"=>"off","exploration-horizon"=>"off","movement-inertia"=>"off","body-field"=>"off","relation-field"=>"off","orientation"=>"off","food-body"=>"off","safety-methods"=>"legacy","running"=>"off","climbing"=>"off","sleep-maintenance"=>"off","sleep-retention"=>"recent","general-sleep"=>"off","social-response"=>"legacy","dropping"=>"off","low-obstacles"=>"off","spec"=>"")
    iseven(length(args)-1) || error("option requires a value")
    for i in 2:2:length(args)
        startswith(args[i],"--") || error("invalid option")
        key=args[i][3:end];haskey(opts,key) || error("unknown option: $key")
        opts[key]=args[i+1]
    end
    out,opts
end

function native_main(args)
    out,opts=native_options(args)
    generated=isempty(opts["spec"])
    if generated
        cfg=(days=parse(Int,opts["days"]),seed=parse(Int,opts["seed"]),food=opts["food"],
             learning=opts["learning"],hazards=opts["hazards"],ground=opts["ground"],ground_wear=opts["ground-wear"],ground_perception=opts["ground-perception"],ground_continuity=opts["ground-continuity"],layout=opts["layout"],skyline=opts["skyline"],reposition=opts["reposition"],selection_trails=opts["selection-trails"],bundle_credit=opts["bundle-credit"],experience_bundles=opts["experience-bundles"],exploration_horizon=opts["exploration-horizon"],movement_inertia=opts["movement-inertia"],body_field=opts["body-field"],relation_field=opts["relation-field"],orientation=opts["orientation"],food_body=opts["food-body"],safety_methods=opts["safety-methods"],running=opts["running"],climbing=opts["climbing"],sleep_maintenance=opts["sleep-maintenance"],sleep_retention=opts["sleep-retention"],general_sleep=opts["general-sleep"],social_response=opts["social-response"],dropping=opts["dropping"],low_obstacles=opts["low-obstacles"])
        cfg.layout in ("sparse","riparian") || error("layout mode")
        input=(scene=cfg.layout=="riparian" ? native_landscape_scene(cfg.seed) : native_scene(cfg.seed),clock=native_clock(),config=cfg)
        bytes=Vector{UInt8}(codeunits(JSON3.write(input)))
    else
        # Frozen input owns configuration; do not silently override it with CLI defaults.
        length(args)==3 || error("--spec cannot be combined with configuration options")
        bytes=read(opts["spec"])
    end
    input=JSON3.read(bytes);cfg=input.config
    1<=cfg.days<=30 && cfg.days isa Integer || error("days must be 1..30")
    cfg.food in ("finite","renewable") || error("food mode")
    cfg.learning in ("off","full") || error("learning mode")
    cfg.hazards in ("off","crossing","territorial","mixed") || error("hazard mode")
    Dict(pairs(input.clock))==Dict(pairs(JSON3.read(JSON3.write(native_clock())))) ||
        error("native entry requires the calibrated human_scale_v1 clock")
    get(cfg,:ground,"flat") in ("flat","patches","shadow") || error("ground mode")
    get(cfg,:running,"off") in ("off","on") || error("running mode")
    get(cfg,:climbing,"off") in ("off","on") || error("climbing mode")
    get(cfg,:low_obstacles,"off") in ("off","on") || error("low obstacle mode")
    get(cfg,:dropping,"off") in ("off","on") || error("dropping mode")
    get(cfg,:social_response,"legacy") in ("legacy","experience") || error("social response mode")
    get(cfg,:general_sleep,"off") in ("off","review","apply") || error("general sleep mode")
    get(cfg,:sleep_retention,"recent") in ("recent","strata") || error("sleep retention mode")
    get(cfg,:sleep_maintenance,"off") in ("off","on") || error("sleep maintenance mode")
    get(cfg,:ground_wear,"off") in ("off","on") || error("ground wear mode")
    get(cfg,:ground_perception,"off") in ("off","on") || error("ground perception mode")
    get(cfg,:ground_continuity,"off") in ("off","on") || error("ground continuity mode")
    get(cfg,:skyline,"off") in ("off","rays","subrays") || error("skyline mode")
    get(cfg,:reposition,"off") in ("off","on") || error("reposition mode")
    get(cfg,:selection_trails,"off") in ("off","on") || error("selection trails mode")
    get(cfg,:bundle_credit,"off") in ("off","on") || error("bundle credit mode")
    get(cfg,:experience_bundles,"off") in ("off","on") || error("experience bundles mode")
    get(cfg,:exploration_horizon,"off") in ("off","on") || error("exploration horizon mode")
    get(cfg,:movement_inertia,"off") in ("off","on") || error("movement inertia mode")
    get(cfg,:body_field,"off") in ("off","on") || error("body field mode")
    get(cfg,:relation_field,"off") in ("off","on") || error("relation field mode")
    get(cfg,:orientation,"off") in ("off","on") || error("orientation mode")
    get(cfg,:food_body,"off") in ("off","on") || error("food body mode")
    get(cfg,:safety_methods,"legacy") in ("legacy","continuous") || error("safety method mode")
    mkpath(out);write(joinpath(out,"spec.json"),bytes)
    root=normpath(joinpath(@__DIR__,".."));sources=Dict{String,String}()
    for (dir,_,files) in walkdir(root), f in files
        endswith(f,".jl") || continue
        p=joinpath(dir,f);sources[relpath(p,root)]=bytes2hex(sha256(read(p)))
    end
    manifest=Dict("entry"=>"native-julia-lw-v1","julia_version"=>string(VERSION),
        "generator"=>generated ? (get(cfg,:layout,"sparse")=="riparian" ? "julia-lw-riparian-mt-v1" : WORLD_GENERATOR) : "frozen-spec",
        "config"=>cfg,"spec_sha256"=>bytes2hex(sha256(bytes)),"sources"=>sources,
        "scope"=>"finite LW subset; not full Python LW parity",
        "python_required"=>false)
    open(joinpath(out,"manifest.json"),"w") do io;JSON3.write(io,manifest);end
    measured=@timed run_integrated(input)
    r,summary=measured.value;elapsed=measured.time
    summary["measurement"]=D("call_seconds"=>elapsed,"allocated_bytes"=>measured.bytes,"gc_seconds"=>measured.gctime,"process_peak_rss_bytes"=>Sys.maxrss(),"compilation_included"=>true)
    summary["elapsed_seconds_including_compilation"]=elapsed
    for (name,data) in (("result.json",r),("summary.json",summary))
        open(joinpath(out,name),"w") do io;JSON3.write(io,data);end
    end
    println(JSON3.write(D("output"=>out,"config"=>cfg,"food"=>summary["food"],"elapsed_seconds_including_compilation"=>elapsed)))
end

if abspath(PROGRAM_FILE)==@__FILE__
    native_main(ARGS)
end
