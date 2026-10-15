# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
module RDLMigrationProbe
using Main.NumericCore
#= none:1 =#
#= none:2 =#
export Query, prepare, ray_hit, segment_hit, batch, nearest
#= none:4 =#
struct Circle
    #= none:5 =#
    x::Float64
    #= none:6 =#
    z::Float64
    #= none:7 =#
    radius::Float64
end
#= none:9 =#
struct Query
    #= none:10 =#
    ray::Bool
    #= none:11 =#
    start::NTuple{2, Float64}
    #= none:12 =#
    vector::NTuple{2, Float64}
    #= none:13 =#
    circle::Circle
    #= none:14 =#
    margin::Float64
end
#= none:17 =#
function prepare(row)
    #= none:17 =#
    #= none:18 =#
    row.kind in (NID(0x0000000000000545), NID(0x0000000000000551)) || throw(ArgumentError(NID(0x000000000000024d)))
    #= none:19 =#
    length(row.start) == 2 && (length(row.vector) == 2 && length(row.circle) == 3) || throw(ArgumentError(NID(0x00000000000003ea)))
    #= none:21 =#
    values = (row.start..., row.vector..., row.circle..., row.margin)
    #= none:22 =#
    all((x->begin
                    #= none:22 =#
                    x isa Real && (!(x isa Bool) && (isfinite(x) && abs(x) <= 10000))
                end), values) || throw(ArgumentError(NID(0x0000000000000552)))
    #= none:23 =#
    row.circle[3] >= 0 && row.margin >= 0 || throw(ArgumentError(NID(0x0000000000000553)))
    #= none:24 =#
    row.kind == NID(0x0000000000000545) && (abs(hypot(row.vector...) - 1) > 1.0e-12 && throw(ArgumentError(NID(0x0000000000000251))))
    #= none:25 =#
    Query(row.kind == NID(0x0000000000000545), Tuple(Float64.(row.start)), Tuple(Float64.(row.vector)), Circle(Float64.(row.circle)...), Float64(row.margin))
end
#= none:28 =#
function segment_hit(start, endpoint, obj::Circle, margin)
    #= none:28 =#
    #= none:29 =#
    (dx, dz) = (endpoint[1] - start[1], endpoint[2] - start[2])
    #= none:30 =#
    len = dx * dx + dz * dz
    #= none:31 =#
    t = if len != 0
            max(0, min(1, ((obj.x - start[1]) * dx + (obj.z - start[2]) * dz) / len))
        else
            0
        end
    #= none:32 =#
    hypot((start[1] + t * dx) - obj.x, (start[2] + t * dz) - obj.z) <= obj.radius + margin
end
#= none:35 =#
function ray_hit(start, direction, obj::Circle)
    #= none:35 =#
    #= none:36 =#
    (dx, dz) = (obj.x - start[1], obj.z - start[2])
    #= none:37 =#
    along = dx * direction[1] + dz * direction[2]
    #= none:38 =#
    disc = obj.radius ^ 2 - ((dx * dx + dz * dz) - along * along)
    #= none:39 =#
    disc < 0 && return nothing
    #= none:40 =#
    far = along + sqrt(disc)
    #= none:41 =#
    if far >= 0
        max(0, along - sqrt(disc))
    else
        nothing
    end
end
#= none:44 =#
function batch(queries)
    #= none:44 =#
    #= none:45 =#
    result = Vector{Union{Nothing, Bool, Float64}}(undef, length(queries))
    #= none:46 =#
    for i = eachindex(queries)
        #= none:47 =#
        q = queries[i]
        #= none:48 =#
        result[i] = if q.ray
                ray_hit(q.start, q.vector, q.circle)
            else
                segment_hit(q.start, q.vector, q.circle, q.margin)
            end
        #= none:49 =#
    end
    #= none:50 =#
    result
end
#= none:53 =#
function nearest(values)
    #= none:53 =#
    #= none:54 =#
    best = nothing
    #= none:55 =#
    distance = Inf
    #= none:56 =#
    for i = eachindex(values)
        #= none:57 =#
        v = values[i]
        #= none:58 =#
        if v !== nothing && (best === nothing || v < distance)
            #= none:59 =#
            (best, distance) = (i - 1, v)
        end
        #= none:61 =#
    end
    #= none:62 =#
    best
end
end
