module RDLMigrationProbe
export Query, prepare, ray_hit, segment_hit, batch, nearest

struct Circle
    x::Float64
    z::Float64
    radius::Float64
end
struct Query
    ray::Bool
    start::NTuple{2,Float64}
    vector::NTuple{2,Float64}
    circle::Circle
    margin::Float64
end

function prepare(row)
    row.kind in ("ray", "segment") || throw(ArgumentError("kind"))
    length(row.start)==2 && length(row.vector)==2 && length(row.circle)==3 || throw(ArgumentError("shape"))
    # A tuple preserves input types: concatenating numeric arrays promotes Bool.
    values = (row.start..., row.vector..., row.circle..., row.margin)
    all(x -> x isa Real && !(x isa Bool) && isfinite(x) && abs(x)<=10000, values) || throw(ArgumentError("domain"))
    row.circle[3]>=0 && row.margin>=0 || throw(ArgumentError("negative"))
    row.kind=="ray" && abs(hypot(row.vector...)-1)>1e-12 && throw(ArgumentError("direction"))
    Query(row.kind=="ray", Tuple(Float64.(row.start)), Tuple(Float64.(row.vector)), Circle(Float64.(row.circle)...), Float64(row.margin))
end

function segment_hit(start, endpoint, obj::Circle, margin)
    dx, dz = endpoint[1]-start[1], endpoint[2]-start[2]
    len = dx*dx+dz*dz
    t = len != 0 ? max(0, min(1, ((obj.x-start[1])*dx+(obj.z-start[2])*dz)/len)) : 0
    hypot(start[1]+t*dx-obj.x, start[2]+t*dz-obj.z) <= obj.radius+margin
end

function ray_hit(start, direction, obj::Circle)
    dx, dz = obj.x-start[1], obj.z-start[2]
    along = dx*direction[1]+dz*direction[2]
    disc = obj.radius^2-(dx*dx+dz*dz-along*along)
    disc < 0 && return nothing
    far = along+sqrt(disc)
    far >= 0 ? max(0, along-sqrt(disc)) : nothing
end

function batch(queries)
    result = Vector{Union{Nothing,Bool,Float64}}(undef, length(queries))
    for i in eachindex(queries)
        q = queries[i]
        result[i] = q.ray ? ray_hit(q.start,q.vector,q.circle) : segment_hit(q.start,q.vector,q.circle,q.margin)
    end
    result
end

function nearest(values)
    best = nothing
    distance = Inf
    for i in eachindex(values)
        v = values[i]
        if v !== nothing && (best === nothing || v < distance)
            best, distance = i-1, v # zero-based external index; preserve first tie
        end
    end
    best
end
end
