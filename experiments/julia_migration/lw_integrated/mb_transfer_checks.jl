using Test
include("../../../integrations/lightweight_julia/native.jl")
@testset "new-world learned MB transfer" begin
    old=mb_map_state("a");old["nodes"]["n"]=D("signature"=>"gray:1:0","home"=>true,"food"=>false,"seen"=>90)
    old["receipt"]=D("unfinished"=>true);old["current"]=D("old"=>true)
    old["parent_mb"]["active"]["home"]=D("source"=>"op:0:a")
    fresh=mb_map_state("a");mb_transfer!(fresh,old,100)
    @test fresh["nodes"]["n"]["seen"]==-10
    @test old["nodes"]["n"]["seen"]==90
    mb_similarity((signature="gray:near:0",anchor=0.),old["nodes"]["n"])
    serialized=JSON3.read(JSON3.write(old),Dict{String,Any})
    reload=mb_map_state("a");mb_transfer!(reload,serialized,100)
    @test mb_similarity((signature="gray:near:0",anchor=0.),reload["nodes"]["n"])!==nothing
    @test fresh["nodes"]["n"]["home"]
    @test fresh["receipt"]===nothing && fresh["current"]===nothing
    @test isempty(fresh["parent_mb"]["active"])
    @test isempty(fresh["route_trace"])
    loop=BasicLoop("a:home");loop.methods["walk"]=MethodNode(4.,2.,12,5.,3,8.)
    restored=BasicLoop("a:home");mb_transfer_methods!(restored,loop_snapshot(loop))
    @test restored.methods["walk"].reward==5
    @test restored.methods["walk"].failure_count==3
    @test restored.methods["walk"].H==0
    @test restored.trial===nothing && restored.receipt===nothing
end
