# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
using JSON3
include(joinpath(#= none:2 =# @__DIR__(), "../julia/src/RDLMigrationProbe.jl"))
using .RDLMigrationProbe
const RS = 64000000 / 17280000000
const SS = 1 / 60
const ANGLES = (-90, -45, 0, 45, 90)
struct Body
    #= none:9 =#
    burst::Float64
    #= none:10 =#
    strain::Float64
    #= none:11 =#
    reserve::Float64
    #= none:12 =#
    damage::Float64
end
#= none:14 =# Core.@doc("Immutable four-component body change; dictionary-compatible at record boundaries.", struct BodyDelta <: AbstractDict{NID, Float64}
        #= none:16 =#
        burst::Float64
        #= none:17 =#
        strain::Float64
        #= none:18 =#
        reserve::Float64
        #= none:19 =#
        damage::Float64
    end)
Base.length(::BodyDelta) = begin
        #= none:21 =#
        4
    end
Base.iterate(d::BodyDelta, i = 1) = begin
        #= none:22 =#
        if i > 4
            nothing
        else
            (fieldname(BodyDelta, i) |> NID => getfield(d, i), i + 1)
        end
    end
function Base.getindex(d::BodyDelta, k::NID)
    #= none:23 =#
    #= none:24 =#
    k == NID(0x0000000000000257) && return d.burst
    #= none:25 =#
    k == NID(0x00000000000001dc) && return d.strain
    #= none:26 =#
    k == NID(0x000000000000014e) && return d.reserve
    #= none:27 =#
    k == NID(0x000000000000022c) && return d.damage
    #= none:28 =#
    throw(KeyError(k))
end
Base.haskey(::BodyDelta, k) = begin
        #= none:30 =#
        k in (NID(0x0000000000000257), NID(0x00000000000001dc), NID(0x000000000000014e), NID(0x000000000000022c))
    end
Base.get(d::BodyDelta, k, default) = begin
        #= none:31 =#
        if haskey(d, k)
            d[k]
        else
            default
        end
    end
mutable struct Agent
    #= none:33 =#
    x::Float64
    #= none:34 =#
    z::Float64
    #= none:35 =#
    yaw::Float64
    #= none:36 =#
    inventory::Int
    #= none:37 =#
    body::Body
end
bodydict(b) = begin
        #= none:39 =#
        Dict(NID(0x00000000000000c6) => NID(0x000000000000053f), NID(0x0000000000000257) => b.burst, NID(0x00000000000001dc) => b.strain, NID(0x000000000000014e) => b.reserve, NID(0x000000000000022c) => b.damage)
    end
state(a) = begin
        #= none:41 =#
        Dict(NID(0x00000000000000d1) => a.x, NID(0x00000000000000e3) => a.z, NID(0x0000000000000095) => a.yaw, NID(0x0000000000000081) => a.inventory, NID(0x0000000000000080) => bodydict(a.body))
    end
function step(b::Body, action, load, resistance = 1.0, clear = true)
    #= none:44 =#
    #= none:45 =#
    effort = (1 + 0.1load) * resistance
    #= none:45 =#
    integrity = 1 - b.damage
    #= none:46 =#
    (burst, strain, reserve) = (b.burst, b.strain, b.reserve)
    #= none:47 =#
    distance = 0.0
    #= none:48 =#
    if action == NID(0x000000000000030f)
        #= none:49 =#
        if !(reserve >= 0.1 * effort * RS && (strain < 1 && integrity > 0))
            #= none:50 =#
            status = NID(0x0000000000000540)
        elseif #= none:51 =# !clear
            #= none:52 =#
            status = NID(0x000000000000036c)
            #= none:52 =#
            reserve = max(0, reserve - 0.05 * effort * RS)
        else
            #= none:54 =#
            status = NID(0x000000000000029b)
            #= none:54 =#
            distance = 0.5integrity
            #= none:55 =#
            reserve -= 0.1 * effort * RS
            #= none:55 =#
            strain = min(1, strain + 0.03 * effort * SS)
        end
    elseif #= none:57 =# action == NID(0x000000000000031c)
        #= none:58 =#
        if !(reserve >= 0.5 * effort * RS && (burst >= 3 * effort && (strain <= 0.8 && integrity > 0)))
            #= none:59 =#
            status = NID(0x0000000000000540)
        elseif #= none:60 =# !clear
            #= none:61 =#
            status = NID(0x000000000000036c)
            #= none:61 =#
            reserve = max(0, reserve - 0.05 * effort * RS)
        else
            #= none:63 =#
            status = NID(0x000000000000029b)
            #= none:63 =#
            distance = 1.5integrity
            #= none:64 =#
            burst -= 3 * effort
            #= none:64 =#
            reserve -= 0.5 * effort * RS
            #= none:64 =#
            strain = min(1, strain + 0.18 * effort * SS)
        end
    elseif #= none:66 =# action == NID(0x0000000000000317)
        #= none:67 =#
        if !(reserve >= 0.4 * effort * RS && (burst >= 4 * effort && (strain <= 0.8 && integrity > 0)))
            #= none:68 =#
            status = NID(0x0000000000000540)
        elseif #= none:69 =# !clear
            #= none:70 =#
            status = NID(0x000000000000036c)
            #= none:70 =#
            reserve = max(0, reserve - 0.05 * effort * RS)
        else
            #= none:72 =#
            status = NID(0x000000000000029b)
            #= none:72 =#
            distance = integrity
            #= none:73 =#
            burst -= 4 * effort
            #= none:73 =#
            reserve -= 0.4 * effort * RS
            #= none:73 =#
            strain = min(1, strain + 0.15 * effort * SS)
        end
    elseif #= none:75 =# action == NID(0x00000000000002f0)
        #= none:76 =#
        status = NID(0x0000000000000323)
        #= none:76 =#
        reserve = min(100, reserve + 20)
    elseif #= none:77 =# action == NID(0x00000000000002f2)
        #= none:78 =#
        status = NID(0x00000000000002de)
        #= none:78 =#
        recovery = min(1, b.reserve / 20) * (1 - b.damage)
        #= none:79 =#
        burst = min(10integrity, burst + 2recovery)
        #= none:80 =#
        strain = max(0, strain - 0.15 * recovery * SS)
        #= none:80 =#
        reserve = max(0, reserve - 0.05 * recovery * RS)
    else
        #= none:82 =#
        error(NID(0x000000000000021f))
    end
    #= none:84 =#
    out = Body(min(burst, 10integrity), strain, reserve, b.damage)
    #= none:85 =#
    #= none:85 =# @assert 0 <= out.reserve <= 100 && (0 <= out.strain <= 1 && 0 <= out.burst <= 10)
    #= none:86 =#
    delta = BodyDelta(out.burst - b.burst, out.strain - b.strain, out.reserve - b.reserve, out.damage - b.damage)
    #= none:88 =#
    (out, status, distance, delta)
end
function simulate(scene, trace = false)
    #= none:91 =#
    #= none:92 =#
    agents = [Agent(p[1], p[2], 0.0, 0, Body(10.0, 0.0, scene.reserve, 0.0)) for p = scene.agents]
    #= none:93 =#
    stock = Int[f.stock for f = scene.food]
    #= none:94 =#
    obstacles = [RDLMigrationProbe.Circle(o.x, o.z, o.radius) for o = scene.obstacles]
    #= none:95 =#
    rows = Any[]
    #= none:96 =#
    counts = Dict((k => 0 for k = (NID(0x000000000000030f), NID(0x00000000000002f2), NID(0x00000000000002f0), NID(0x00000000000002fc), NID(0x0000000000000541), NID(0x0000000000000542))))
    #= none:97 =#
    for tick = 0:scene.ticks - 1, (index, a) = enumerate(agents)
        #= none:98 =#
        origin = (a.x, a.z)
        #= none:98 =#
        yaw = deg2rad(a.yaw)
        #= none:98 =#
        (s, c) = (sin(yaw), cos(yaw))
        #= none:99 =#
        visible = NamedTuple{(:ref, :forward, :right, :distance), Tuple{Int, Float64, Float64, Float64}}[]
        #= none:100 =#
        for (j, f) = enumerate(scene.food)
            #= none:101 =#
            (dx, dz) = (f.x - a.x, f.z - a.z)
            #= none:102 =#
            (forward, right) = (dx * s + dz * c, dx * c - dz * s)
            #= none:102 =#
            distance = hypot(forward, right)
            #= none:103 =#
            if stock[j] > 0 && (distance <= 12 && (forward >= 0 && !(any((o->begin
                                            #= none:103 =#
                                            segment_hit(origin, (Float64(f.x), Float64(f.z)), o, 0.0)
                                        end), obstacles))))
                #= none:104 =#
                push!(visible, (ref = j - 1, forward = forward, right = right, distance = distance))
            end
            #= none:106 =#
        end
        #= none:107 =#
        sort!(visible, by = (v->begin
                        #= none:107 =#
                        (v.distance, v.ref)
                    end))
        #= none:107 =#
        resize!(visible, min(5, length(visible)))
        #= none:108 =#
        target = if isempty(visible)
                nothing
            else
                visible[1]
            end
        #= none:109 =#
        candidates = Any[]
        #= none:109 =#
        chosen = -1
        #= none:109 =#
        best = Inf
        #= none:110 =#
        for (j, angle) = enumerate(ANGLES)
            #= none:111 =#
            theta = deg2rad(a.yaw + angle)
            #= none:111 =#
            endpoint = (a.x + sin(theta), a.z + cos(theta))
            #= none:112 =#
            clear = !(any((o->begin
                                #= none:112 =#
                                segment_hit(origin, endpoint, o, 0.2)
                            end), obstacles))
            #= none:113 =#
            goal = if target === nothing
                    1.0 + abs(angle) / 90
                else
                    min(10.0, hypot(target.forward - cos(deg2rad(Float64(angle))), target.right - sin(deg2rad(Float64(angle)))))
                end
            #= none:114 =#
            (_, status, _, delta) = step(a.body, NID(0x000000000000030f), a.inventory, scene.resistance, clear)
            #= none:115 =#
            cost = if status == NID(0x000000000000029b)
                    ((goal - delta[NID(0x000000000000014e)] / max(a.body.reserve, 0.001)) - delta[NID(0x0000000000000257)] / max(a.body.burst, 0.001)) + delta[NID(0x00000000000001dc)]
                else
                    nothing
                end
            #= none:116 =#
            counts[NID(0x0000000000000541)] += status == NID(0x000000000000036c)
            #= none:117 =#
            counts[NID(0x0000000000000542)] += status == NID(0x0000000000000540)
            #= none:118 =#
            if cost !== nothing && cost < best
                #= none:119 =#
                best = cost
                #= none:119 =#
                chosen = j - 1
            end
            #= none:121 =#
            if trace
                #= none:122 =#
                push!(candidates, Dict(NID(0x0000000000000195) => ncat(j - 1), NID(0x000000000000021f) => NID(0x000000000000030f), NID(0x000000000000022e) => clear, NID(0x0000000000000231) => scene.resistance, NID(0x00000000000004cd) => goal, NID(0x000000000000008a) => status, NID(0x000000000000030c) => cost, NID(0x0000000000000319) => delta))
            end
            #= none:126 =#
        end
        #= none:127 =#
        if a.inventory > 0 && a.body.reserve < 80
            #= none:128 =#
            action = NID(0x00000000000002f0)
            #= none:128 =#
            (a.body, status, _, _) = step(a.body, action, a.inventory)
            #= none:128 =#
            a.inventory -= 1
            #= none:128 =#
            chosen = -1
        elseif #= none:129 =# target !== nothing && target.distance <= 1.25
            #= none:130 =#
            action = NID(0x00000000000002fc)
            #= none:130 =#
            status = NID(0x00000000000002e3)
            #= none:130 =#
            stock[target.ref + 1] -= 1
            #= none:130 =#
            a.inventory += 1
            #= none:130 =#
            chosen = -1
        elseif #= none:131 =# chosen < 0
            #= none:132 =#
            action = NID(0x00000000000002f2)
            #= none:132 =#
            (a.body, status, _, _) = step(a.body, action, a.inventory)
        else
            #= none:134 =#
            action = NID(0x000000000000030f)
            #= none:134 =#
            a.yaw = mod(a.yaw + ANGLES[chosen + 1] + 180, 360) - 180
            #= none:135 =#
            (a.body, status, distance, _) = step(a.body, action, a.inventory, scene.resistance)
            #= none:136 =#
            theta = deg2rad(a.yaw)
            #= none:136 =#
            a.x += sin(theta) * distance
            #= none:136 =#
            a.z += cos(theta) * distance
        end
        #= none:138 =#
        counts[action] += 1
        #= none:139 =#
        trace && push!(rows, Dict(NID(0x00000000000004c0) => tick, NID(0x00000000000003b0) => index - 1, NID(0x00000000000001dd) => visible, NID(0x00000000000001e2) => candidates, NID(0x000000000000021f) => action, NID(0x00000000000004b1) => chosen, NID(0x000000000000008a) => status, NID(0x00000000000001ce) => state(a), NID(0x0000000000000082) => copy(stock)))
        #= none:142 =#
    end
    #= none:143 =#
    #= none:143 =# @assert sum(stock) + sum((a.inventory for a = agents)) + counts[NID(0x00000000000002f0)] == sum((f.stock for f = scene.food))
    #= none:144 =#
    Dict(NID(0x000000000000007c) => state.(agents), NID(0x0000000000000082) => stock, NID(0x0000000000000086) => counts, NID(0x00000000000001ca) => rows)
end
function main()
    #= none:147 =#
    #= none:148 =#
    (mode, input, output) = ARGS
    #= none:149 =#
    scenes = JSON3.read(read(input, NID))
    #= none:149 =#
    results = Dict{NID, Any}()
    #= none:150 =#
    for scene = scenes
        #= none:151 =#
        if mode == NID(0x00000000000001ca)
            #= none:152 =#
            results[scene.name] = simulate(scene, true)
        else
            #= none:154 =#
            simulate(scene)
            #= none:155 =#
            times = Float64[]
            #= none:155 =#
            result = nothing
            #= none:156 =#
            for _ = 1:3
                #= none:157 =#
                start = time_ns()
                #= none:157 =#
                result = simulate(scene)
                #= none:157 =#
                push!(times, (time_ns() - start) / 1.0e9)
                #= none:158 =#
            end
            #= none:159 =#
            results[scene.name] = Dict(NID(0x000000000000016b) => times, NID(0x0000000000000086) => result[NID(0x0000000000000086)])
        end
        #= none:161 =#
    end
    #= none:162 =#
    open(output, NID(0x0000000000000092)) do io
        #= none:163 =#
        JSON3.write(io, results)
    end
end
nothing
