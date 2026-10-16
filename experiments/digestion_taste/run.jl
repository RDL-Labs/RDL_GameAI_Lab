using Test, JSON3
include("../julia_migration/lw_integrated/run.jl")
@testset "taste, fullness and delayed nutrition" begin
    g=Digestion(); b=Body(10.,0.,50.,0.)
    @test taste(g,2,50)>taste(g,1,50)
    @test taste(g,2,90)<taste(g,2,50)
    first=ingest!(g,2,b.reserve,0)
    @test b.reserve==50
    @test taste(g,2,50)<first
    @test taste(g,1,50)>taste(g,2,50)
    ingest!(g,1,50,1)
    @test !can_ingest(g)
    @test taste(g,2,50)==0
    @test_throws ErrorException ingest!(g,1,50,2)
    b=digest!(g,b,900.)
    @test isapprox(b.reserve,60.)
    @test isapprox(g.gut,1.5)
    @test !can_ingest(g)
    b=digest!(g,b,2700.)
    @test isapprox(b.reserve,90.) && g.gut==0
    @test isapprox(g.absorbed,40.)
    @test can_ingest(g)
    @test digestion_snapshot(g)["eaten"]==2
    @test_throws ErrorException digest!(g,b,-1.)
    @test_throws ErrorException ingest!(g,3,50,3)
    for kind in (1,2)
        sat=Digestion(); ingest!(sat,kind,95,0)
        after=digest!(sat,Body(10.,0.,95.,0.),1800.)
        @test after.reserve==100 && sat.absorbed==5 && sat.overflow==15
        @test digestion_snapshot(sat)["gut"]==0
    end
end
# Controlled choice fixture: equal availability, nutrition and effort.
function controlled_choices()
g=Digestion(); b=Body(10.,0.,50.,0.); choices=Any[]
for t in (0,1,2,1800,3600,10800)
    elapsed=isempty(choices) ? 0 : t-choices[end].time
    b=digest!(g,b,Float64(elapsed))
    scores=[taste(g,k,b.reserve) for k in 1:2]
    kind=can_ingest(g) ? argmax(scores) : 0
    liking=kind==0 ? 0. : ingest!(g,kind,b.reserve,t)
    push!(choices,(time=t,kind=kind,scores=scores,liking=liking,gut=g.gut,reserve=b.reserve))
end
choices
end
choices=controlled_choices()
@test choices[1].kind==2 && choices[2].kind==1 && choices[3].kind==0
base=JSON3.read(read(joinpath(@__DIR__,"spec.json"),String),Dict{String,Any})
rows=Any[]; reports=Dict{String,Any}()
out=length(ARGS)>0 ? abspath(ARGS[1]) : joinpath(@__DIR__,"../../outputs/digestion-taste")
mkpath(out)
for mode in ("off","ordinary","meat")
    raw=deepcopy(base); raw["config"]["digestion"]=mode
    input=JSON3.read(JSON3.write(raw))
    m=@timed run_integrated(input); r,s=m.value; reports[mode]=r
    write(joinpath(out,"$mode-result.json"),JSON3.write(r))
    write(joinpath(out,"$mode-spec.json"),JSON3.write(input))
    row=(mode=mode,seconds=m.time,consumed=r["consumed"],
        reserves=Dict(a=>r["final_agents"][a]["body"]["reserve"] for a in IDS),
        digestion=get(r,"digestion",nothing))
    push!(rows,row); println(JSON3.write(row))
end
# Opt-out remains exactly equivalent to omitted config.
base_result,_=run_integrated(JSON3.read(JSON3.write(base)))
@test reports["off"]==base_result
prior=joinpath(@__DIR__,"../../outputs/julia-entry-smoke/result.json")
prior_checked=isfile(prior)
if prior_checked
    prior_matches=JSON3.read(JSON3.write(reports["off"]))==JSON3.read(read(prior,String))
    @test prior_matches
end
# Taste alone must not silently alter physics or create a hunting bonus.
ordinary=deepcopy(reports["ordinary"]); meat=deepcopy(reports["meat"])
delete!(ordinary,"digestion"); delete!(meat,"digestion")
@test ordinary==meat
@test sum(reports["meat"]["digestion"][a]["eaten"] for a in IDS)==reports["meat"]["consumed"]
repeat_input=deepcopy(base); repeat_input["config"]["digestion"]="meat"
repeat_result,_=run_integrated(JSON3.read(JSON3.write(repeat_input)))
@test repeat_result==reports["meat"]
write(joinpath(@__DIR__,"results.json"),JSON3.write((choices=choices,runs=rows,prior_baseline_checked=prior_checked)))
println("Digestion/taste integration, off parity and replay passed")
