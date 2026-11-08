# Optional execution backend, no behavior policy. Runtime handles are never serialized.
module RabbitNeighborOpenCL
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

mutable struct Backend
 ctx::Ptr{Cvoid};q::Ptr{Cvoid};prog::Ptr{Cvoid};kernel::Ptr{Cvoid}
 buffers::Vector{Ptr{Cvoid}};capacity::Int;device::String
end
function Backend(world)
 d=devices();name=info(d,0x102b)
 obstacles=zeros(Float32,3,max(1,length(world.obstacles)))
 for (i,o) in enumerate(world.obstacles);obstacles[:,i].=(o.x,o.z,o.radius);end
 isempty(world.obstacles) && (obstacles[:,1].=(1f8,1f8,0f0))
 err=Ref{Int32}(0)
 ctx=ccall((:clCreateContext,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt32,Ref{Ptr{Cvoid}},Ptr{Cvoid},Ptr{Cvoid},Ref{Int32}),C_NULL,1,Ref(d),C_NULL,C_NULL,err);check(err[])
 q=ccall((:clCreateCommandQueue,CL),Ptr{Cvoid},(Ptr{Cvoid},Ptr{Cvoid},UInt64,Ref{Int32}),ctx,d,0,err);check(err[])
 source="__kernel void score(__global const float *a,__global const float *b,__global float *out){size_t i=get_global_id(0);float x=a[4*i],z=a[4*i+1],dx=a[4*i+2]-x,dz=a[4*i+3]-z,l=dx*dx+dz*dz,gap=1e20f;for(int j=0;j<$(size(obstacles,2));j++){float u=l!=0?clamp(((b[3*j]-x)*dx+(b[3*j+1]-z)*dz)/l,0.0f,1.0f):0;float ex=x+u*dx-b[3*j],ez=z+u*dz-b[3*j+1];gap=fmin(gap,sqrt(ex*ex+ez*ez)-(b[3*j+2]+.25f));}out[i]=gap;}"
 prog=GC.@preserve source ccall((:clCreateProgramWithSource,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt32,Ref{Ptr{UInt8}},Ptr{Csize_t},Ref{Int32}),ctx,1,Ref(pointer(source)),C_NULL,err);check(err[])
 check(ccall((:clBuildProgram,CL),Int32,(Ptr{Cvoid},UInt32,Ref{Ptr{Cvoid}},Cstring,Ptr{Cvoid},Ptr{Cvoid}),prog,1,Ref(d),"",C_NULL,C_NULL))
 kernel=ccall((:clCreateKernel,CL),Ptr{Cvoid},(Ptr{Cvoid},Cstring,Ref{Int32}),prog,"score",err);check(err[])

 buffers=Ptr{Cvoid}[]
 for bytes in (16,sizeof(obstacles),4)
  ptr=ccall((:clCreateBuffer,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt64,Csize_t,Ptr{Cvoid},Ref{Int32}),ctx,1,bytes,C_NULL,err);check(err[]);push!(buffers,ptr)
 end
 check(ccall((:clEnqueueWriteBuffer,CL),Int32,(Ptr{Cvoid},Ptr{Cvoid},UInt32,Csize_t,Csize_t,Ptr{Cvoid},UInt32,Ptr{Cvoid},Ptr{Cvoid}),q,buffers[2],1,0,sizeof(obstacles),obstacles,0,C_NULL,C_NULL))
 Backend(ctx,q,prog,kernel,buffers,1,name)
end
function evaluate!(backend,queries,output,n)
 if n>backend.capacity
  for i in (1,3)
   check(ccall((:clReleaseMemObject,CL),Int32,(Ptr{Cvoid},),backend.buffers[i]))
   err=Ref{Int32}(0);bytes=sizeof(Float32)*n*(i==1 ? 4 : 1)
   backend.buffers[i]=ccall((:clCreateBuffer,CL),Ptr{Cvoid},(Ptr{Cvoid},UInt64,Csize_t,Ptr{Cvoid},Ref{Int32}),backend.ctx,1,bytes,C_NULL,err);check(err[])
  end
  backend.capacity=n
 end
 for i in 1:3
  check(ccall((:clSetKernelArg,CL),Int32,(Ptr{Cvoid},UInt32,Csize_t,Ref{Ptr{Cvoid}}),backend.kernel,i-1,sizeof(Ptr{Cvoid}),Ref(backend.buffers[i])))
 end
 check(ccall((:clEnqueueWriteBuffer,CL),Int32,(Ptr{Cvoid},Ptr{Cvoid},UInt32,Csize_t,Csize_t,Ptr{Cvoid},UInt32,Ptr{Cvoid},Ptr{Cvoid}),backend.q,backend.buffers[1],1,0,16n,queries,0,C_NULL,C_NULL))
 check(ccall((:clEnqueueNDRangeKernel,CL),Int32,(Ptr{Cvoid},Ptr{Cvoid},UInt32,Ptr{Csize_t},Ref{Csize_t},Ptr{Csize_t},UInt32,Ptr{Cvoid},Ptr{Cvoid}),backend.q,backend.kernel,1,C_NULL,Ref(Csize_t(n)),C_NULL,0,C_NULL,C_NULL))
 check(ccall((:clEnqueueReadBuffer,CL),Int32,(Ptr{Cvoid},Ptr{Cvoid},UInt32,Csize_t,Csize_t,Ptr{Cvoid},UInt32,Ptr{Cvoid},Ptr{Cvoid}),backend.q,backend.buffers[3],1,0,4n,output,0,C_NULL,C_NULL))
end
function close!(b)
 for p in b.buffers;ccall((:clReleaseMemObject,CL),Int32,(Ptr{Cvoid},),p);end
 ccall((:clReleaseKernel,CL),Int32,(Ptr{Cvoid},),b.kernel)
 ccall((:clReleaseProgram,CL),Int32,(Ptr{Cvoid},),b.prog)
 ccall((:clReleaseCommandQueue,CL),Int32,(Ptr{Cvoid},),b.q)
 ccall((:clReleaseContext,CL),Int32,(Ptr{Cvoid},),b.ctx)
end
end
