# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
using Test
#= none:2 =# @testset("finite safety selection", begin
        #= none:3 =#
        m = D(NID(0x000000000000030d) => D(NID(0x000000000000030e) => [D(NID(0x0000000000000195) => ncat(i), NID(0x000000000000030c) => 1.0) for i = 0:4]))
        #= none:4 =#
        seen = D(NID(0x000000000000034e) => NID(0x000000000000034f), NID(0x0000000000000341) => [D(NID(0x000000000000027b) => 2.0, NID(0x000000000000027c) => 2.0, NID(0x0000000000000084) => sqrt(8.0))])
        #= none:5 =#
        clear = D(NID(0x000000000000034e) => NID(0x000000000000034f), NID(0x0000000000000341) => Any[])
        #= none:6 =#
        s = safety_state()
        #= none:7 =#
        #= none:7 =# @test safety_plan!(s, clear, m) === nothing
        #= none:8 =#
        #= none:8 =# @test (safety_plan!(s, seen, m))[NID(0x000000000000021f)] == NID(0x000000000000030f)
        #= none:9 =#
        #= none:9 =# @test s[NID(0x00000000000001bc)] && s[NID(0x0000000000000350)] == 1
        #= none:10 =#
        blocked = D(NID(0x000000000000030d) => D(NID(0x000000000000030e) => [D(NID(0x0000000000000195) => NID(0x000000000000067b), NID(0x000000000000030c) => nothing)]))
        #= none:11 =#
        #= none:11 =# @test (safety_plan!(s, seen, blocked))[NID(0x000000000000021f)] == NID(0x000000000000030b)
        #= none:12 =#
        for i = 1:3
            #= none:13 =#
            #= none:13 =# @test (safety_plan!(s, clear, m))[NID(0x000000000000021f)] == NID(0x000000000000030b)
            #= none:14 =#
        end
        #= none:15 =#
        #= none:15 =# @test safety_plan!(s, clear, m) === nothing
        #= none:16 =#
        #= none:16 =# @test s[NID(0x0000000000000351)] == 1 && !(s[NID(0x00000000000001bc)])
        #= none:17 =#
        #= none:17 =# @test safety_plan!(s, seen, m) !== nothing && s[NID(0x0000000000000350)] == 2
        #= none:18 =#
        safety_plan!(s, clear, m)
        #= none:19 =#
        safety_plan!(s, seen, m)
        #= none:20 =#
        #= none:20 =# @test s[NID(0x00000000000001e8)] == 0
        #= none:21 =#
        w = (positions = Dict(NID(0x0000000000000049) => (0.0, 0.0)), obstacles = Any[])
        #= none:22 =#
        yaw = Dict(NID(0x0000000000000049) => 0.0)
        #= none:23 =#
        hs = [(x = 0.0, z = 2.0, vx = 1.0, vz = 0.0, start = 0, stop = 10)]
        #= none:24 =#
        ob = hazard_observation(w, NID(0x0000000000000049), yaw, hs, 1)
        #= none:25 =#
        #= none:25 =# @test length(ob[NID(0x0000000000000341)]) == 1
        #= none:26 =#
        #= none:26 =# @test ((ob[NID(0x0000000000000341)])[1])[NID(0x000000000000027c)] == 1.0
        #= none:27 =#
        #= none:27 =# @test Set(keys((ob[NID(0x0000000000000341)])[1])) == Set([NID(0x000000000000027b), NID(0x000000000000027c), NID(0x0000000000000084)])
        #= none:28 =#
        #= none:28 =# @test isempty((hazard_observation(w, NID(0x0000000000000049), yaw, hs, 10))[NID(0x0000000000000341)])
        #= none:29 =#
        yaw[NID(0x0000000000000049)] = 180.0
        #= none:30 =#
        #= none:30 =# @test isempty((hazard_observation(w, NID(0x0000000000000049), yaw, hs, 1))[NID(0x0000000000000341)])
    end)
function validate_integrated(r, input)
    #= none:33 =#
    #= none:34 =#
    cfg = input.config
    #= none:35 =#
    #= none:35 =# @testset "LW-Julia integrated invariants" begin
            #= none:36 =#
            #= none:36 =# @test r[NID(0x0000000000000070)] == cfg.days * input.clock.day_us
            #= none:37 =#
            #= none:37 =# @test all((sum(values((r[NID(0x0000000000000086)])[a])) == cfg.days * 17280 for a = IDS))
            #= none:38 =#
            #= none:38 =# @test r[NID(0x0000000000000073)] + r[NID(0x0000000000000075)] == r[NID(0x0000000000000036)] + get(r, NID(0x0000000000000071), 0) + r[NID(0x0000000000000076)] + sum((s[NID(0x0000000000000081)] + s[NID(0x0000000000000083)] for s = values(r[NID(0x000000000000007d)])))
            #= none:39 =#
            #= none:39 =# @test all((isfinite(v) for s = values(r[NID(0x000000000000007d)]) for v = values(s[NID(0x0000000000000080)]) if v isa Number))
        end
end
#= none:44 =# @testset("Sleep uses current dynamic hazard observation", begin
        #= none:45 =#
        w = (positions = Dict(NID(0x0000000000000049) => (0.0, 0.0)), obstacles = Any[])
        #= none:46 =#
        yaw = Dict(NID(0x0000000000000049) => 0.0)
        #= none:47 =#
        state = dynamic_hazards()
        #= none:48 =#
        (state[NID(0x000000000000029d)])[NID(0x000000000000007f)] = (0.0, 2.0)
        #= none:49 =#
        movement = D(NID(0x0000000000000383) => NID(0x000000000000034f), NID(0x00000000000001dd) => Any[], NID(0x000000000000030d) => D(NID(0x000000000000030e) => Any[]))
        #= none:50 =#
        view = hazard_observation(w, NID(0x0000000000000049), yaw, dynamic_hazard_sources(state, 20; patrol = false), 20)
        #= none:51 =#
        #= none:51 =# @test (sleep_context(movement, view))[2] === true
        #= none:52 =#
        (state[NID(0x000000000000029d)])[NID(0x000000000000007f)] = (0.0, 20.0)
        #= none:53 =#
        nextview = hazard_observation(w, NID(0x0000000000000049), yaw, dynamic_hazard_sources(state, 21; patrol = false), 21)
        #= none:54 =#
        #= none:54 =# @test (sleep_context(movement, nextview))[2] === false
        #= none:55 =#
        #= none:55 =# @test (sleep_context(movement, view))[2] === true
        #= none:56 =#
        #= none:56 =# @test sleep_context(movement, D(NID(0x000000000000034e) => NID(0x0000000000000384), NID(0x0000000000000341) => Any[])) === nothing
    end)
