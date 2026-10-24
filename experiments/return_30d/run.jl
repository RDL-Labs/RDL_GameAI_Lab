using JSON3, SHA, Test
const root=normpath(joinpath(@__DIR__,"../.."))
const out=abspath(ARGS[1])
ispath(out) && error("output must be new")
mkpath(out)
const snapshot=joinpath(out,"source")
mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(root,"src"),joinpath(snapshot,"src"))
cp(joinpath(root,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
const daypath=joinpath(snapshot,"src/lw/simulation/day.jl")
const original=read(daypath,String)
const anchor="        advance_physiology!(w,metabolism,guts,food_body)"
@assert count(anchor,original)==1
const patched=replace(original,anchor=>anchor*"\n        Main.return_probe!(sec,w,purposes,plans,homes,loops,spec.home,shared,counts)")
write(daypath,patched)
const inputpath=joinpath(root,"experiments/julia_migration/lw_integrated/search_review_spec.json")
cp(inputpath,joinpath(out,"input.json"))
write(joinpath(out,"provenance.json"),JSON3.write((commit=strip(read(`git -C $root rev-parse HEAD`,String)),
    original_day_sha256=bytes2hex(sha256(original)),instrumented_day_sha256=bytes2hex(sha256(patched)),
    spec_sha256=bytes2hex(sha256(read(inputpath))),julia=string(VERSION),
    modification="read-only after-physiology return observer; original input unchanged")))
const samples=open(joinpath(out,"return_samples.jsonl"),"w")
const episodes=open(joinpath(out,"return_episodes.jsonl"),"w")
const progress=open(joinpath(out,"progress.jsonl"),"w")
const active=Dict{String,Dict{String,Any}}()
const started=time()
function return_probe!(sec,w,purposes,plans,homes,loops,home,shared,counts)
    for a in keys(purposes)
        p=purposes[a];pos=w.positions[a];dist=hypot(pos[1]-home[1],pos[2]-home[2])
        if p["active"]
            if !haskey(active,a) || active[a]["started_us"]!=p["started_us"]
                active[a]=Dict("actor"=>a,"started_us"=>p["started_us"],"first_observed_sec"=>sec,
                    "start_distance"=>dist,"min_distance"=>dist,"last_distance"=>dist,"zero_reserve_ticks"=>0,"ticks"=>0)
            end
            e=active[a];e["min_distance"]=min(e["min_distance"],dist);e["last_distance"]=dist
            e["ticks"]+=1;e["zero_reserve_ticks"]+=(w.bodies[a].reserve<=0)
        elseif haskey(active,a)
            e=pop!(active,a);e["completed_observed_sec"]=sec;e["completed"]=true
            JSON3.write(episodes,e);println(episodes);flush(episodes)
        end
        if mod(sec+1,60)==0 || (p["active"] && dist<=3)
            row=(sec=sec+1,actor=a,position=pos,distance=dist,reserve=w.bodies[a].reserve,
                inventory=w.inventory[a],purpose=p,home_visible=homes[a]!==nothing,
                home_H=loops[a]["home"].H,action=get(plans[a],"action",nothing),
                method=get(plans[a],"method",nothing),direction=get(plans[a],"direction",nothing))
            JSON3.write(samples,row);println(samples)
        end
    end
    if mod(sec+1,17280)==0
        row=(day=div(sec+1,17280),elapsed_seconds=time()-started,peak_rss=Sys.maxrss(),shared=shared,
            agents=Dict(a=>(position=w.positions[a],reserve=w.bodies[a].reserve,purpose=purposes[a],counts=counts[a]) for a in keys(purposes)))
        JSON3.write(progress,row);println(progress);flush(progress);flush(samples)
        println("DAY $(row.day) elapsed=$(round(row.elapsed_seconds,digits=1))s");flush(stdout)
    end
end
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
try
    native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json")])
    for e in values(active)
        e["completed"]=false;e["end_sec"]=30*17280
        JSON3.write(episodes,e);println(episodes)
    end
finally
    close(samples);close(episodes);close(progress)
end
const r=JSON3.read(read(joinpath(out,"run/result.json"),String))
const input=JSON3.read(read(joinpath(out,"input.json"),String))
include(joinpath(root,"experiments/julia_migration/lw_integrated/checks.jl"))
validate_integrated(r,input)
@testset "30-day daily accounting and continuity" begin
    @test length(r.daily)==30
    for (i,d) in enumerate(r.daily)
        @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(s.inventory+s.personal_stock for s in values(d.physical))
        i>1 && (@test r.day_starts[i]==r.daily[i-1].physical)
        for a in IDS
            previous=i==1 ? 0 : sum(values(r.daily[i-1].counts[a]))
            @test sum(values(d.counts[a]))-previous==17280
        end
    end
end
const daily=Any[]
for (i,d) in enumerate(r.daily), a in IDS
    s=d.physical[a];p=s.return_purpose
    previous=i==1 ? Dict{String,Int}() : r.daily[i-1].counts[a]
    delta=Dict(String(k)=>v-get(previous,k,0) for (k,v) in pairs(d.counts[a]))
    push!(daily,(day=i,actor=a,position=s.position,distance=hypot(s.position[1]-input.scene.home[1],s.position[2]-input.scene.home[2]),
        reserve=s.body.reserve,purpose=p,active_age_days=p.active ? (i*input.clock.day_us-p.started_us)/input.clock.day_us : 0.,
        home_H=s.loops.home.H,actions=delta))
end
write(joinpath(out,"daily_return.json"),JSON3.write(daily))
write(joinpath(out,"status.json"),JSON3.write((status="complete",days=30,operations=1555200,checks_passed=true)))
println("COMPLETE: return audit saved")
