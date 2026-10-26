# World-authoring controls; no stage labels are supplied to action selection.
function staged_food_layout!(input)
    s=input["scene"];x,z=Float64.(s["home"])
    # The existing branching roads provide the outer routes. Add stepping stones
    # along those roads, rather than jumping directly from radius 4 to 20+.
    tiers=[[(x-4,z),(x+4,z),(x,z-4)],
           [(x-5,z-10),(x,z-12),(x+4,z-10)],
           [(x-8,z-18),(x,z-24),(x+6,z-18)]]
    s["food"]=[D("x"=>p[1],"z"=>p[2],"stock"=>tier==1 ? 12 : 24,"renewable"=>tier==3)
        for (tier,points) in enumerate(tiers) for p in points]
    cells=Set{Tuple{Int,Int}}()
    for p in tiers[1],t in 0:.025:1
        push!(cells,(floor(Int,x+t*(p[1]-x)),floor(Int,z+t*(p[2]-z))))
    end
    push!(s["artificial_roads"],D("cells"=>[collect(c) for c in sort(collect(cells))],"lifetime_days"=>3650))
    s["food_stages"]=D("version"=>"three-distance-tiers-v1","sites"=>[[collect(p) for p in points] for points in tiers],
        "stocks"=>[12,24,24],"renewable"=>[false,false,true])
end

function distinctive_landmarks!(input)
    s=input["scene"];x,z=Float64.(s["home"])
    # Explicit world IDs remain unique after random world enrichment.
    objects=vcat(s["obstacles"],get(s,"low_obstacles",Any[]))
    nextid=maximum([get(o,"world_id",0) for o in objects];init=0)
    authored=Any[]
    function add(dx,dz,r,h,color,kind)
        nextid+=1
        push!(authored,D("x"=>x+dx,"z"=>z+dz,"radius"=>r,"height"=>h,"color"=>color,
            "kind"=>kind,"solid"=>true,"world_id"=>nextid,"food_index"=>0))
    end
    # West: crescent of ochre rocks. East: two ordered rows of trees.
    for theta in (-70,-35,0,35,70)
        add(-11-3cosd(theta),-2+3sind(theta),.65,2.5,"ochre",2)
    end
    for dz in (-6,-3,0,3,6),dx in (10,12)
        add(dx,dz,.45,5.,"green",1)
    end
    # South: unequal paired rocks, framing but not blocking the central road.
    add(-2.5,-15,.8,3.,"gray",2);add(2.5,-15,1.,4.,"ochre",2)
    append!(s["obstacles"],authored)
    s["distinctive_landmarks"]=D("version"=>"west-crescent-east-grove-south-pair-v1",
        "world_ids"=>[o["world_id"] for o in authored])
end

function check_staged_world(input)
    s=JSON3.read(JSON3.write(input["scene"]));home=Tuple(Float64.(s.home))
    obstacles=[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in s.obstacles]
    @testset "staged world access and finite supplies" begin
        @test length(s.food)==9
        @test all(!f.renewable for f in s.food[1:6])
        @test all(f.renewable for f in s.food[7:9])
        # Author-known access routes verify geometry; agents must discover them.
        for (i,f) in enumerate(s.food)
            p=(Float64(f.x),Float64(f.z))
            route=i<=3 ? [home,p] : [home,(home[1],home[2]-10),(p[1],home[2]-10),p]
            for j in 1:length(route)-1
                a,b=route[j],route[j+1]
                @test all(!segment_hit(a,b,o,.2) for o in obstacles)
                @test all(landscape_material(s.landscape,(a[1]+t*(b[1]-a[1]),a[2]+t*(b[2]-a[2])))!="water" for t in 0:.025:1)
            end
        end
        stock=zeros(Int,9);replenish_food!(stock,s.food;capacity=12)
        @test stock[1:6]==zeros(Int,6)
        @test stock[7:9]==fill(12,3)
        ids=[o.world_id for o in s.obstacles if hasproperty(o,:world_id)]
        @test length(ids)==length(unique(ids))
    end
end
