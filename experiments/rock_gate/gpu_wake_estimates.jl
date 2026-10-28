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
 T=eltype(a)
 @inbounds for i in axes(a,2)
  base=a[1,i];search=a[2,i];mean=a[3,i];q=a[4,i];last=a[5,i];rate=a[6,i]
  center=base
  if mean<0
   upper=max(T(2),ceil(center+max(search>0 ? T(128) : T(4),center)))
  else
   scale=search>0 ? one(T) : base
   center=max(one(T),mean*scale)
   horizon=q<0 ? last*scale+max(T(4),T(.25)*last*scale) : q*scale
   upper=max(T(2),ceil(max(center,horizon)))
  end
  out[4i-3]=center;out[4i-2]=upper;out[4i-1]=upper*rate;out[4i]=center*rate
 end
end
function pack(rows)
 a=Matrix{Float32}(undef,6,length(rows))
 for (i,r) in enumerate(rows)
  a[:,i].=(r.baseline,Float32(r.search),r.mean,r.q80,r.last,r.rate)
 end
 a
end
function main()
 d=devices();name=info(d,0x102b);println(name);flush(stdout)
 err=Ref{Int32}(0)
 ctx=ccall((:clCreateContext,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt32,Ref{Ptr{Cvoid}},Ptr{Cvoid},Ptr{Cvoid},Ref{Int32}),C_NULL,1,Ref(d),C_NULL,C_NULL,err);check(err[])
 q=ccall((:clCreateCommandQueue,CL),Ptr{Cvoid},(Ptr{Cvoid},Ptr{Cvoid},UInt64,Ref{Int32}),ctx,d,0,err);check(err[])
 source="__kernel void score(__global const float *a,__global const float *b,__global float *out){size_t i=get_global_id(0);float base=a[6*i],search=a[6*i+1],mean=a[6*i+2],q=a[6*i+3],last=a[6*i+4],rate=a[6*i+5];float center=base,upper;if(mean<0){upper=fmax(2.0f,ceil(center+fmax(search>0?128.0f:4.0f,center)));}else{float scale=search>0?1.0f:base;center=fmax(1.0f,mean*scale);float horizon=q<0?last*scale+fmax(4.0f,.25f*last*scale):q*scale;upper=fmax(2.0f,ceil(fmax(center,horizon)));}out[4*i]=center;out[4*i+1]=upper;out[4*i+2]=upper*rate;out[4*i+3]=center*rate;}"
 prog=GC.@preserve source ccall((:clCreateProgramWithSource,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt32,Ref{Ptr{UInt8}},Ptr{Csize_t},Ref{Int32}),ctx,1,Ref(pointer(source)),C_NULL,err);check(err[])
 check(ccall((:clBuildProgram,CL),Int32,(Ptr{Cvoid},UInt32,Ref{Ptr{Cvoid}},Cstring,Ptr{Cvoid},Ptr{Cvoid}),prog,1,Ref(d),"",C_NULL,C_NULL))
 kernel=ccall((:clCreateKernel,CL),Ptr{Cvoid},(Ptr{Cvoid},Cstring,Ref{Int32}),prog,"score",err);check(err[])
 rows=Any[];captured=JSON3.read(read(ARGS[2],String));workloads=Any[]
 for day in captured
  push!(workloads,(label="day$(day.day)_largest",data=day.batches[argmax(length.(day.batches))]))
 end
 push!(workloads,(label="pooled_independent_samples",data=vcat([collect(b) for day in captured for b in day.batches]...)))
 for workload in workloads
  data=workload.data;n=length(data);a=pack(data);b=zeros(Float32,1);out=zeros(Float32,4n);ref=similar(out)
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
   if transfer;a=pack(data);upload();end
   check(ccall((:clEnqueueNDRangeKernel,CL),Int32,(Ptr{Cvoid},Ptr{Cvoid},UInt32,Ptr{Csize_t},Ref{Csize_t},Ptr{Csize_t},UInt32,Ptr{Cvoid},Ptr{Cvoid}),q,kernel,1,C_NULL,Ref(Csize_t(n)),C_NULL,0,C_NULL,C_NULL))
   check(ccall((:clEnqueueReadBuffer,CL),Int32,(Ptr{Cvoid},Ptr{Cvoid},UInt32,Csize_t,Csize_t,Ptr{Cvoid},UInt32,Ptr{Cvoid},Ptr{Cvoid}),q,buffers[3],1,0,sizeof(out),out,0,C_NULL,C_NULL))
  end
  cpu!(ref,a,b);gpu!(true)
  error_max=maximum(abs.(ref.-out));@test all(isapprox.(ref,out;rtol=2f-5,atol=2f-7))
  reference64=Float64[v for r in data for v in (r.expected_actions,r.upper_actions,r.energy,r.expected_energy)]
  error64=maximum(abs.(reference64.-out));relative64=maximum(abs.(reference64.-out)./max.(1.,abs.(reference64)))
  upper_mismatches=count(reference64[2:4:end].!=out[2:4:end])
  @test relative64<1e-4
  timings=Dict(k=>Float64[] for k in ("cpu","cpu_pack","gpu_transfer","gpu_resident"))
  for repeat in 1:9
   order=isodd(repeat) ? ("cpu","cpu_pack","gpu_transfer","gpu_resident") : ("gpu_resident","gpu_transfer","cpu_pack","cpu")
   for k in order
    t=time_ns();k=="cpu" ? cpu!(ref,a,b) : k=="cpu_pack" ? cpu!(ref,pack(data),b) : gpu!(k=="gpu_transfer");push!(timings[k],(time_ns()-t)/1e9)
   end
  end
  row=Dict("label"=>workload.label,"upper_action_mismatches"=>upper_mismatches,"max_relative_error_float64"=>relative64,"candidates"=>n,"max_abs_error"=>error_max,"max_abs_error_float64"=>error64,"seconds"=>timings,"median_seconds"=>Dict(k=>median(v) for (k,v) in timings));push!(rows,row);println(JSON3.write(row));flush(stdout)
  for buf in buffers;check(ccall((:clReleaseMemObject,CL),Int32,(Ptr{Cvoid},),buf));end
 end
 for (f,p) in ((:clReleaseKernel,kernel),(:clReleaseProgram,prog),(:clReleaseCommandQueue,q),(:clReleaseContext,ctx))
  # Dynamic symbol lookup is only needed for final cleanup.
  if f==:clReleaseKernel;ccall((:clReleaseKernel,CL),Int32,(Ptr{Cvoid},),p)
  elseif f==:clReleaseProgram;ccall((:clReleaseProgram,CL),Int32,(Ptr{Cvoid},),p)
  elseif f==:clReleaseCommandQueue;ccall((:clReleaseCommandQueue,CL),Int32,(Ptr{Cvoid},),p)
  else;ccall((:clReleaseContext,CL),Int32,(Ptr{Cvoid},),p);end
 end
 write(ARGS[1],JSON3.write(Dict("device"=>name,"scope"=>"actual captured parent numeric forecasts, Float32; model lookup/survival fitting excluded; gpu_transfer includes packing/uploads/readback; resident includes readback; CPU single thread; buffers preallocated","rows"=>rows)))
end
main()

