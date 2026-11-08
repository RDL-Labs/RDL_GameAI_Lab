# Sequential end-to-end comparison; same frozen source and starting checkpoint.
using JSON3,SHA
function main()
 root=abspath(ARGS[1]);checkpoint=abspath(ARGS[2]);input=abspath(ARGS[3]);days=parse(Int,ARGS[4])
 ispath(root) && error("fresh comparison output required")
 repo=normpath(joinpath(@__DIR__,"../.."));source=joinpath(root,"source")
 mkpath(joinpath(source,"experiments"));cp(joinpath(repo,"src"),joinpath(source,"src"))
 cp(@__DIR__,joinpath(source,"experiments/lw_wildlife"));cp(joinpath(repo,"Project.toml"),joinpath(source,"Project.toml"))
 cp(input,joinpath(root,"input.json"));input=joinpath(root,"input.json")
 write(joinpath(root,"conditions.json"),JSON3.write((days,checkpoint,input,order=["batch_cpu","gpu"],sequential=true,threads=Threads.nthreads(),scope="full runner including daily checkpoint writes; compilation included; one run each")))
 for backend in ("batch_cpu","gpu")
  output=joinpath(root,backend)
  cmd=`$(Base.julia_cmd()) --project=$repo $(joinpath(source,"experiments/lw_wildlife/crossing_longrun.jl")) $input unused $output $days true 0 1.5 $checkpoint true $backend`
  println("START ",backend);flush(stdout);run(cmd)
 end
 cpu=JSON3.read(read(joinpath(root,"batch_cpu/result.json"),String));gpu=JSON3.read(read(joinpath(root,"gpu/result.json"),String))
 comparisons=Any[]
 for day in 0:days
  filename="day-"*lpad(day,3,'0')*".jls"
  hash(path)=open(io->bytes2hex(sha256(io)),path)
  a=hash(joinpath(root,"batch_cpu/checkpoints",filename));b=hash(joinpath(root,"gpu/checkpoints",filename))
  push!(comparisons,(day,identical=a==b,cpu_sha256=a,gpu_sha256=b))
 end
 summary=(days,cpu_seconds=cpu.seconds,gpu_seconds=gpu.seconds,cpu_bytes=cpu.bytes,gpu_bytes=gpu.bytes,all_checkpoints_identical=all(x->x.identical,comparisons),comparisons)
 write(joinpath(root,"comparison.json"),JSON3.write(summary));println(JSON3.write(summary));flush(stdout)
 write(joinpath(root,"completed.json"),JSON3.write((days,complete=true,all_checkpoints_identical=summary.all_checkpoints_identical)))
end
main()
