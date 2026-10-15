# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
struct AidNotice
    #= none:3 =#
    actor::NID
    #= none:4 =#
    id::NID
    #= none:5 =#
    target::NID
    #= none:6 =#
    outcome::NID
    #= none:7 =#
    request::NID
    #= none:8 =#
    result::NID
end
Base.:(==)(a::AidNotice, b::AidNotice) = begin
        #= none:10 =#
        all((getfield(a, k) == getfield(b, k) for k = fieldnames(AidNotice)))
    end
function aid_notice(id, r)
    #= none:11 =#
    #= none:12 =#
    fields = (r[NID(0x00000000000002cb)], id, r[NID(0x00000000000001b0)], r[NID(0x0000000000000334)], r[NID(0x00000000000002f6)], r[NID(0x0000000000000443)])
    #= none:13 =#
    check(all((x->begin
                    #= none:13 =#
                    x isa NID && !(isempty(x))
                end), fields), NID(0x00000000000005a1))
    #= none:14 =#
    check(fields[4] in (NID(0x0000000000000516), NID(0x00000000000002aa), NID(0x000000000000057d), NID(0x0000000000000528)), NID(0x00000000000005a2))
    #= none:15 =#
    AidNotice(fields...)
end
mutable struct LiveAid
    #= none:18 =#
    actor::NID
    #= none:19 =#
    state::AidPressure
    #= none:20 =#
    seen::Dict{NID, AidNotice}
end
live_aid(actor, theta = 3) = begin
        #= none:22 =#
        LiveAid(actor, pressure_update(nothing, Records(), actor, theta), Dict{NID, AidNotice}())
    end
pressure_snapshot(live::LiveAid) = begin
        #= none:23 =#
        deepcopy(live.state)
    end
function pressure_poll!(live, records, accepted_count)
    #= none:24 =#
    #= none:25 =#
    count = length(records)
    #= none:26 =#
    check(count in (accepted_count, accepted_count + 1), NID(0x00000000000005a3))
    #= none:27 =#
    notice = if count == accepted_count
            nothing
        else
            aid_notice(last(records.order), records[last(records.order)])
        end
    #= none:28 =#
    pressure_update!(live, notice)
end
function aid_finish!(s::GoalState, n::AidNotice)
    #= none:31 =#
    #= none:32 =#
    confirmed = n.outcome == NID(0x0000000000000516)
    #= none:32 =#
    comparable = n.outcome != NID(0x0000000000000528)
    #= none:33 =#
    trial = D(NID(0x000000000000056c) => n.id, NID(0x0000000000000121) => D(NID(0x00000000000002cd) => n.request), NID(0x000000000000008c) => s.model_ref, NID(0x000000000000042d) => s.goal_id, NID(0x000000000000055b) => s.dimension, NID(0x000000000000056d) => D(s.dimension => 1))
    #= none:35 =#
    before = s.H
    #= none:35 =#
    E = if comparable
            if confirmed
                0
            else
                1
            end
        else
            nothing
        end
    #= none:36 =#
    comparable && (s.H = if confirmed
                0
            else
                before + E
            end)
    #= none:37 =#
    s.records[n.id] = D(NID(0x00000000000001b6) => trial, NID(0x000000000000042f) => D(NID(0x00000000000004ef) => confirmed, NID(0x000000000000022a) => comparable, NID(0x0000000000000121) => n.result), NID(0x0000000000000573) => if comparable
                    D(s.dimension => Int(confirmed))
                else
                    nothing
                end, NID(0x0000000000000442) => E, NID(0x000000000000045d) => before, NID(0x0000000000000445) => s.H, NID(0x000000000000008a) => if comparable
                    NID(0x000000000000049d)
                else
                    NID(0x0000000000000574)
                end)
end
function pressure_update!(live::LiveAid, n::Union{Nothing, AidNotice} = nothing)
    #= none:41 =#
    #= none:42 =#
    n === nothing && return live.state
    #= none:43 =#
    check(n.actor == live.actor, NID(0x0000000000000578))
    #= none:44 =#
    if haskey(live.seen, n.id)
        #= none:45 =#
        check(live.seen[n.id] == n, NID(0x00000000000005a4))
        #= none:45 =#
        return live.state
    end
    #= none:47 =#
    check(length(live.seen) < 192, NID(0x00000000000005a5))
    #= none:48 =#
    p = live.state
    #= none:49 =#
    check(p.parent.trial === nothing, NID(0x00000000000005a6))
    #= none:50 =#
    method = get(p.methods, n.target, nothing)
    #= none:51 =#
    check(method === nothing || method.trial === nothing, NID(0x00000000000005a6))
    #= none:52 =#
    if method === nothing
        #= none:53 =#
        method = ginitial(live.actor * NID(0x0000000000000579) * n.target, NID(0x0000000000000575), NID(0x0000000000000576), p.parent.threshold, p.parent.goal_id)
        #= none:54 =#
        p.methods[n.target] = method
    end
    #= none:56 =#
    aid_finish!(p.parent, n)
    #= none:56 =#
    aid_finish!(method, n)
    #= none:56 =#
    live.seen[n.id] = n
    #= none:57 =#
    p
end
