include("core_checks.jl")
@testset "tracking toggle preserves reachable identities" begin
    NumericCore.PINNED[]=length(NumericCore.BYTES)
    live=nid("live-experience-123")
    dead=nid("discarded-operation-999")
    hidden=nid("closure-experience-456")
    closure=let captured=hidden; ()->captured; end
    roots=Dict(live=>Any[closure])
    push!(roots[live],roots) # reachable cycle
    NumericCore.TRACK_IDS[]=true
    NumericCore.collect_ids!(roots)
    @test isempty(NumericCore.FREE)
    NumericCore.TRACK_IDS[]=false
    NumericCore.collect_ids!(roots)
    @test dead.value in NumericCore.FREE
    @test !(live.value in NumericCore.FREE)
    @test !(hidden.value in NumericCore.FREE)
    @test nid("live-experience-123")==live
    @test decode(closure())=="closure-experience-456"
    next=nid("new-operation-1000")
    @test next.value==dead.value
    @test decode(next)=="new-operation-1000"
    @test decode(nid("grass"))=="grass" # pinned vocabulary survives
    saved=deepcopy(NumericCore.BYTES); free=copy(NumericCore.FREE)
    NumericCore.restore_registry!(saved,free)
    @test nid("live-experience-123")==live
    @test nid("new-operation-1000")==next
end
