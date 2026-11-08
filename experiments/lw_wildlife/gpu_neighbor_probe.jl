# Isolated Windows OpenCL neighbor-geometry benchmark; no production policy changes.
# Actual map circles, synthetic positions/grass; all actors evaluate 8 neighbors.
# Excludes river/walkability filters, heading/H selection, allocation, movement, reproduction.
# Float32 on both backends; production Float64 and trajectories are not validated here.
# 9 alternating timed repeats after warmup, synchronous readback, preallocated buffers.
using JSON3, Statistics, Random, Test
const CL="OpenCL.dll"
check(e)=e==0 ? nothing : error("OpenCL status $e")
function devices()
 n=Ref{UInt32}(0);check(ccall((:clGetPlatformIDs,CL),Int32,(UInt32,Ptr{Ptr{Cvoid}},Ref{UInt32}),0,C_NULL,n))
 ps=Vector{Ptr{Cvoid}}(undef,n[]);check(ccall((:clGetPlatformIDs,CL),Int32,(UInt32,Ptr{Ptr{Cvoid}},Ptr{UInt32}),n[],ps,C_NULL))
 for p in ps
  n[]=0;e=ccall((:clGetDeviceIDs,CL),Int32,(Ptr{Cvoid},UInt64,UInt32,Ptr{Ptr{Cvoid}},Ref{UInt32}),p,4,0,C_NULL,n)
  e==-1 && continue;check(e)
  ds=Vector{Ptr{Cvoid}}(undef,n[]);check(ccall((:clGetDeviceIDs,CL),Int32,(Ptr{Cvoid},UInt64,UInt32,Ptr{Ptr{Cvoid}},Ptr{UInt32}),p,4,n[],ds,C_NULL))
  !isempty(ds) && return first(ds)
 end
 error("No OpenCL GPU device")
end
function info(d,param)
 n=Ref{Csize_t}(0);check(ccall((:clGetDeviceInfo,CL),Int32,(Ptr{Cvoid},UInt32,Csize_t,Ptr{Cvoid},Ref{Csize_t}),d,param,0,C_NULL,n))
 b=zeros(UInt8,n[]);check(ccall((:clGetDeviceInfo,CL),Int32,(Ptr{Cvoid},UInt32,Csize_t,Ptr{Cvoid},Ptr{Csize_t}),d,param,length(b),b,C_NULL));String(b[1:end-1])
end
function cpu!(out,a,b)
 @inbounds for i in eachindex(out)
  x=a[1,i];z=a[2,i];tx=a[3,i];tz=a[4,i];grass=a[5,i];dx=tx-x;dz=tz-z;len2=dx*dx+dz*dz;blocked=false
  for j in axes(b,2)
   u=clamp(((b[1,j]-x)*dx+(b[2,j]-z)*dz)/max(len2,1f-12),0f0,1f0)
   ex=x+u*dx-b[1,j];ez=z+u*dz-b[2,j]
   if ex*ex+ez*ez<=(b[3,j]+.25f0)^2;blocked=true;break;end
  end
  out[i]=blocked ? -1000f0 : grass-.25f0*sqrt(len2)
 end
