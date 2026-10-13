# Native entry: no Python process, Python imports, or Python-generated input required.
include(joinpath(@__DIR__,"run.jl"))
include(joinpath(@__DIR__,"world.jl"))
using SHA

function native_options(args)
    isempty(args) && error("usage: native.jl OUTPUT [--days 1..4 --seed N --food finite|renewable --learning off|full --hazards off|crossing --ground flat|shadow|patches --running off|on --climbing off|on --sleep-retention recent|strata --general-sleep off|review|apply --social-response legacy|experience --dropping off|on --low-obstacles off|on --spec FILE]")
    out=args[1];opts=Dict("days"=>"3","seed"=>"20261004","food"=>"finite","learning"=>"full","hazards"=>"off","ground"=>"flat","running"=>"off","climbing"=>"off","sleep-retention"=>"recent","general-sleep"=>"off","social-response"=>"legacy","dropping"=>"off","low-obstacles"=>"off","spec"=>"")
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
             learning=opts["learning"],hazards=opts["hazards"],ground=opts["ground"],running=opts["running"],climbing=opts["climbing"],sleep_retention=opts["sleep-retention"],general_sleep=opts["general-sleep"],social_response=opts["social-response"],dropping=opts["dropping"],low_obstacles=opts["low-obstacles"])
        input=(scene=native_scene(cfg.seed),clock=native_clock(),config=cfg)
        bytes=Vector{UInt8}(codeunits(JSON3.write(input)))
    else
        # Frozen input owns configuration; do not silently override it with CLI defaults.
        length(args)==3 || error("--spec cannot be combined with configuration options")
        bytes=read(opts["spec"])
    end
    input=JSON3.read(bytes);cfg=input.config
    1<=cfg.days<=4 && cfg.days isa Integer || error("days must be 1..4")
    cfg.food in ("finite","renewable") || error("food mode")
    cfg.learning in ("off","full") || error("learning mode")
    cfg.hazards in ("off","crossing") || error("hazard mode")
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
    mkpath(out);write(joinpath(out,"spec.json"),bytes)
    root=normpath(joinpath(@__DIR__,".."));sources=Dict{String,String}()
    for (dir,_,files) in walkdir(root), f in files
        endswith(f,".jl") || continue
        p=joinpath(dir,f);sources[relpath(p,root)]=bytes2hex(sha256(read(p)))
    end
    manifest=Dict("entry"=>"native-julia-lw-v1","julia_version"=>string(VERSION),
        "generator"=>generated ? WORLD_GENERATOR : "frozen-spec",
        "config"=>cfg,"spec_sha256"=>bytes2hex(sha256(bytes)),"sources"=>sources,
        "scope"=>"finite LW subset; not full Python LW parity",
        "python_required"=>false)
    open(joinpath(out,"manifest.json"),"w") do io;JSON3.write(io,manifest);end
    elapsed=@elapsed r,summary=run_integrated(input)
    summary["elapsed_seconds_including_compilation"]=elapsed
    for (name,data) in (("result.json",r),("summary.json",summary))
        open(joinpath(out,name),"w") do io;JSON3.write(io,data);end
    end
    println(JSON3.write(D("output"=>out,"config"=>cfg,"food"=>summary["food"],"elapsed_seconds_including_compilation"=>elapsed)))
end

if abspath(PROGRAM_FILE)==@__FILE__
    native_main(ARGS)
end
