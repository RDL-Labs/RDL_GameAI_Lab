using JSON3, Test
earlier,current=ARGS
@testset "ten-day prefix of thirty-day experiment" begin
for mode in ("off","on")
    old=JSON3.read(read(joinpath(earlier,"$mode-result.json"),String),Dict{String,Any})
    new=JSON3.read(read(joinpath(current,"$mode-result.json"),String),Dict{String,Any})
    delta=new["initial_food"]-old["initial_food"]
    @test delta==1_000_000
    for day in 1:10
        a=old["daily"][day];b=deepcopy(new["daily"][day])
        b["ground"]-=delta
        @test a==b
    end
end
end
