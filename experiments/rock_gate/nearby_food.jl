# Authored learning environment, not an agent policy or preloaded route.
function nearby_food_layout!(input)
    scene=input["scene"]; hx,hz=Float64.(scene["home"])
    sites=[(hx-4,hz),(hx+4,hz),(hx,hz-4)]
    land=JSON3.read(JSON3.write(scene["landscape"]))
    objects=[RDLMigrationProbe.Circle(o["x"],o["z"],o["radius"]) for key in ("obstacles","low_obstacles") for o in get(scene,key,[]) if get(o,"solid",true)]
    cells=Set{Tuple{Int,Int}}()
    @testset "nearby finite food: short clear round trips" begin
        for p in sites
            @test 1.25<hypot(p[1]-hx,p[2]-hz)<=6
            @test all(!segment_hit((hx,hz),p,o,.2) for o in objects)
            @test all(landscape_material(land,(hx+t*(p[1]-hx),hz+t*(p[2]-hz)))!="water" for t in 0:.025:1)
            push!(scene["food"],D("x"=>p[1],"z"=>p[2],"stock"=>12,"renewable"=>false))
            for t in 0:.025:1
                x,z=hx+t*(p[1]-hx),hz+t*(p[2]-hz)
                push!(cells,(floor(Int,x),floor(Int,z)))
            end
        end
        # Exercise actual regeneration: exhausted finite sites must stay empty.
        food=JSON3.read(JSON3.write(scene["food"][end-2:end]))
        stock=zeros(Int,3)
        @test replenish_food!(stock,food;capacity=12)==0
        @test stock==[0,0,0]
    end
    push!(scene["artificial_roads"],D("cells"=>[collect(c) for c in sort(collect(cells))],"lifetime_days"=>3650))
    scene["nearby_food_layout"]=D("version"=>"finite-short-trips-v1","distance"=>4,"stock_per_site"=>12,"sites"=>[collect(p) for p in sites])
end
