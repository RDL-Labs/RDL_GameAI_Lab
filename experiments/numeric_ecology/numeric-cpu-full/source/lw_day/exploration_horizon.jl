# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
horizon_state(actor) = begin
        #= none:2 =#
        D(NID(0x0000000000000259) => actor, NID(0x00000000000001e8) => 0, NID(0x000000000000013e) => 2, NID(0x00000000000003fc) => 0, NID(0x00000000000005ee) => nothing, NID(0x000000000000012f) => Any[], NID(0x0000000000000300) => 0)
    end
function horizon_result!(s, actor, op, phase, status, acquired; linked = true)
    #= none:3 =#
    #= none:4 =#
    actor == s[NID(0x0000000000000259)] || error(NID(0x00000000000005ef))
    #= none:5 =#
    (!linked || op == s[NID(0x00000000000005ee)]) && return false
    #= none:6 =#
    s[NID(0x00000000000005ee)] = op
    #= none:6 =#
    before = s[NID(0x00000000000001e8)]
    #= none:6 =#
    reason = nothing
    #= none:7 =#
    if acquired
        #= none:8 =#
        s[NID(0x00000000000001e8)] = 0
        #= none:8 =#
        s[NID(0x00000000000003fc)] = 0
        #= none:8 =#
        reason = NID(0x00000000000002e0)
    elseif #= none:9 =# phase == NID(0x00000000000002d2) && status in (NID(0x00000000000001b8), NID(0x0000000000000331), NID(0x000000000000032f), NID(0x000000000000036a))
        #= none:10 =#
        s[NID(0x00000000000003fc)] += 1
        #= none:11 =#
        if s[NID(0x00000000000003fc)] == 8
            #= none:12 =#
            s[NID(0x00000000000001e8)] = min(32, before + 1)
            #= none:12 =#
            s[NID(0x00000000000003fc)] = 0
            #= none:13 =#
            reason = NID(0x00000000000005f0)
        end
    end
    #= none:16 =#
    if reason !== nothing
        #= none:17 =#
        push!(s[NID(0x000000000000012f)], D(NID(0x0000000000000121) => op, NID(0x000000000000045d) => before, NID(0x0000000000000445) => s[NID(0x00000000000001e8)], NID(0x0000000000000442) => if acquired
                        0
                    else
                        1
                    end, NID(0x0000000000000364) => reason))
        #= none:18 =#
        length(s[NID(0x000000000000012f)]) > 16 && popfirst!(s[NID(0x000000000000012f)])
    end
    #= none:20 =#
    true
end
function horizon_candidates(s, fan, move)
    #= none:22 =#
    #= none:23 =#
    s[NID(0x00000000000001e8)] >= s[NID(0x000000000000013e)] || return Any[]
    #= none:24 =#
    safe = [Int(ANGLES[i]) for i = 1:5 if (((move[NID(0x000000000000030b)])[NID(0x000000000000030c)])[i])[NID(0x000000000000030a)] !== nothing]
    #= none:25 =#
    out = Dict{Int, Any}()
    #= none:25 =#
    pressure = min(4.0, s[NID(0x00000000000001e8)] / s[NID(0x000000000000013e)])
    #= none:26 =#
    for (i, f) = enumerate(fan[NID(0x000000000000033f)])
        #= none:27 =#
        f[NID(0x000000000000039d)] in (NID(0x000000000000039e), NID(0x000000000000039f)) || continue
        #= none:28 =#
        (lo, hi) = f[NID(0x000000000000039c)]
        #= none:28 =#
        hi - lo <= 45 && !(isempty(safe)) || continue
        #= none:29 =#
        center = (lo + hi) / 2
        #= none:29 =#
        angle = safe[argmin(abs.(safe .- center))]
        #= none:30 =#
        abs(angle - center) <= 22.5 || continue
        #= none:31 =#
        score = 2 + pressure * if f[NID(0x000000000000039d)] == NID(0x000000000000039f)
                        1.0
                    else
                        0.35
                    end
        #= none:32 =#
        if !(haskey(out, angle)) || score > (out[angle])[NID(0x00000000000002fc)]
            #= none:33 =#
            out[angle] = D(NID(0x00000000000001b7) => ncat(NID(0x0000000000000333), angle), NID(0x000000000000021f) => NID(0x000000000000030d), NID(0x0000000000000251) => findfirst((==)(angle), ANGLES) - 1, NID(0x00000000000002fc) => score, NID(0x00000000000001b4) => NID(0x00000000000002db), NID(0x00000000000005f1) => fan[NID(0x0000000000000121)], NID(0x00000000000005f2) => i)
        end
        #= none:36 =#
    end
    #= none:37 =#
    [out[a] for a = sort(collect(keys(out)))]
end
