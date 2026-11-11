using Serialization, JSON3
include("../rock_gate/parent_candidate_reuse_checks.jl")
fixtures=deserialize(ARGS[1]);rows=Any[]
@testset "recorded candidate batches" begin
    for (index,fixture) in enumerate(fixtures)
        a=deepcopy(fixture);b=deepcopy(fixture)
        @test mb_parent_candidates!(a.s,a.candidates,a.goal,a.target)==candidate_reference!(b.s,b.candidates,b.goal,b.target)
        @test a.s==b.s
        for iteration in 1:4
            order=isodd(iteration) ? ("baseline","optimized") : ("optimized","baseline")
            for mode in order
                work=deepcopy(fixture)
                f=mode=="baseline" ? candidate_reference! : mb_parent_candidates!
                f(work.s,work.candidates,work.goal,work.target)
                m=@timed for repetition in 1:100
                    f(work.s,work.candidates,work.goal,work.target)
                end
                push!(rows,(;index,iteration,mode,seconds=m.time,bytes=m.bytes,gc=m.gctime))
            end
        end
    end
end
write(ARGS[2],JSON3.write((;fixtures=length(fixtures),repetitions_per_sample=100,rows)))
