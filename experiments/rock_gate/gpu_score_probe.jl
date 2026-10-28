# Isolated Windows OpenCL probe; no production dependencies or policy changes.
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
  s=0f0
  for j in 1:5;s+=exp(-2f0*a[j,i]-b[j,i]);end
  out[i]=s/5f0
 end
end
function main()
 d=devices();name=info(d,0x102b);println(name);flush(stdout)
 err=Ref{Int32}(0)
 ctx=ccall((:clCreateContext,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt32,Ref{Ptr{Cvoid}},Ptr{Cvoid},Ptr{Cvoid},Ref{Int32}),C_NULL,1,Ref(d),C_NULL,C_NULL,err);check(err[])
 q=ccall((:clCreateCommandQueue,CL),Ptr{Cvoid},(Ptr{Cvoid},Ptr{Cvoid},UInt64,Ref{Int32}),ctx,d,0,err);check(err[])
 source="__kernel void score(__global const float *a,__global const float *b,__global float *out){size_t i=get_global_id(0);float s=0;for(int j=0;j<5;j++)s+=exp(-2.0f*a[5*i+j]-b[5*i+j]);out[i]=s/5.0f;}"
 prog=GC.@preserve source ccall((:clCreateProgramWithSource,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt32,Ref{Ptr{UInt8}},Ptr{Csize_t},Ref{Int32}),ctx,1,Ref(pointer(source)),C_NULL,err);check(err[])
 check(ccall((:clBuildProgram,CL),Int32,(Ptr{Cvoid},UInt32,Ref{Ptr{Cvoid}},Cstring,Ptr{Cvoid},Ptr{Cvoid}),prog,1,Ref(d),"",C_NULL,C_NULL))
 kernel=ccall((:clCreateKernel,CL),Ptr{Cvoid},(Ptr{Cvoid},Cstring,Ref{Int32}),prog,"score",err);check(err[])
 rows=Any[];rng=MersenneTwister(20261028)
 for n in (128,1280,10000,100000,1000000)
  a=rand(rng,Float32,5,n).*2f0;b=rand(rng,Float32,5,n).*6f0;out=zeros(Float32,n);ref=similar(out)
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
  reference64=[sum(exp(-2.0*Float64(a[j,i])-Float64(b[j,i])) for j in 1:5)/5 for i in 1:n]
  error64=maximum(abs.(reference64.-out));@test error64<2e-7
  timings=Dict(k=>Float64[] for k in ("cpu","gpu_transfer","gpu_resident"))
  for repeat in 1:9
   order=isodd(repeat) ? ("cpu","gpu_transfer","gpu_resident") : ("gpu_resident","gpu_transfer","cpu")
   for k in order
    t=time_ns();k=="cpu" ? cpu!(ref,a,b) : gpu!(k=="gpu_transfer");push!(timings[k],(time_ns()-t)/1e9)
   end
  end
  row=Dict("candidates"=>n,"max_abs_error"=>error_max,"max_abs_error_float64"=>error64,"seconds"=>timings,"median_seconds"=>Dict(k=>median(v) for (k,v) in timings));push!(rows,row);println(JSON3.write(row));flush(stdout)
  for buf in buffers;check(ccall((:clReleaseMemObject,CL),Int32,(Ptr{Cvoid},),buf));end
 end
 for (f,p) in ((:clReleaseKernel,kernel),(:clReleaseProgram,prog),(:clReleaseCommandQueue,q),(:clReleaseContext,ctx))
  # Dynamic symbol lookup is only needed for final cleanup.
  if f==:clReleaseKernel;ccall((:clReleaseKernel,CL),Int32,(Ptr{Cvoid},),p)
  elseif f==:clReleaseProgram;ccall((:clReleaseProgram,CL),Int32,(Ptr{Cvoid},),p)
  elseif f==:clReleaseCommandQueue;ccall((:clReleaseCommandQueue,CL),Int32,(Ptr{Cvoid},),p)
  else;ccall((:clReleaseContext,CL),Int32,(Ptr{Cvoid},),p);end
 end
 write(ARGS[1],JSON3.write(Dict("device"=>name,"scope"=>"synthetic 5-feature Float32 score only; CPU single thread; resident includes readback; buffers preallocated; packing and initialization excluded","rows"=>rows)))
end
main()
