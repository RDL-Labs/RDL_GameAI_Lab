# M00 local observation probe, not a full living-loop benchmark.
using Profile, InteractiveUtils, SHA
source_root=abspath(ARGS[1]);spec_path=abspath(ARGS[2]);out=abspath(ARGS[3]);mkpath(out)
include(joinpath(source_root,"experiments/julia_migration/lw_integrated/native.jl"))
input=JSON3.read(read(spec_path,String));objects=input.scene.obstacles
position=Tuple(Float64.(input.scene.positions[1]))
probe(objects,position)=skyline_fan(objects,position,0.,"m00:fixed";subrays=true)
function batch(objects,position,n)
    checksum=0
    for _ in 1:n
        checksum+=length(probe(objects,position)["features"])
    end
    checksum
end
first=@timed probe(objects,position)
batch(objects,position,2)
samples=Any[]
for _ in 1:5
    GC.gc()
    m=@timed batch(objects,position,32)
    push!(samples,(calls=32,seconds=m.time,allocated_bytes=m.bytes,gc_seconds=m.gctime,checksum=m.value))
end
Profile.clear();@profile batch(objects,position,256)
open(joinpath(out,"cpu.txt"),"w") do io
    Profile.print(io;format=:flat,sortedby=:count)
end
Profile.Allocs.clear()
Profile.Allocs.@profile sample_rate=0.001 batch(objects,position,32)
a=Profile.Allocs.fetch()
open(joinpath(out,"allocations.txt"),"w") do io
    for x in a.allocs
        println(io,"size=",x.size," type=",x.type)
        for frame in x.stacktrace
            occursin("julia_migration",String(frame.file)) && println(io,frame)
        end
    end
end
open(joinpath(out,"warntype.txt"),"w") do io
    code_warntype(io,probe,Tuple{typeof(objects),typeof(position)})
end
r=(scope="M00 Skyline initial observation only; concurrent local30 run; timings exploratory, not acceptance",julia=string(VERSION),threads=Threads.nthreads(),cpu=Sys.CPU_NAME,os=string(Sys.KERNEL),source_root=source_root,spec_sha256=bytes2hex(sha256(read(spec_path))),skyline_sha256=bytes2hex(sha256(read(joinpath(source_root,"experiments/julia_migration/lw_day/skyline.jl")))),project_sha256=bytes2hex(sha256(read(Base.active_project()))),manifest_sha256=bytes2hex(sha256(read(joinpath(dirname(Base.active_project()),"Manifest.toml")))),objects=length(objects),first=(seconds=first.time,allocated_bytes=first.bytes,gc_seconds=first.gctime),samples=samples,sampled_allocations=length(a.allocs),process_peak_rss_bytes=Sys.maxrss())
write(joinpath(out,"measurements.json"),JSON3.write(r));println(JSON3.write(r))
