using Test, Random
include("mb_queue_candidate.jl")
@testset "stable bounded merge equals complete stable sort" begin
    rng=Xoshiro(819)
    for limit in (1,64,256), trial in 1:300
        prefix=rand(rng,0:limit);added=rand(rng,0:400)
        queue=[(cost=Float64(rand(rng,0:5)),node=string(rand(rng,1:5)),path_key=string(rand(rng,1:5)),id=i) for i in 1:prefix+added]
        for key in (x->(x.cost,x.path_key),x->(x.cost,x.node,x.path_key))
            original=copy(queue);sort!(view(original,1:prefix);by=key)
            expected=sort(copy(original);by=key);resize!(expected,min(length(expected),limit))
            @test mb_queue_merge!(original,prefix,limit,key)==expected
        end
    end
end
@testset "merge retains mutable candidate identity and duplicate entries" begin
    a=Dict{String,Any}("key"=>1);b=Dict{String,Any}("key"=>1);c=Dict{String,Any}("key"=>0)
    queue=Any[a,b,c,a]
    returned=mb_queue_merge!(queue,2,4,x->x["key"])
    @test returned===queue
    @test all(queue[i]===expected for (i,expected) in enumerate((c,a,b,a)))
    queue[2]["probe"]=true
    @test queue[4]["probe"]===true
    @test !haskey(b,"probe")
end
