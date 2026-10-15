# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function maintenance!(s)
    #= none:2 =#
    #= none:3 =#
    get!(s, NID(0x00000000000004a8), D(NID(0x000000000000046e) => D(), NID(0x0000000000000010) => Int[], NID(0x000000000000032e) => Any[], NID(0x0000000000000470) => 0, NID(0x000000000000048e) => nothing))
end
function review_sleep_usage!(s, day, formation)
    #= none:5 =#
    #= none:6 =#
    m = maintenance!(s)
    #= none:6 =#
    day in m[NID(0x0000000000000010)] && return
    #= none:7 =#
    decisions = Any[]
    #= none:8 =#
    for id = sort(collect(keys(s[NID(0x0000000000000288)])))
        #= none:9 =#
        u = (m[NID(0x000000000000046e)])[id]
        #= none:10 =#
        u[NID(0x0000000000000479)] >= formation && continue
        #= none:11 =#
        u[NID(0x0000000000000469)] && continue
        #= none:12 =#
        u[NID(0x0000000000000371)] = if u[NID(0x000000000000047a)] > 0
                0
            else
                u[NID(0x0000000000000371)] + 1
            end
        #= none:13 =#
        u[NID(0x0000000000000469)] = u[NID(0x000000000000047a)] == 0 && u[NID(0x0000000000000371)] >= if u[NID(0x000000000000047b)] > 0
                        2
                    else
                        3
                    end
        #= none:14 =#
        push!(decisions, D(NID(0x0000000000000121) => id, NID(0x000000000000047a) => u[NID(0x000000000000047a)], NID(0x000000000000047b) => u[NID(0x000000000000047b)], NID(0x0000000000000371) => u[NID(0x0000000000000371)], NID(0x0000000000000469) => u[NID(0x0000000000000469)]))
        #= none:15 =#
        u[NID(0x000000000000047a)] = 0
        #= none:15 =#
        u[NID(0x000000000000047b)] = 0
        #= none:16 =#
    end
    #= none:17 =#
    push!(m[NID(0x0000000000000010)], day)
    #= none:17 =#
    push!(m[NID(0x000000000000032e)], D(NID(0x0000000000000173) => day, NID(0x0000000000000281) => decisions))
end
function enroll_sleep_usage!(s, now)
    #= none:19 =#
    #= none:20 =#
    m = maintenance!(s)
    #= none:21 =#
    for id = sort(collect(keys(s[NID(0x0000000000000288)])))
        #= none:22 =#
        haskey(m[NID(0x000000000000046e)], id) && continue
        #= none:23 =#
        active = count((u->begin
                        #= none:23 =#
                        !(u[NID(0x0000000000000469)])
                    end), values(m[NID(0x000000000000046e)]))
        #= none:24 =#
        (m[NID(0x000000000000046e)])[id] = D(NID(0x0000000000000479) => now, NID(0x000000000000047a) => 0, NID(0x000000000000047b) => 0, NID(0x0000000000000371) => 0, NID(0x0000000000000469) => active >= 32)
        #= none:25 =#
    end
end
function wake_sleep_usage!(s, context, phase)
    #= none:27 =#
    #= none:28 =#
    context === nothing && return
    #= none:29 =#
    phase in (NID(0x00000000000002d2), NID(0x00000000000002d3)) || return
    #= none:30 =#
    m = maintenance!(s)
    #= none:31 =#
    for id = sort(collect(keys(m[NID(0x000000000000046e)])))
        #= none:32 =#
        u = (m[NID(0x000000000000046e)])[id]
        #= none:32 =#
        r = (s[NID(0x0000000000000288)])[id]
        #= none:33 =#
        u[NID(0x0000000000000469)] && (get(r, NID(0x0000000000000250), nothing) == context && r[NID(0x0000000000000116)] == phase) || continue
        #= none:34 =#
        count((x->begin
                            #= none:34 =#
                            !(x[NID(0x0000000000000469)])
                        end), values(m[NID(0x000000000000046e)])) < 32 || break
        #= none:35 =#
        u[NID(0x0000000000000469)] = false
        #= none:35 =#
        u[NID(0x0000000000000371)] = 0
        #= none:35 =#
        m[NID(0x0000000000000470)] += 1
        #= none:36 =#
    end
end
function record_sleep_use!(s, plan, op, status)
    #= none:38 =#
    #= none:39 =#
    haskey(s, NID(0x00000000000004a8)) || return
    #= none:40 =#
    m = s[NID(0x00000000000004a8)]
    #= none:40 =#
    m[NID(0x000000000000048e)] == op && return
    #= none:41 =#
    m[NID(0x000000000000048e)] = op
    #= none:42 =#
    get(plan, NID(0x0000000000000304), false) && status in (NID(0x0000000000000299), NID(0x000000000000036a)) || return
    #= none:43 =#
    for id = get(plan, NID(0x00000000000004a9), NID[])
        #= none:44 =#
        ((m[NID(0x000000000000046e)])[id])[NID(0x000000000000047a)] += 1
        #= none:45 =#
    end
end
