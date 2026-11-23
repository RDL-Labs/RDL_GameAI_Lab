using Test,JSON3,Downloads
const OUTPUT=mktempdir()
include("../../src/lw/configured_paths/api_transport.jl")
@testset "API rate retry" begin
    raw=JSON3.write((error=(code="rate_limit_exceeded",message="Please try again in 1.927s.",),))
    @test configured_api_retry_delay(429,raw,Pair{String,String}[],1)≈2.927
    @test configured_api_retry_delay(429,raw,["Retry-After"=>"5"],1)==6
    @test configured_api_retry_delay(429,"{\"error\":{\"code\":\"insufficient_quota\"}}",[],1)===nothing
    @test configured_api_retry_delay(401,raw,[],1)===nothing
    calls=Ref(0);waits=Float64[]
    send=p->begin calls[]+=1;calls[]==1 ? (status=429,headers=[],body=raw) : (status=200,headers=[],body="ok") end
    @test configured_api_request((x=1,),"test";send,pause=x->push!(waits,x))=="ok"
    @test calls[]==2
    @test waits≈[2.927]
    @test_throws ErrorException configured_api_request(nothing,"auth";send=p->(status=401,headers=[],body=raw),pause=x->error("must not sleep"))
end
