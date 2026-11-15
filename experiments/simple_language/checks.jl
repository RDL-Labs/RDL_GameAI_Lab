using Test,Serialization,JSON3
include("../../src/lw/LW.jl")
include("local_probe.jl")
const A=LW.IDS[1];const B=LW.IDS[2]
function fixture()
 w=LW.world(true);empty!(w.obstacles);stores=Dict(a=>0 for a in LW.IDS)
 for a in LW.IDS;w.inventory[a]=0;w.positions[a]=(0.,0.);end
 r=LW.food_resources((typed_food=true,food_batch_expiry=true,),w,Any[],Int[],0,stores)
 for (kind,q,deadline) in ((1,2,5),(3,4,30))
  LW.food_push!(r,B,kind,q;deadline);r.initial[kind]+=1;w.inventory[B]+=1
 end
 cargo=Dict(a=>(a==B ? ["fruit-lot","acorn-lot"] : String[]) for a in LW.IDS)
 lex=LocalLexicon();local_seed!(lex,"どんぐり",3);local_seed!(lex,"くだもの",1)
 (w=w,r=r,cargo=cargo,lex=lex,receipts=Dict{Any,Any}(),stores=stores)
end
rows=Any[]
@testset "local named food request" begin
 f=fixture();obs=local_receive(f.w,A,B,"u1","どんぐり、ちょうだい")
 result=local_answer!(f.receipts,f.lex,obs,f.w,f.r,f.cargo;accept=true)
 push!(rows,(case="named_request",result=result))
 @test result==(status=:transferred,kind=3,quality=4,deadline=30)
 @test f.r.inventory[A]==[3] && f.r.inventory[B]==[1]
 @test f.cargo[A]==["acorn-lot"] && f.cargo[B]==["fruit-lot"]
 @test LW.food_audit!(f.r,f.w,Int[],0,f.stores)===nothing
 @test LW.food_age_audit!(f.r)===nothing
 @test local_answer!(f.receipts,f.lex,obs,f.w,f.r,f.cargo;accept=true)==result
 @test f.w.inventory[A]==1
 @test_throws ErrorException local_answer!(f.receipts,f.lex,merge(obs,(expression="くだもの、ちょうだい",)),f.w,f.r,f.cargo;accept=true)
 io=IOBuffer();serialize(io,(f,obs));seekstart(io);restored,savedobs=deserialize(io)
 @test local_answer!(restored.receipts,restored.lex,savedobs,restored.w,restored.r,restored.cargo;accept=true)==result
 @test restored.w.inventory[A]==1
 for (expression,expected,accept) in (("なも、ちょうだい",:unknown_name,true),("どうぞ",:give_marker,true),("どんぐり、ちょうだい",:declined,false))
  g=fixture();ob=local_receive(g.w,A,B,"u2",expression)
  answer=local_answer!(g.receipts,g.lex,ob,g.w,g.r,g.cargo;accept)
  push!(rows,(case=String(expected),result=answer))
  @test answer.status==expected
  @test g.w.inventory[A]==0 && g.r.inventory[B]==[1,3]
 end
 g=fixture();g.w.hearing[B]=false
 @test local_receive(g.w,A,B,"u3","どんぐり、ちょうだい")===nothing
 @test local_interpret(LocalLexicon(),"どんぐり、ちょうだい").status==:unknown_name
 g=fixture();ob=local_receive(g.w,A,B,"u4","どんぐり、ちょうだい");g.w.seconds+=6
 @test local_answer!(g.receipts,g.lex,ob,g.w,g.r,g.cargo;accept=true).status==:expired
 g=fixture();g.lex.names["どんぐり"]=[1,3]
 @test local_interpret(g.lex,"どんぐり、ちょうだい").status==:unresolved_referent
 @test local_interpret(g.lex,repeat("あ",65)).status==:too_long
end
write(joinpath(@__DIR__,"result.json"),JSON3.write((scope="isolated fixed-response prototype; no life loop or MB updates",cases=rows)))
