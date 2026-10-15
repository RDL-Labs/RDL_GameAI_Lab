# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function review_harvest!(h, actor, op, prediction, before, status, executed, after; accepted = true, pose = true)
    #= none:2 =#
    #= none:3 =#
    check(accepted && actor == h[NID(0x0000000000000259)], NID(0x000000000000065b))
    #= none:4 =#
    prediction[NID(0x000000000000008a)] == NID(0x00000000000002d9) || return false
    #= none:5 =#
    check(h[NID(0x000000000000008d)] !== nothing && prediction[NID(0x000000000000008c)] == (h[NID(0x000000000000008d)])[NID(0x000000000000008c)], NID(0x000000000000065c))
    #= none:6 =#
    check(prediction[NID(0x0000000000000121)] == before[NID(0x0000000000000121)], NID(0x000000000000065d))
    #= none:7 =#
    check(before[NID(0x00000000000002ce)] < executed <= after[NID(0x00000000000002ce)], NID(0x000000000000065e))
    #= none:8 =#
    request = D(NID(0x0000000000000328) => op, NID(0x0000000000000191) => deepcopy(prediction), NID(0x0000000000000158) => deepcopy(before), NID(0x000000000000008a) => status, NID(0x000000000000018e) => executed, NID(0x0000000000000633) => deepcopy(after), NID(0x000000000000018c) => pose)
    #= none:10 =#
    last = get(h, NID(0x000000000000065f), nothing)
    #= none:11 =#
    if last !== nothing
        #= none:12 =#
        if last[NID(0x0000000000000328)] == op
            #= none:13 =#
            check(last == request, NID(0x0000000000000660))
            #= none:13 =#
            return false
        end
        #= none:15 =#
        check(executed > last[NID(0x000000000000018e)], NID(0x0000000000000661))
    end
    #= none:17 =#
    comparable = pose && (before[NID(0x000000000000034f)] && (after[NID(0x000000000000034f)] && status in (NID(0x00000000000002e3), NID(0x0000000000000326))))
    #= none:18 =#
    observed = if comparable
            D(NID(0x00000000000002e2) => Int(status == NID(0x00000000000002e3)), NID(0x000000000000063c) => Int(after[NID(0x0000000000000638)]))
        else
            nothing
        end
    #= none:19 =#
    delta = if comparable
            D((k => observed[k] - v for (k, v) = prediction[NID(0x000000000000004e)]))
        else
            nothing
        end
    #= none:20 =#
    verdict = if !comparable
            NID(0x0000000000000576)
        else
            if any((v != 0 for v = values(delta)))
                NID(0x0000000000000662)
            else
                NID(0x00000000000004f1)
            end
        end
    #= none:21 =#
    row = D(NID(0x0000000000000328) => op, NID(0x0000000000000121) => before[NID(0x0000000000000121)], NID(0x0000000000000663) => after[NID(0x0000000000000121)], NID(0x000000000000008c) => prediction[NID(0x000000000000008c)], NID(0x000000000000056f) => deepcopy(prediction[NID(0x000000000000004e)]), NID(0x0000000000000575) => observed, NID(0x0000000000000662) => delta, NID(0x000000000000008a) => verdict, NID(0x000000000000025a) => executed, NID(0x0000000000000664) => after[NID(0x00000000000002ce)])
    #= none:24 =#
    rows = get!(h, NID(0x000000000000045c), Any[])
    #= none:24 =#
    push!(rows, row)
    #= none:24 =#
    length(rows) > 32 && popfirst!(rows)
    #= none:25 =#
    totals = get!(h, NID(0x0000000000000665), D(NID(0x00000000000004f1) => 0, NID(0x0000000000000662) => 0, NID(0x0000000000000576) => 0))
    #= none:25 =#
    totals[verdict] += 1
    #= none:26 =#
    h[NID(0x000000000000065f)] = request
    #= none:27 =#
    if verdict == NID(0x0000000000000662) && !(get(h, NID(0x0000000000000641), false))
        #= none:28 =#
        h[NID(0x0000000000000641)] = true
        #= none:28 =#
        h[NID(0x0000000000000666)] = deepcopy(row)
        #= none:29 =#
        history = get!(h, NID(0x0000000000000667), Any[])
        #= none:29 =#
        push!(history, deepcopy(row))
        #= none:29 =#
        length(history) > 2 && popfirst!(history)
    end
    #= none:31 =#
    true
end
