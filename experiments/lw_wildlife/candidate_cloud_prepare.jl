using JSON3, SHA
baseline_repo=abspath(ARGS[1]);optimized_repo=abspath(ARGS[2]);root=abspath(ARGS[3])
ispath(root) && error("fresh output required")
input_path=joinpath(@__DIR__,"candidate_longrun_input.json")
input=JSON3.read(read(input_path,String))
@assert input.config.days==60 && input.config.seed==20261007
@assert !input.scene.wildlife.enabled
@assert collect(input.scene.experimental_actor_ids)==["npc_a","npc_b","npc_c","npc_d"]
for (variant,repository) in (("baseline",baseline_repo),("optimized",optimized_repo))
    destination=joinpath(root,variant,"source");mkpath(destination)
    cp(joinpath(repository,"src"),joinpath(destination,"src"))
    cp(input_path,joinpath(destination,"input.json"))
    cp(joinpath(optimized_repo,"Project.toml"),joinpath(destination,"Project.toml"))
    # Experimental cohort contract only, identical in both variants and local run.
    write(joinpath(destination,"src/data/lw_actor_ids.jl"),"const IDS="*repr(Tuple(input.scene.experimental_actor_ids))*"\n")
end
source=joinpath(root,"baseline/source")
files=sort([relpath(joinpath(d,f),source) for (d,_,fs) in walkdir(source) for f in fs])
optimized_source=joinpath(root,"optimized/source")
@assert files==sort([relpath(joinpath(d,f),optimized_source) for (d,_,fs) in walkdir(optimized_source) for f in fs])
differences=[f for f in files if read(joinpath(source,f))!=read(joinpath(root,"optimized/source",f))]
@assert replace.(differences,'\\'=>'/')==["src/lw/learning/mb_parent.jl"] differences
for (file,destination) in (("human_fresh_pair_runner.jl","runner.jl"),("candidate_longrun_pair.jl","controller.jl"),
    ("candidate_longrun_compare.jl","compare.jl"),("return_validation_compare.jl","state_compare.jl"))
    cp(joinpath(@__DIR__,file),joinpath(root,destination))
end
write(joinpath(root,"conditions.json"),JSON3.write((days=60,seed=20261007,actors=collect(input.scene.experimental_actor_ids),
    wildlife=false,threads=Threads.nthreads(),checkpoint_interval_days=2,order=["baseline","optimized"],
    source_differences=differences,input_sha256=bytes2hex(sha256(read(input_path))),
    baseline_commit="8c6e5da87e66e4c04c42163df191d4920483f6b8",optimized_commit=get(ENV,"GITHUB_SHA","local"),
    julia=string(VERSION),kernel=string(Sys.KERNEL),cpu=Sys.CPU_NAME)))
println("PREPARED ",root)
