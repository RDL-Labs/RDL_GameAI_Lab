using JSON3,Serialization
include("trade_observation.jl")
include("role_probe.jl")
include("trade_channels.jl")
root=only(ARGS)
memory=deserialize(joinpath(root,"communication_state.bin"))["npc_e"]
println("MEMORY ",JSON3.write((receipts=memory.roles.receipts,pending_count=length(memory.pending),words=memory.words.evidence)))
result=JSON3.read(read(joinpath(root,"run/result.json"),String))
day_us=JSON3.read(read(joinpath(root,"input.json"),String)).clock.day_us
println("E_RESPONSES ",JSON3.write([(day=div(r.us,day_us)+1,second=rem(r.us,day_us)/1e6,partner=r.partner,action=r.action,status=r.status) for r in result.incidental_items.npc_e.social.records if startswith(r.source,"items:response:")]))
println("E_PREDICTIONS ",JSON3.write([(day=div(r.us,day_us)+1,selected=r.selected,method=c.method,prediction=c.communication_prediction) for r in result.social_relationships.npc_e.gradient_maps.records for c in r.candidates if haskey(c,:communication_prediction)]))
