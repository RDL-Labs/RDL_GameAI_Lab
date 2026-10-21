root=normpath(joinpath(@__DIR__,".."))
path=joinpath(root,"src/ecology/herbivore/update.jl")
text=replace(read(path,String),"\r\n"=>"\n")
header="function step!(w,a,t,demand,ratio,requests,active; threat=nothing,policy=StateMachinePolicy())"
occursin(header,text) || error("Already split or unexpected update source")
text=replace(text,header=>"function prepare_requests!(w,a,t,demand,requests,active,threat,policy)")
text=replace(text,"    # Simultaneous proportional allocation prevents first-agent access bias."=>
    "end\n\nfunction allocate_grass!(w,demand,ratio,active)\n    # Simultaneous proportional allocation prevents first-agent access bias.")
marker="    for i in 1:n\n        state=a.state[i]"
occursin(marker,text) || error("Unexpected update source")
text=replace(text,marker=>"end\n\nfunction apply_actions!(w,a,t,ratio,requests,threat,policy)\n    for i in eachindex(a.x)\n        state=a.state[i]")
text*="""

# One authoritative tick order. Resource arbitration precedes every action.
function step!(w,a,t,demand,ratio,requests,active;threat=nothing,policy=StateMachinePolicy())
    prepare_requests!(w,a,t,demand,requests,active,threat,policy)
    allocate_grass!(w,demand,ratio,active)
    apply_actions!(w,a,t,ratio,requests,threat,policy)
end
"""
write(path,text)
# Keep the LW order, extracting its shared end-of-tick physiology operation.
path=joinpath(root,"src/lw/simulation/day.jl")
text=replace(read(path,String),"\r\n"=>"\n")
start=findfirst("        if food_body\n            for a in IDS\n                before=w.bodies",text)
stop=findfirst("        @assert shared+sum(stock)",text)
start===nothing && error("Missing physiology phase")
body=text[first(start):prevind(text,first(stop))]
write(joinpath(root,"src/lw/simulation/physiology.jl"),"function advance_physiology!(w,metabolism,guts,food_body)\n"*body*"end\n")
text=replace(text,body=>"        advance_physiology!(w,metabolism,guts,food_body)\n")
text="include(\"physiology.jl\")\n"*text
text=replace(text,"    for sec in 0:days*div(clock.day_us,1_000_000)-1"=>"    # Tick phases: world/clock -> observations -> learning/decision -> actions -> physiology -> daily consolidation.\n    for sec in 0:days*div(clock.day_us,1_000_000)-1")
text=replace(text,"        plans=D()"=>"        # Every actor plans from observations acquired before any actor acts.\n        plans=D()")
text=replace(text,"        w.seconds=sec+1"=>"        # Ordered action resolution: receipts are stamped at the end of this second.\n        w.seconds=sec+1")
write(path,text)