end
function main()
 scene=JSON3.read(read(ARGS[2],String)).scene
 objects=vcat(collect(scene.obstacles),collect(scene.low_obstacles))
 objects=filter(o->!hasproperty(o,:solid)||o.solid,objects)
 obstacles=hcat([Float32[o.x,o.z,o.radius] for o in objects]...)
 d=devices();name=info(d,0x102b);println(name);flush(stdout)
 err=Ref{Int32}(0)
 ctx=ccall((:clCreateContext,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt32,Ref{Ptr{Cvoid}},Ptr{Cvoid},Ptr{Cvoid},Ref{Int32}),C_NULL,1,Ref(d),C_NULL,C_NULL,err);check(err[])
 q=ccall((:clCreateCommandQueue,CL),Ptr{Cvoid},(Ptr{Cvoid},Ptr{Cvoid},UInt64,Ref{Int32}),ctx,d,0,err);check(err[])
 source="__kernel void score(__global const float *a,__global const float *b,__global float *out){size_t i=get_global_id(0);float x=a[5*i],z=a[5*i+1],dx=a[5*i+2]-x,dz=a[5*i+3]-z,l=dx*dx+dz*dz;int blocked=0;for(int j=0;j<$(size(obstacles,2));j++){float u=clamp(((b[3*j]-x)*dx+(b[3*j+1]-z)*dz)/fmax(l,1e-12f),0.0f,1.0f);float ex=x+u*dx-b[3*j],ez=z+u*dz-b[3*j+1],r=b[3*j+2]+.25f;if(ex*ex+ez*ez<=r*r){blocked=1;break;}}out[i]=blocked?-1000.0f:a[5*i+4]-.25f*sqrt(l);}"

 prog=GC.@preserve source ccall((:clCreateProgramWithSource,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt32,Ref{Ptr{UInt8}},Ptr{Csize_t},Ref{Int32}),ctx,1,Ref(pointer(source)),C_NULL,err);check(err[])
 check(ccall((:clBuildProgram,CL),Int32,(Ptr{Cvoid},UInt32,Ref{Ptr{Cvoid}},Cstring,Ptr{Cvoid},Ptr{Cvoid}),prog,1,Ref(d),"",C_NULL,C_NULL))
 kernel=ccall((:clCreateKernel,CL),Ptr{Cvoid},(Ptr{Cvoid},Cstring,Ref{Int32}),prog,"score",err);check(err[])
 rows=Any[];rng=MersenneTwister(20261028)
 for rabbits in (300,1000,3000,10000)
  n=8rabbits
  a=zeros(Float32,5,n);b=obstacles;out=zeros(Float32,n);ref=similar(out)
  xmin,xmax,zmin,zmax=Float32.(scene.landscape.extent)
  offsets=((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1))
  for actor in 1:rabbits
   x=xmin+rand(rng)*(xmax-xmin);z=zmin+rand(rng)*(zmax-zmin)
   for (j,(dx,dz)) in enumerate(offsets)
    i=8(actor-1)+j;a[:,i].=(x,z,x+2dx,z+2dz,rand(rng)*9f0)
   end
  end
  buffers=Ptr{Cvoid}[]
  for bytes in (sizeof(a),sizeof(b),sizeof(out))
   ptr=ccall((:clCreateBuffer,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt64,Csize_t,Ptr{Cvoid},Ref{Int32}),ctx,1,bytes,C_NULL,err);check(err[]);push!(buffers,ptr)
  end
  for i in 1:3;check(ccall((:clSetKernelArg,CL),Int32,(Ptr{Cvoid},UInt32,Csize_t,Ref{Ptr{Cvoid}}),kernel,i-1,sizeof(Ptr{Cvoid}),Ref(buffers[i])));end
  function upload()
   for (buf,x) in zip(buffers,(a,b))
    check(ccall((:clEnqueueWriteBuffer,CL),Int32,(Ptr{Cvoid},Ptr{Cvoid},UInt32,Csize_t,Csize_t,Ptr{Cvoid},UInt32,Ptr{Cvoid},Ptr{Cvoid}),q,buf,1,0,sizeof(x),x,0,C_NULL,C_NULL))
   end
  end
  function gpu!(transfer)
   transfer && upload()
   check(ccall((:clEnqueueNDRangeKernel,CL),Int32,(Ptr{Cvoid},Ptr{Cvoid},UInt32,Ptr{Csize_t},Ref{Csize_t},Ptr{Csize_t},UInt32,Ptr{Cvoid},Ptr{Cvoid}),q,kernel,1,C_NULL,Ref(Csize_t(n)),C_NULL,0,C_NULL,C_NULL))
   check(ccall((:clEnqueueReadBuffer,CL),Int32,(Ptr{Cvoid},Ptr{Cvoid},UInt32,Csize_t,Csize_t,Ptr{Cvoid},UInt32,Ptr{Cvoid},Ptr{Cvoid}),q,buffers[3],1,0,sizeof(out),out,0,C_NULL,C_NULL))
  end
  cpu!(ref,a,b);gpu!(true)
  error_max=maximum(abs.(ref.-out));@test all(isapprox.(ref,out;rtol=2f-5,atol=2f-7))
  error64=nothing
  timings=Dict(k=>Float64[] for k in ("cpu","gpu_transfer","gpu_resident"))
  for repeat in 1:9
   order=isodd(repeat) ? ("cpu","gpu_transfer","gpu_resident") : ("gpu_resident","gpu_transfer","cpu")
   for k in order
    t=time_ns();k=="cpu" ? cpu!(ref,a,b) : gpu!(k=="gpu_transfer");push!(timings[k],(time_ns()-t)/1e9)
   end
  end
  row=Dict("rabbits"=>rabbits,"obstacles"=>size(b,2),"candidates"=>n,"max_abs_error"=>error_max,"max_abs_error_float64"=>error64,"seconds"=>timings,"median_seconds"=>Dict(k=>median(v) for (k,v) in timings));push!(rows,row);println(JSON3.write(row));flush(stdout)
  for buf in buffers;check(ccall((:clReleaseMemObject,CL),Int32,(Ptr{Cvoid},),buf));end
 end
 for (f,p) in ((:clReleaseKernel,kernel),(:clReleaseProgram,prog),(:clReleaseCommandQueue,q),(:clReleaseContext,ctx))
  # Dynamic symbol lookup is only needed for final cleanup.
  if f==:clReleaseKernel;ccall((:clReleaseKernel,CL),Int32,(Ptr{Cvoid},),p)
  elseif f==:clReleaseProgram;ccall((:clReleaseProgram,CL),Int32,(Ptr{Cvoid},),p)
  elseif f==:clReleaseCommandQueue;ccall((:clReleaseCommandQueue,CL),Int32,(Ptr{Cvoid},),p)
  else;ccall((:clReleaseContext,CL),Int32,(Ptr{Cvoid},),p);end
 end
 write(ARGS[1],JSON3.write(Dict("device"=>name,"scope"=>"isolated 8-neighbor distance/solid-circle/grass score; real map obstacles, synthetic positions/grass; Float32 CPU single thread; resident includes readback; preallocated; packing excluded; NOT full ecology or production equivalence","rows"=>rows)))
end
main()
