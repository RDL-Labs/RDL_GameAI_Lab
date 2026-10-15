include("../julia/src/RDLMigrationProbe.jl")
using .RDLMigrationProbe

function convert_queries(raw,n)
    values=reinterpret(Float64,raw)
    qs=Vector{Query}(undef,n)
    for i in 1:n
        j=(i-1)*9
        k,sx,sz,vx,vz,x,z,r,m=ntuple(t->values[j+t],9)
        k in (0.,1.) || error("kind")
        all(v->isfinite(v) && abs(v)<=10000,(sx,sz,vx,vz,x,z,r,m)) || error("domain")
        r>=0 && m>=0 || error("negative")
        k==1 && abs(hypot(vx,vz)-1)>1e-12 && error("direction")
        qs[i]=Query(k==1,(sx,sz),(vx,vz),RDLMigrationProbe.Circle(x,z,r),m)
    end
    qs
end

function main()
    VERSION==v"1.13.1" || error("version")
    ENDIAN_BOM==0x04030201 || error("little_endian_required")
    println("RDLJ3_READY");flush(stdout)
    while !eof(stdin)
        read(stdin,4)==UInt8[0x52,0x44,0x4c,0x33] || error("request_magic")
        seq=read(stdin,UInt64);n=Int(read(stdin,UInt32))
        n<=100000 || error("capacity")
        raw=read(stdin,72*n)
        length(raw)==72*n || error("short_request")
        converted=@timed convert_queries(raw,n)
        computed=@timed batch(converted.value)
        write(stdout,codeunits("RDR3"),seq,UInt32(n),UInt64(round(converted.time*1e9)),
            UInt64(round(computed.time*1e9)),UInt64(converted.bytes+computed.bytes),
            UInt64(round((converted.gctime+computed.gctime)*1e9)))
        output=IOBuffer()
        for value in computed.value
            tag=value===nothing ? UInt8(0) : value isa Bool ? (value ? UInt8(2) : UInt8(1)) : UInt8(3)
            write(output,tag,tag==3 ? Float64(value) : 0.)
        end
        write(stdout,take!(output));flush(stdout)
    end
end
main()
