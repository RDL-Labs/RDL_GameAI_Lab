# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
orientation_state(owner) = begin
        #= none:2 =#
        D(NID(0x0000000000000351) => owner, NID(0x00000000000000c1) => Any[], NID(0x0000000000000357) => 0, NID(0x0000000000000300) => 0, NID(0x0000000000000280) => 0, NID(0x000000000000027a) => 0, NID(0x000000000000024a) => nothing)
    end
function sky_sample(owner, source, now, yaw, clock; available = true)
    #= none:3 =#
    #= none:4 =#
    check(isfinite(yaw), NID(0x0000000000000358))
    #= none:5 =#
    center = mod(floor(Int, (-yaw + 15) / 30) * 30 + 180, 360) - 180
    #= none:6 =#
    D(NID(0x0000000000000259) => owner, NID(0x0000000000000121) => source, NID(0x00000000000002cc) => now, NID(0x0000000000000359) => NID(0x000000000000035a), NID(0x000000000000008a) => if available
                NID(0x0000000000000352)
            else
                NID(0x0000000000000325)
            end, NID(0x000000000000035b) => if available
                center
            else
                nothing
            end, NID(0x000000000000035c) => 15, NID(0x0000000000000354) => if mod(now, clock.day_us) >= clock.phase_boundaries_us[3]
                NID(0x000000000000035d)
            else
                NID(0x000000000000035e)
            end, NID(0x000000000000026a) => NID(0x000000000000035f))
end
function observe_sky!(s, cue)
    #= none:11 =#
    #= none:12 =#
    check(cue[NID(0x0000000000000259)] == s[NID(0x0000000000000351)], NID(0x0000000000000360))
    #= none:13 =#
    h = s[NID(0x00000000000000c1)]
    #= none:14 =#
    if !(isempty(h))
        #= none:15 =#
        check(cue[NID(0x00000000000002cc)] >= (last(h))[NID(0x00000000000002cc)], NID(0x0000000000000361))
        #= none:16 =#
        if cue[NID(0x00000000000002cc)] == (last(h))[NID(0x00000000000002cc)]
            #= none:17 =#
            check(cue == last(h), NID(0x0000000000000362))
            #= none:17 =#
            return
        end
    end
    #= none:20 =#
    push!(h, copy(cue))
    #= none:20 =#
    length(h) > 257 && popfirst!(h)
    #= none:21 =#
    s[NID(0x0000000000000357)] += 1
end
function orientation_scan!(s, clock)
    #= none:23 =#
    #= none:24 =#
    h = s[NID(0x00000000000000c1)]
    #= none:24 =#
    isempty(h) && return 90
    #= none:25 =#
    cue = last(h)
    #= none:25 =#
    cue[NID(0x000000000000008a)] == NID(0x0000000000000352) || return 90
    #= none:26 =#
    counts = zeros(Int, 12)
    #= none:26 =#
    day = div(cue[NID(0x00000000000002cc)], clock.day_us)
    #= none:27 =#
    for r = h
        #= none:28 =#
        div(r[NID(0x00000000000002cc)], clock.day_us) == day && r[NID(0x000000000000008a)] == NID(0x0000000000000352) || continue
        #= none:29 =#
        counts[div(mod(-(r[NID(0x000000000000035b)]), 360), 30) + 1] += 1
        #= none:30 =#
    end
    #= none:31 =#
    heading = mod(-(cue[NID(0x000000000000035b)]), 360)
    #= none:32 =#
    left = counts[div(mod(heading - 90, 360), 30) + 1]
    #= none:32 =#
    right = counts[div(mod(heading + 90, 360), 30) + 1]
    #= none:33 =#
    angle = if left < right
            -90
        else
            90
        end
    #= none:34 =#
    s[NID(0x0000000000000300)] += 1
    #= none:34 =#
    s[if angle < 0
                NID(0x0000000000000280)
            else
                NID(0x000000000000027a)
            end] += 1
    #= none:35 =#
    s[NID(0x000000000000024a)] = D(NID(0x0000000000000121) => cue[NID(0x0000000000000121)], NID(0x0000000000000086) => counts, NID(0x0000000000000363) => angle, NID(0x0000000000000364) => NID(0x0000000000000365))
    #= none:36 =#
    angle
end
