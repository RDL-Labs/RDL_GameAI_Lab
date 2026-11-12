using JSON3
const ROOT=normpath(joinpath(@__DIR__,"../.."))
suites=JSON3.read(read(joinpath(@__DIR__,"suites.json"),String),Dict{String,Any})
paths=String[]
for entries in values(suites), entry in entries
    path=entry["path"]
    isfile(joinpath(ROOT,path)) || error("Missing CI test: $path")
    startswith(path,"outputs/") && error("Local outputs cannot be CI inputs")
    path in paths && error("Duplicate CI entry: $path")
    push!(paths,path)
end
core_paths=JSON3.read(read(joinpath(@__DIR__,"core.json"),String),Vector{String})
length(unique(core_paths))==length(core_paths) || error("Duplicate core entry")
all(path->path in paths,core_paths) || error("Core entry missing from suite catalog")
entries_by_path=Dict(entry["path"]=>entry for entries in values(suites) for entry in entries)
suites["core"]=[entries_by_path[path] for path in core_paths]
length(ARGS)==1 || error("Pass a suite name, --list or --validate")
if ARGS[1]=="--validate"
    println("Validated $(length(paths)) catalog entries; $(length(core_paths)) core entries");exit()
end
if ARGS[1]=="--list"
    println(join(sort!(collect(keys(suites))),"\n"));exit()
end
suite=ARGS[1];haskey(suites,suite) || error("Unknown suite: $suite")
out=joinpath(ROOT,"outputs/ci",suite);mkpath(out)
results=Any[]
for (index,entry) in enumerate(suites[suite])
    path=entry["path"];arguments=String.(entry["args"])
    logfile=joinpath(out,"$(index)-$(basename(path)).log")
    println("::group::$path");flush(stdout)
    started=time()
    command=`$(Base.julia_cmd()) --startup-file=no --project=$ROOT $(joinpath(ROOT,path)) $arguments`
    process=open(logfile,"w") do io
        run(pipeline(ignorestatus(Cmd(command;dir=ROOT)),stdout=io,stderr=io))
    end
    print(read(logfile,String))
    push!(results,(path=path,exitcode=process.exitcode,seconds=time()-started))
    write(joinpath(out,"results.json"),JSON3.write(results))
    println("::endgroup::");flush(stdout)
end
failed=filter(r->r.exitcode!=0,results)
println("Suite $suite: $(length(results)-length(failed))/$(length(results)) scripts passed")
exit(isempty(failed) ? 0 : 1)
