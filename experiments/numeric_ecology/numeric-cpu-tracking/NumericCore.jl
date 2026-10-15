module NumericCore
using SHA, JSON3
export NID, nid, ncat, njoin, njson, nhex, encode, decode, audit, register_symbol!

"Numeric identity for a categorical value, field, agent, MB or experience reference."
struct NID
    value::UInt64
end
const BYTES=Vector{Vector{UInt8}}()
const BUCKETS=Dict{UInt64,Vector{UInt64}}()
const SYMBOLS=Dict{Symbol,NID}()
const REVERSE_SYMBOLS=Dict{NID,Symbol}()
const AGENT_COUNT=Ref(30)
const AUDITS=Int[]
const TRACK_IDS=Ref(true)
const PINNED=Ref(0)
const FREE=UInt64[]
const COLLECTIONS=Ref(0)
const RECLAIMED=Ref(0)
function bytehash(bytes)
    h=UInt64(0xcbf29ce484222325)
    for b in bytes; h=(h ⊻ UInt64(b))*UInt64(0x100000001b3); end
    h
end
function intern(bytes::Vector{UInt8})
    # Explicit collision resolution: hash collisions never merge identities.
    h=bytehash(bytes)
    bucket=get!(BUCKETS,h,UInt64[])
    for i in bucket
        BYTES[i]==bytes && return NID(i)
    end
    if isempty(FREE)
        push!(BYTES,copy(bytes)); i=UInt64(length(BYTES))
    else
        i=pop!(FREE); BYTES[i]=copy(bytes)
    end
    push!(bucket,i); NID(i)
end
function markids!(marked,x,seen)
    if x isa NID
        marked[x.value]=true
        return
    end
    (x isa Number || x isa Symbol || x===nothing || x isa Type || x isa Module || x isa AbstractString) && return
    if ismutabletype(typeof(x))
        haskey(seen,x) && return
        seen[x]=true
    end
    if x isa AbstractDict
        for (k,v) in x; markids!(marked,k,seen); markids!(marked,v,seen); end
    elseif x isa Union{AbstractArray,Tuple,NamedTuple,AbstractSet}
        for v in x; markids!(marked,v,seen); end
    else
        # Include closure captures, which can keep model state alive.
        for i in 1:fieldcount(typeof(x))
            isdefined(x,i) && markids!(marked,getfield(x,i),seen)
        end
    end
end
function collect_ids!(roots)
    TRACK_IDS[] && return
    marked=falses(length(BYTES)); marked[1:PINNED[]].=true
    seen=IdDict{Any,Bool}()
    markids!(marked,roots,seen)
    markids!(marked,SYMBOLS,seen)
    oldfree=Set(FREE)
    for i in PINNED[]+1:length(BYTES)
        (marked[i] || UInt64(i) in oldfree) && continue
        h=bytehash(BYTES[i]); bucket=BUCKETS[h]
        filter!(j->j!=i,bucket)
        isempty(bucket) && delete!(BUCKETS,h)
        BYTES[i]=UInt8[]; push!(FREE,UInt64(i)); RECLAIMED[]+=1
    end
    COLLECTIONS[]+=1
end
function restore_registry!(bytes,free)
    empty!(BYTES); append!(BYTES,deepcopy(bytes))
    empty!(FREE); append!(FREE,free)
    empty!(BUCKETS); vacant=Set(free)
    for i in eachindex(BYTES)
        UInt64(i) in vacant && continue
        push!(get!(BUCKETS,bytehash(BYTES[i]),UInt64[]),UInt64(i))
    end
end
nid(x::NID)=x
nid(x::AbstractString)=intern(collect(codeunits(x))) # input/build boundary
nid(x::Symbol)=SYMBOLS[x]
nid(x::Char)=intern(UInt8[UInt8(x)])
function nid(x::Integer)
    x==0 && return intern(UInt8[0x30])
    n=abs(big(x)); b=UInt8[]
    while n>0; push!(b,UInt8(rem(n,10))+0x30); n=div(n,10); end
    x<0 && push!(b,0x2d)
    intern(reverse!(b))
end
# Numerical formatting is a boundary used only for externally formatted scalar references.
nid(x::AbstractFloat)=begin io=IOBuffer(); print(io,x); intern(take!(io)); end
nid(x::Nothing)=intern(UInt8[0x6e,0x6f,0x74,0x68,0x69,0x6e,0x67])
nid(x::Bool)=intern(x ? UInt8[0x74,0x72,0x75,0x65] : UInt8[0x66,0x61,0x6c,0x73,0x65])
NID(x::Union{AbstractString,Symbol,NID})=nid(x)
Base.convert(::Type{NID},x::Union{AbstractString,Symbol,NID})=nid(x)
function register_symbol!(s::Symbol)
    id=nid(String(s)); SYMBOLS[s]=id; REVERSE_SYMBOLS[id]=s; id
end
Base.Symbol(x::NID)=REVERSE_SYMBOLS[x]
Base.:(==)(a::NID,b::NID)=a.value==b.value
Base.isequal(a::NID,b::NID)=a.value==b.value
Base.hash(a::NID,h::UInt)=hash(a.value,h)
function Base.isless(a::NID,b::NID)
    x,y=BYTES[a.value],BYTES[b.value]
    for i in 1:min(length(x),length(y))
        x[i]!=y[i] && return x[i]<y[i]
    end
    length(x)<length(y)
