# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
general_sleep_state() = begin
        #= none:2 =#
        D(NID(0x00000000000000c1) => Any[], NID(0x0000000000000243) => Any[], NID(0x0000000000000497) => 0, NID(0x0000000000000498) => Any[], NID(0x000000000000032d) => nothing, NID(0x000000000000032e) => Any[])
    end
function freeze_general!(s, owner, now; retained = false)
    #= none:3 =#
    #= none:4 =#
    selected = Any[]
    #= none:4 =#
    seen = Set{Tuple{NID, NID}}()
    #= none:5 =#
    for r = reverse(if retained
                    s[NID(0x0000000000000243)]
                else
                    s[NID(0x00000000000000c1)]
                end)
        #= none:6 =#
        check(r[NID(0x0000000000000259)] == owner && r[NID(0x000000000000025a)] <= now, NID(0x0000000000000499))
        #= none:7 =#
        key = (r[NID(0x000000000000021f)], r[NID(0x0000000000000334)])
        #= none:7 =#
        key in seen && continue
        #= none:8 =#
        push!(seen, key)
        #= none:8 =#
        push!(selected, deepcopy(r))
        #= none:8 =#
        length(selected) == 6 && break
        #= none:9 =#
    end
    #= none:10 =#
    s[NID(0x0000000000000498)] = selected
    #= none:10 =#
    s[NID(0x000000000000032d)] = now
end
function review_general!(s, owner, day, executed)
    #= none:12 =#
    #= none:13 =#
    any((r->begin
                    #= none:13 =#
                    r[NID(0x0000000000000173)] == day
                end), s[NID(0x000000000000032e)]) && return
    #= none:14 =#
    records = s[NID(0x0000000000000498)]
    #= none:14 =#
    pairs = Any[]
    #= none:15 =#
    for r = records
        #= none:16 =#
        check(r[NID(0x0000000000000259)] == owner && r[NID(0x000000000000025a)] <= s[NID(0x000000000000032d)] <= executed, NID(0x000000000000049a))
        #= none:17 =#
    end
    #= none:18 =#
    for i = 1:length(records), j = i + 1:length(records)
        #= none:19 =#
        (a, b) = (records[i], records[j])
        #= none:19 =#
        matched = NID[]
        #= none:19 =#
        different = NID[]
        #= none:19 =#
        missing = NID[]
        #= none:20 =#
        for key = (NID(0x0000000000000259), NID(0x000000000000021f), NID(0x0000000000000334), NID(0x00000000000001b0), NID(0x0000000000000250))
            #= none:21 =#
            if get(a, key, nothing) === nothing || get(b, key, nothing) === nothing
                #= none:22 =#
                push!(missing, key)
            elseif #= none:23 =# a[key] == b[key]
                #= none:24 =#
                push!(matched, key)
            else
                #= none:26 =#
                push!(different, key)
            end
            #= none:28 =#
        end
        #= none:29 =#
        push!(pairs, D(NID(0x0000000000000412) => [a[NID(0x0000000000000237)], b[NID(0x0000000000000237)]], NID(0x0000000000000471) => matched, NID(0x0000000000000495) => different, NID(0x0000000000000496) => missing))
        #= none:30 =#
    end
    #= none:31 =#
    push!(s[NID(0x000000000000032e)], D(NID(0x0000000000000173) => day, NID(0x000000000000032d) => s[NID(0x000000000000032d)], NID(0x000000000000049b) => executed, NID(0x0000000000000288) => deepcopy(records), NID(0x00000000000000ec) => pairs, NID(0x000000000000008a) => if isempty(pairs)
                    NID(0x000000000000049c)
                else
                    NID(0x000000000000049d)
                end, NID(0x00000000000003f5) => NID(0x000000000000049e)))
end
function remember_general!(s, owner, op, action, status, target, phase, executed; context = nothing, direction = nothing, retain = false)
    #= none:35 =#
    #= none:36 =#
    push!(s[NID(0x00000000000000c1)], D(NID(0x0000000000000259) => owner, NID(0x0000000000000237) => op, NID(0x000000000000021f) => action, NID(0x0000000000000334) => status, NID(0x0000000000000250) => deepcopy(context), NID(0x0000000000000251) => direction, NID(0x00000000000001b0) => target, NID(0x0000000000000116) => phase, NID(0x000000000000025a) => executed))
    #= none:38 =#
    length(s[NID(0x00000000000000c1)]) > 64 && popfirst!(s[NID(0x00000000000000c1)])
    #= none:39 =#
    if retain
        #= none:40 =#
        key(r) = begin
                #= none:40 =#
                (r[NID(0x000000000000021f)], r[NID(0x0000000000000334)])
            end
        #= none:41 =#
        current = last(s[NID(0x00000000000000c1)])
        #= none:42 =#
        filter!((r->begin
                    #= none:42 =#
                    key(r) != key(current)
                end), s[NID(0x0000000000000243)])
        #= none:43 =#
        push!(s[NID(0x0000000000000243)], deepcopy(current))
        #= none:44 =#
        if length(s[NID(0x0000000000000243)]) > 32
            #= none:45 =#
            popfirst!(s[NID(0x0000000000000243)])
            #= none:45 =#
            s[NID(0x0000000000000497)] += 1
        end
    end
end
