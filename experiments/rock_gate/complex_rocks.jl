# World authoring only. Connectivity witnesses are not supplied to the agents.
function complex_rocks!(input;natural=false)
    s=input["scene"];hx,hz=Float64.(s["home"])
    nextid=maximum([get(o,"world_id",0) for o in vcat(s["obstacles"],get(s,"low_obstacles",Any[]))];init=0)
    added=Any[]
    function add(x,z,r)
        hypot(x-hx,z-hz)>8+r || return
        any(f->hypot(x-f["x"],z-f["z"])<2+r,s["food"]) && return
        any(o->hypot(x-o["x"],z-o["z"])<r+o["radius"]+.15,s["obstacles"]) && return
        natural && any(o->hypot(x-o["x"],z-o["z"])<r+o["radius"]+.25,added) && return
        nextid+=1
        push!(added,D("x"=>x,"z"=>z,"radius"=>r,"height"=>2.5+.5mod(nextid,4),
            "color"=>iseven(nextid) ? "gray" : "ochre","solid"=>true,"kind"=>2,"world_id"=>nextid,"food_index"=>0))
    end
    if natural
        rng=MersenneTwister(20261027)
        # Unequal, irregular clumps with open space between them; no wall rows.
        for (cx,cz,n) in ((-8.,11.,7),(9.,13.,6),(-16.,19.,8),(16.,24.,7),
                          (1.,28.,5),(-21.,1.,6),(21.,2.,8),(6.,-15.,5))
            placed=0
            for attempt in 1:100
                placed>=n && break
                angle=360rand(rng);d=4sqrt(rand(rng));r=.45+1.05rand(rng)
                before=length(added);add(hx+cx+d*cosd(angle),hz+cz+.7d*sind(angle),r)
                placed+=Int(length(added)>before)
            end
        end
    else
    # Staggered partial ridges: each has a different gap, plus routes around both ends.
    for (row,(dz,gap)) in enumerate(((9.,-5.),(13.,5.),(17.,-4.),(21.,3.)))
        for dx in -18.:1.5:18.
            abs(dx-gap)<2.5 && continue
            add(hx+dx,hz+dz,.8+.1mod(row,2))
        end
    end
    # Distinct clusters on both flanks and behind camp, leaving the camp itself open.
    for (cx,cz) in ((-15.,-5.),(16.,-6.),(-22.,12.),(22.,20.),(5.,-13.))
        for (dx,dz,r) in ((0.,0.,1.4),(2.,1.,.9),(-1.5,2.,1.),(.5,3.,.7))
            add(hx+cx+dx,hz+cz+dz,r)
        end
    end
    end
    append!(s["obstacles"],added)
    s["complex_rocks"]=D("version"=>natural ? "irregular-clumps-v1" : "staggered-ridges-v1","added"=>length(added),"camp_clear_radius"=>8.)
    scene=JSON3.read(JSON3.write(s));circles=[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in scene.obstacles]
    # Conservative half-unit grid and .3 body margin, including dry ground and clear edges.
    point(k)=(hx+.5k[1],hz+.5k[2])
    valid(k)=begin
        p=point(k)
        -60<=k[1]<=60 && -40<=k[2]<=76 && landscape_material(scene.landscape,p)!="water" &&
            all(hypot(p[1]-o.x,p[2]-o.z)>o.radius+.3 for o in circles)
    end
    queue=[(0,0)];parents=Dict((0,0)=>(0,0));i=1
    while i<=length(queue)
        k=queue[i];i+=1
        for step in ((1,0),(-1,0),(0,1),(0,-1))
            q=(k[1]+step[1],k[2]+step[2])
            haskey(parents,q) && continue
            valid(q) && all(!segment_hit(point(k),point(q),o,.3) for o in circles) || continue
            parents[q]=k;push!(queue,q)
        end
    end
    paths=Any[]
    @testset "complex rocks and traversable food routes" begin
        @test length(added)>=(natural ? 35 : 60)
        @test valid((0,0))
        @test all(hypot(o["x"]-hx,o["z"]-hz)>8+o["radius"] for o in added)
        ids=[o["world_id"] for o in s["obstacles"]];@test length(ids)==length(unique(ids))
        for p in s["positions"]
            @test all(hypot(p[1]-o.x,p[2]-o.z)>o.radius+.3 for o in circles)
        end
        for f in scene.food
            target=(round(Int,2(f.x-hx)),round(Int,2(f.z-hz)))
            @test haskey(parents,target)
            haskey(parents,target) || error("food unreachable in authored map")
            points=Any[collect(point(target))];k=target
            while k!=(0,0);k=parents[k];push!(points,collect(point(k)));end
            push!(paths,D("food"=>[f.x,f.z],"length"=>.5(length(points)-1),"points"=>reverse(points)))
        end
    end
    D("added_rocks"=>length(added),"obstacles"=>length(circles),"grid_spacing"=>.5,"body_margin"=>.3,"paths"=>paths)
end
