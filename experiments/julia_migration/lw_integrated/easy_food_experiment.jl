include(joinpath(@__DIR__,"native.jl"))
using Test
length(ARGS) in (2,4) || error("SPEC OUTPUT [DAYS REPETITION_MODE]")
spec,out=ARGS[1:2]
days=length(ARGS)==4 ? parse(Int,ARGS[3]) : 3
repetition=length(ARGS)==4 ? ARGS[4] : "off"
1<=days<=10 || error("finite_days")
repetition in ("off","on") || error("repetition_mode")
isdir(out) && error("fresh output required")
mkpath(out)
input=JSON3.read(read(spec,String),Dict{String,Any})
cfg=input["config"];cfg["days"]=days;cfg["repetition_pressure"]=repetition;cfg["hazards"]="off";cfg["ground"]="flat"
cfg["skyline"]="off";cfg["low_obstacles"]="off";cfg["food"]="finite"
scene=input["scene"];pop!(scene,"landscape",nothing)
scene["name"]="easy-hidden-near-food"
scene["home"]=[0.,4.];scene["positions"]=[[-2.,4.],[0.,4.],[2.,4.]]
scene["reserve"]=[90.,90.,90.];scene["initial_inventory"]=[2,2,2]
scene["food"]=[D("x"=>0.,"z"=>17.,"stock"=>1_000_000)]
scene["obstacles"]=[D("x"=>-4.,"z"=>4.,"radius"=>.3,"height"=>12.,"color"=>"ochre","solid"=>true)]
scene["low_obstacles"]=Any[];scene["ground_patches"]=Any[];scene["hazards"]=Any[]
@test all(hypot(p[1],17-p[2])>12 for p in scene["positions"])
@test hypot(scene["home"][1],17-scene["home"][2])>12
@test 1_000_000>3*days*17_280 # even pickup on every operation cannot exhaust supply
for mode in ("off","on")
    cfg["parent_breadth"]=mode
    write(joinpath(out,"$mode-spec.json"),JSON3.write(input))
    timed=@timed run_integrated(JSON3.read(JSON3.write(input)))
    result,summary=timed.value
    f=summary["food"];held=sum(a["stock"]+a["inventory"] for a in values(summary["agents"]))
    @test f["initial"]+f["added"]==f["ground"]+f["shared"]+f["consumed"]+held
    @test f["ground"]>0
    @test sum(a["operations"] for a in values(summary["agents"]))==3*days*17_280
    summary["measurement"]=D("seconds"=>timed.time,"bytes"=>timed.bytes)
    write(joinpath(out,"$mode-summary.json"),JSON3.write(summary))
    write(joinpath(out,"$mode-result.json"),JSON3.write(result))
    println(mode," complete ",timed.time);flush(stdout)
end
