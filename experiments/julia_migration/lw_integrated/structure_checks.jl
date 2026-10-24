include(joinpath(@__DIR__,"native.jl"))
using Test
function structure_ground(t=0)
 cells=[D("angle"=>a,"distance"=>d,"status"=>"sampled","appearance"=>a==0 ? "bare_ground" : a==-90 ? "water" : "grass") for a in ANGLES for d in (1,2,4)]
 D("source"=>D("actor"=>"a","observation"=>"ob:$t:a","capture_us"=>t),"coverage"=>"complete","cells"=>cells)
end
wall_samples()=D("samples"=>[D("angle"=>a,"distance"=>1.,"status"=>"hit") for a in -90:30:90])
receipt(t,u)=D("actor"=>"a","source"=>"ob:$t:a","before_us"=>t,"after_us"=>u,"right"=>0.,"forward"=>0.,"yaw"=>0.)
@testset "shared sampled structure and gaps" begin
 g=structure_ground();w=wall_samples();ob=local_structures(g,w)
 @test Set(x["kind"] for x in ob["groups"])==Set(["worn_ground","water","grass","obstacle"])
 @test length(filter(x->x["kind"]=="obstacle",ob["groups"]))==1
 @test all(x["continuity"]=="between_samples_unverified" for x in ob["groups"])
 w["samples"][4]["status"]="clear";w["samples"][4]["distance"]=12.
 split=local_structures(g,w)
 @test length(filter(x->x["kind"]=="obstacle",split["groups"]))==2
 @test any(x->x["kind"]=="obstacle" && x["passability"]=="unverified",split["breaks"])
 w["samples"][4]["status"]="unknown"
 hidden=local_structures(g,w)
 @test !any(x->x["kind"]=="obstacle",hidden["breaks"])
 @test any(x->x["status"]=="unobserved",hidden["boundaries"])
 # A large interval between like samples cannot become a continuous surface.
 w=wall_samples();w["samples"][4]["distance"]=10.
 @test any(x->x["status"]=="unresolved_interval",local_structures(g,w)["boundaries"])
 g["cells"][8]["appearance"]="grass"
 @test length(filter(x->x["kind"]=="worn_ground",local_structures(g,w)["groups"]))==2
 g["cells"][8]["status"]="occluded";g["cells"][8]["appearance"]=nothing
 @test !any(x->x["kind"]=="worn_ground",local_structures(g,w)["breaks"])
end
@testset "bounded identity, splitting, merging and body link" begin
 s=structure_memory("a");g=structure_ground();w=wall_samples()
 update_structures!(s,local_structures(g,w),nothing)
 old=only(filter(x->x["kind"]=="obstacle",s["models"]))["model_ref"]
 update_structures!(s,local_structures(structure_ground(1_000_000),w),receipt(0,1_000_000))
 @test only(filter(x->x["kind"]=="obstacle",s["models"]))["model_ref"]==old
 w["samples"][4]["status"]="clear";w["samples"][4]["distance"]=12.
 update_structures!(s,local_structures(structure_ground(2_000_000),w),receipt(1_000_000,2_000_000))
 @test "split_or_merge" in s["events"]
 @test count(x->x["kind"]=="obstacle" && x["status"]=="observed",s["models"])==2
 @test !any(x->x["model_ref"]==old,s["models"])
 update_structures!(s,local_structures(structure_ground(3_000_000),wall_samples()),receipt(2_000_000,3_000_000))
 @test count(x->x["kind"]=="obstacle",s["models"])==1
 @test "split_or_merge" in s["events"]
 update_structures!(s,local_structures(structure_ground(4_000_000),wall_samples()),nothing)
 @test "body_correspondence_unavailable" in s["events"]
 @test_throws ErrorException update_structures!(structure_memory("b"),local_structures(g,w),nothing)
 for t in 5:50
  update_structures!(s,local_structures(structure_ground(t*1_000_000),wall_samples()),receipt((t-1)*1_000_000,t*1_000_000))
 end
 @test length(s["models"])<=24
 @test all(length(x["points"])<=22 for x in s["models"])
 # Actual translation of actor-relative samples preserves correspondence.
 next=structure_ground(51_000_000);walls=wall_samples()
 for c in vcat(next["cells"],walls["samples"])
  x=c["distance"]*sind(c["angle"]);z=c["distance"]*cosd(c["angle"])-.1
  c["distance"]=hypot(x,z);c["angle"]=rad2deg(atan(x,z))
 end
 prior=only(filter(x->x["kind"]=="obstacle",s["models"]))["model_ref"]
 link=receipt(50_000_000,51_000_000);link["forward"]=.1
 update_structures!(s,local_structures(next,walls),link)
 @test only(filter(x->x["kind"]=="obstacle",s["models"]))["model_ref"]==prior
end
@testset "no path across an unresolved interval" begin
 s=ground_memory("a");g=structure_ground();update_ground!(s,g,nothing)
 move=D("energy"=>D("rows"=>[D("cost"=>1.) for _ in 1:5]))
 @test !isempty(ground_proposals(s,move))
 # The same coarse band can contain two pieces too distant to link.
 g["cells"][8]["distance"]=5.;g["cells"][9]["distance"]=6.
 s=ground_memory("a");update_ground!(s,g,nothing)
 update_structures!(s["structures"],local_structures(g,wall_samples()),nothing)
 proposals=ground_proposals(s,move)
 @test isempty(proposals)
 @test all(m["kind"]!="water" || m["status"]=="observed" for m in s["structures"]["models"])
 # Two multi-point components prohibit a single old path spanning both.
 model=only(s["models"]);model["current_points"]=[(0.,1.),(0.,2.),(0.,5.),(0.,6.)]
 s["structures"]["observation"]["groups"]=[D("kind"=>"worn_ground","points"=>[(0.,1.),(0.,2.)]),D("kind"=>"worn_ground","points"=>[(0.,5.),(0.,6.)])]
 @test isempty(ground_proposals(s,move))
end
@testset "actual narrow rock gate rays preserve opening" begin
 rocks=[(x=5sin(2pi*i/24),z=6-5cos(2pi*i/24),radius=.8,height=3.,color="gray") for i in 1:23]
 wall=lateral_obstacles(rocks,(0.,3.),180.,"gate")
 @test wall["samples"][4]["status"]=="clear"
 ob=local_structures(structure_ground(),wall)
 @test any(b->b["kind"]=="obstacle",ob["breaks"])
 @test all(!(any(p->p[1]<-.1,g["points"]) && any(p->p[1]>.1,g["points"])) for g in ob["groups"] if g["kind"]=="obstacle")
 @test all(b["passability"]=="unverified" for b in ob["breaks"])
end
