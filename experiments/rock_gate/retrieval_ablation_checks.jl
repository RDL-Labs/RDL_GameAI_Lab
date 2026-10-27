include("../../integrations/lightweight_julia/native.jl")
include("retrieval_ablation.jl")
using Test
source=read(joinpath(@__DIR__,"../../src/lw/learning/mb_recognition.jl"),String)
# Its dependency is already loaded above; do not change include resolution.
source=replace(source,"include(\"mb_similarity_learning.jl\")"=>"")
@testset "strict top-k disables both expansion mechanisms" begin
 for k in (1,2,4,8)
    Base.include_string(Main,restrict_retrieval_source(source,k))
    for H in (0.,32.)
        s=mb_map_state("a")
        s["current"]=(key="observed",signature="brown:far:0|gray:far:2",anchor=0.)
        for i in 1:40
            s["nodes"][lpad(string(i),2,'0')]=D("signature"=>"brown:near:0|gray:near:2")
        end
        Base.invokelatest(mb_correspondences,s,keys(s["nodes"]),0;H=H)
        r=last(s["recognition"]["retrieval"]["records"])
        @test r["examined"]==k
        @test r["batches"]==1 && r["best_weight"]<.25
    end
 end
 @test_throws ErrorException restrict_retrieval_source(source,0)
end
