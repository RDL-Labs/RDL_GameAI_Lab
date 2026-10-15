# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function maintenance!(s)
    #= none:2 =#
    #= none:3 =#
    get!(s, NID(0x00000000000004aa), D(NID(0x0000000000000470) => D(), NID(0x0000000000000010) => Int[], NID(0x0000000000000330) => Any[], NID(0x0000000000000472) => 0, NID(0x0000000000000490) => nothing))
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
    for id = sort(collect(keys(s[NID(0x000000000000028a)])))
        #= none:9 =#
        u = (m[NID(0x0000000000000470)])[id]
        #= none:10 =#
        u[NID(0x000000000000047b)] >= formation && continue
        #= none:11 =#
        u[NID(0x000000000000046b)] && continue
        #= none:12 =#
        u[NID(0x0000000000000373)] = if u[NID(0x000000000000047c)] > 0
                0
            else
                u[NID(0x0000000000000373)] + 1
            end
        #= none:13 =#
        u[NID(0x000000000000046b)] = u[NID(0x000000000000047c)] == 0 && u[NID(0x0000000000000373)] >= if u[NID(0x000000000000047d)] > 0
                        2
                    else
                        3
                    end
        #= none:14 =#
        push!(decisions, D(NID(0x0000000000000121) => id, NID(0x000000000000047c) => u[NID(0x000000000000047c)], NID(0x000000000000047d) => u[NID(0x000000000000047d)], NID(0x0000000000000373) => u[NID(0x0000000000000373)], NID(0x000000000000046b) => u[NID(0x000000000000046b)]))
        #= none:15 =#
        u[NID(0x000000000000047c)] = 0
        #= none:15 =#
        u[NID(0x000000000000047d)] = 0
        #= none:16 =#
    end
    #= none:17 =#
    push!(m[NID(0x0000000000000010)], day)
    #= none:17 =#
    push!(m[NID(0x0000000000000330)], D(NID(0x0000000000000173) => day, NID(0x0000000000000283) => decisions))
end
function enroll_sleep_usage!(s, now)
    #= none:19 =#
    #= none:20 =#
    m = maintenance!(s)
    #= none:21 =#
    for id = sort(collect(keys(s[NID(0x000000000000028a)])))
        #= none:22 =#
        haskey(m[NID(0x0000000000000470)], id) && continue
        #= none:23 =#
        active = count((u->begin
                        #= none:23 =#
                        !(u[NID(0x000000000000046b)])
                    end), values(m[NID(0x0000000000000470)]))
        #= none:24 =#
        (m[NID(0x0000000000000470)])[id] = D(NID(0x000000000000047b) => now, NID(0x000000000000047c) => 0, NID(0x000000000000047d) => 0, NID(0x0000000000000373) => 0, NID(0x000000000000046b) => active >= 32)
        #= none:25 =#
    end
end
function wake_sleep_usage!(s, context, phase)
    #= none:27 =#
    #= none:28 =#
    context === nothing && return
    #= none:29 =#
    phase in (NID(0x00000000000002d4), NID(0x00000000000002d5)) || return
    #= none:30 =#
    m = maintenance!(s)
    #= none:31 =#
    for id = sort(collect(keys(m[NID(0x0000000000000470)])))
        #= none:32 =#
        u = (m[NID(0x0000000000000470)])[id]
        #= none:32 =#
        r = (s[NID(0x000000000000028a)])[id]
        #= none:33 =#
        u[NID(0x000000000000046b)] && (get(r, NID(0x0000000000000250), nothing) == context && r[NID(0x0000000000000116)] == phase) || continue
        #= none:34 =#
        count((x->begin
                            #= none:34 =#
                            !(x[NID(0x000000000000046b)])
                        end), values(m[NID(0x0000000000000470)])) < 32 || break
        #= none:35 =#
        u[NID(0x000000000000046b)] = false
        #= none:35 =#
        u[NID(0x0000000000000373)] = 0
        #= none:35 =#
        m[NID(0x0000000000000472)] += 1
        #= none:36 =#
    end
end
function record_sleep_use!(s, plan, op, status)
    #= none:38 =#
    #= none:39 =#
    haskey(s, NID(0x00000000000004aa)) || return
    #= none:40 =#
    m = s[NID(0x00000000000004aa)]
    #= none:40 =#
    m[NID(0x0000000000000490)] == op && return
    #= none:41 =#
    m[NID(0x0000000000000490)] = op
    #= none:42 =#
    get(plan, NID(0x0000000000000306), false) && status in (NID(0x000000000000029b), NID(0x000000000000036c)) || return
    #= none:43 =#
    for id = get(plan, NID(0x00000000000004ab), NID[])
        #= none:44 =#
        ((m[NID(0x0000000000000470)])[id])[NID(0x000000000000047c)] += 1
        #= none:45 =#
    end
end
