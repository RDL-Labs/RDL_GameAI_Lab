function far_transfer_world!(input)
    s=input["scene"];hx,hz=Float64.(s["home"])
    # Rotate authored objects/resources/roads by 180 degrees around camp.
    for key in ("obstacles","low_obstacles"),o in get(s,key,Any[])
        o["x"]=2hx-o["x"];o["z"]=2hz-o["z"]
    end
    s["food"]=deepcopy(s["food"][7:9])
    for f in s["food"];f["x"]=2hx-f["x"];f["z"]=2hz-f["z"];end
    for road in s["artificial_roads"]
        road["cells"]=[[Int(2hx)-c[1]-1,Int(2hz)-c[2]-1] for c in road["cells"]]
    end
    for key in ("food_stages","nearby_food_layout");pop!(s,key,nothing);end
    s["reserve"]=fill(90.,3);s["initial_inventory"]=zeros(Int,3)
    s["name"]="rotated-far-food-transfer"
    s["transfer_world"]=D("rotation_degrees"=>180,"food"=>"far-only","body"=>"fresh-reserve-90")
    spec=JSON3.read(JSON3.write(s))
    obstacles=[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in spec.obstacles]
    @testset "new transfer world access" begin
        @test length(spec.food)==3
        for f in spec.food
            @test hypot(f.x-hx,f.z-hz)>18
            points=[(hx,hz),(hx,hz+10),(Float64(f.x),hz+10),(Float64(f.x),Float64(f.z))]
            for j in 1:3
                a,b=points[j],points[j+1]
                @test all(!segment_hit(a,b,o,.2) for o in obstacles)
                @test all(landscape_material(spec.landscape,(a[1]+t*(b[1]-a[1]),a[2]+t*(b[2]-a[2])))!="water" for t in 0:.025:1)
            end
        end
    end
end
