include(joinpath(@__DIR__,"native.jl"))
@testset "parent search relocation and survey" begin
 s=BasicLoop("home");s.H=32;state=reposition_state("a")
 chosen=String[]
 for i in 1:20
  cs=Any[D("method"=>"survey","action"=>"scan","priority"=>2.,"question"=>"target_observed"),D("method"=>"reposition_0","action"=>"walk","priority"=>3.5,"question"=>"target_observed")]
  project_search_review!(state,cs,s,nothing,"home")
  p=choose_method!(s,cs,string(i));push!(chosen,p["method"])
  search_review_result!(state,"home",p["method"],false,true)
  resolve_method!(s,string(i),false,false)
 end
 @test "survey" in chosen
 @test "reposition_0" in chosen
 @test s.H==32
 @test s.methods["reposition_0"].H>0
 @test s.methods["survey"].H>0
 search_review_result!(state,"home","survey",true,true)
 @test state["review_H"]==0
 @test s.H==32
 search_review_result!(state,"food","reposition_0",false,false)
 @test state["review_H"]==0
end

