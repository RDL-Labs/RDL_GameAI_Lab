using Test, Serialization, JSON3, SHA, Random
include("../../integrations/lightweight_julia/native.jl")

# Optional original run supplies captured decision evidence and day-end MBs.
# Captured scores isolate temperature; day-end MBs test the real response path.
@testset "request H does not enter provision" begin
    aid=social_aid_state("npc_e")
    obs=D("self_id"=>"npc_e","inventory"=>1,"body"=>D("body_demand"=>0.,"reserve"=>100.),
        "messages"=>[D("id"=>"test","sender"=>"npc_b","kind"=>"request")],
        "others"=>[D("ref"=>"npc_b","holding_food"=>true)])
    _,base=experienced_response(obs,D(),social_aid_pressure(aid),"npc_e","scope";retention=1.)
    aid["loop"].H=32.
    rng_before=copy(aid["loop"].rng)
    _,high=experienced_response(obs,D(),social_aid_pressure(aid),"npc_e","scope";retention=1.)
    @test base==high
    @test aid["loop"].H==32.
    @test rand(copy(aid["loop"].rng),UInt64)==rand(rng_before,UInt64)
    obs["body"]["body_demand"]=.8
    @test experienced_response(obs,D(),social_aid_pressure(aid),"npc_e","scope";retention=1.)[2]["give_probability"]<high["give_probability"]
    @test experienced_response(obs,D(),social_aid_pressure(aid),"npc_e","scope";available_food=false)[1][1]=="refuse"
end

if !isempty(ARGS)
 @testset "E captured provision cases" begin
  for (day,t) in ((11,176720000000),(17,281768000000),(21,350346000000),(24,401161000000))
    state=deserialize(joinpath(ARGS[1],"checkpoints","day-"*lpad(day,3,'0')*".jls")).state
    relation=state[:relations]["npc_e"]
    row=only(filter(r->r["us"]==t && r["channel"]=="aid_response",relation["gradient_maps"]["records"]))
    candidate=only(filter(c->c["action"]=="give",row["candidates"]))
    score=candidate["base"]
    old=method_distribution(BasicLoop("replay";threshold=3.),[D("method"=>"refuse","priority"=>0.),D("method"=>"give","priority"=>score)])
    loop=BasicLoop("replay";threshold=3.);loop.H=row["H"]
    @test method_distribution(loop,[D("method"=>"refuse","priority"=>0.),D("method"=>"give","priority"=>score)])[2]≈candidate["probability"]
    bits=foldl((x,b)->(x<<8)|UInt64(b),sha256(row["source"])[1:8];init=UInt64(0))
    draw=Float64(bits)/18446744073709551616.
    @test draw>=1-candidate["probability"]
    other=split(row["selected"],":")[2]
    obs=D("self_id"=>"npc_e","inventory"=>1,"body"=>D("body_demand"=>0.,"reserve"=>100.),
        "messages"=>[D("id"=>"replay","sender"=>other,"kind"=>"request")],"others"=>[D("ref"=>other)])
    relation["gradient_logging"]=false
    pressure=social_aid_pressure(relation["aid"])
    pressure.loop.H=0.
    low=experienced_response(obs,D(),pressure,"npc_e",row["source"];relation,retention=1.,now=t)
    pressure.loop.H=32.
    high=experienced_response(obs,D(),pressure,"npc_e",row["source"];relation,retention=1.,now=t)
    @test low==high
    @test pressure.loop.H==32.
    println(JSON3.write((day,H=row["H"],before=candidate["probability"],fixed_evidence_after=old[2],draw,
        selected=draw<1-old[2] ? "refuse" : "give",day_end_MB_probability=high[2]["give_probability"])))
  end
 end
end