end
Base.isempty(x::NID)=isempty(BYTES[x.value])
Base.length(x::NID)=length(BYTES[x.value])
Base.getindex(x::NID,r::UnitRange{Int})=intern(BYTES[x.value][r])
Base.show(io::IO,x::NID)=print(io,"NID(",x.value,")")
Base.startswith(x::NID,p::NID)=length(x)>=length(p) && view(BYTES[x.value],1:length(p))==BYTES[p.value]
Base.endswith(x::NID,p::NID)=length(x)>=length(p) && view(BYTES[x.value],length(x)-length(p)+1:length(x))==BYTES[p.value]
Base.occursin(c::Char,x::NID)=UInt8(c) in BYTES[x.value]
function Base.split(x::NID,c::Char)
    b=BYTES[x.value]; out=NID[]; start=1
    for i in eachindex(b)
        if b[i]==UInt8(c); push!(out,intern(b[start:i-1])); start=i+1; end
    end
    push!(out,intern(b[start:end])); out
end
function Base.parse(::Type{T},x::NID) where T<:Integer
    b=BYTES[x.value]; isempty(b) && throw(ArgumentError("empty numeric reference"))
    negative=b[1]==0x2d; start=negative ? 2 : 1; start>length(b) && throw(ArgumentError("invalid numeric reference"))
    value=zero(T)
    for i in start:length(b)
        0x30<=b[i]<=0x39 || throw(ArgumentError("non-numeric reference"))
        value=negative ? Base.checked_sub(Base.checked_mul(value,T(10)),T(b[i]-0x30)) : Base.checked_add(Base.checked_mul(value,T(10)),T(b[i]-0x30))
    end
    value
end
function ncat(xs...)
    b=UInt8[]
    for x in xs; append!(b,BYTES[nid(x).value]); end
    intern(b)
end
Base.:*(a::NID,b::NID)=ncat(a,b)
function njoin(xs,separator)
    b=UInt8[]; first=true
    for x in xs
        first || append!(b,BYTES[nid(separator).value])
        append!(b,BYTES[nid(x).value]); first=false
    end
    intern(b)
end
SHA.sha256(x::NID)=SHA.sha256(BYTES[x.value])
function nhex(bytes)
    digits=UInt8[0x30:0x39;0x61:0x66]
    out=UInt8[]
    for b in bytes; push!(out,digits[Int(b>>4)+1],digits[Int(b&0x0f)+1]); end
    intern(out)
end
function jsonbytes(io,x::NID)
    write(io,0x22)
    for b in BYTES[x.value]
        if b in (0x22,0x5c); write(io,0x5c,b)
        elseif b in (0x08,0x09,0x0a,0x0c,0x0d)
            escape=b==0x08 ? 0x62 : b==0x09 ? 0x74 : b==0x0a ? 0x6e : b==0x0c ? 0x66 : 0x72
            write(io,0x5c,escape)
        elseif b<0x20
            write(io,UInt8[0x5c,0x75,0x30,0x30]); write(io,BYTES[nhex(UInt8[b]).value])
        else; write(io,b)
        end
    end
    write(io,0x22)
end
function jsonbytes(io,x::Union{Tuple,AbstractVector})
    write(io,0x5b)
    for (i,v) in enumerate(x); i>1 && write(io,0x2c); jsonbytes(io,v); end
    write(io,0x5d)
end
jsonbytes(io,x::Union{Number,Nothing})=JSON3.write(io,x)
function njson(x)
    io=IOBuffer(); jsonbytes(io,x); intern(take!(io))
end

# JSON-like inputs retain property access through NamedTuples, but all values are encoded.
encode(x::AbstractString)=nid(x)
encode(x::AbstractVector)=[encode(v) for v in x]
function encode(x::AbstractDict)
    names=Tuple(Symbol(k) for k in keys(x))
    foreach(register_symbol!,names)
    NamedTuple{names}(Tuple(encode(v) for v in values(x)))
end
encode(x::NamedTuple)=NamedTuple{keys(x)}(map(encode,values(x)))
encode(x)=x
decode(x::NID)=String(copy(BYTES[x.value]))
decode(x::AbstractDict)=Dict(decode(k)=>decode(v) for (k,v) in x)
decode(x::NamedTuple)=Dict(String(k)=>decode(v) for (k,v) in pairs(x))
decode(x::Tuple)=map(decode,x)
decode(x::AbstractArray)=map(decode,x)
decode(x::AbstractSet)=map(decode,collect(x))
decode(x)=x

"Count actual strings reachable in state; metadata/registry is audited separately."
function audit(x,seen=IdDict{Any,Bool}())
    x isa AbstractString && return 1
    (x isa NID || x isa Number || x isa Symbol || x===nothing || x isa Function || x isa Type) && return 0
    if ismutabletype(typeof(x))
        haskey(seen,x) && return 0
        seen[x]=true
    end
    x isa AbstractDict && return sum((audit(k,seen)+audit(v,seen) for (k,v) in x);init=0)
    x isa Union{AbstractArray,Tuple,NamedTuple,AbstractSet} && return sum((audit(v,seen) for v in x);init=0)
    sum((audit(getfield(x,i),seen) for i in 1:fieldcount(typeof(x)));init=0)
end
end

