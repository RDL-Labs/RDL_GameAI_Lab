# World-authored experimental layout. Route metadata is observer-only.
function food_road_layout!(input;enabled=true)
    home=Float64.(input["scene"]["home"]);x,z=home
    junction=[x,z-10]
    branches=[[[x,z],junction,[x-8,z-10],[x-8,z-18]],
              [[x,z],junction,[x,z-24]],
              [[x,z],junction,[x+6,z-10],[x+6,z-18]]]
    cells=Set{Tuple{Int,Int}}()
    segments=Set{Tuple{Tuple{Float64,Float64},Tuple{Float64,Float64}}}()
    for path in branches, i in 1:length(path)-1
        a,b=path[i],path[i+1];push!(segments,(Tuple(a),Tuple(b)))
        dx,dz=b.-a;length2=dx^2+dz^2
        for cx in floor(Int,min(a[1],b[1])-1):ceil(Int,max(a[1],b[1])+1),
            cz in floor(Int,min(a[2],b[2])-1):ceil(Int,max(a[2],b[2])+1)
            px,pz=cx+.5,cz+.5
            t=clamp(((px-a[1])*dx+(pz-a[2])*dz)/length2,0.,1.)
            hypot(px-a[1]-t*dx,pz-a[2]-t*dz)<=1. && push!(cells,(cx,cz))
        end
    end
    # Same food sites/stock in both road-on and road-off conditions.
    input["scene"]["food"]=[D("x"=>last(path)[1],"z"=>last(path)[2],"stock"=>24) for path in branches]
    enabled && push!(input["scene"]["artificial_roads"],D("cells"=>[collect(c) for c in sort(collect(cells))],"lifetime_days"=>3650))
    (enabled=enabled,width=2.,branches=branches,cells=sort(collect(cells)),segments=sort(collect(segments)),junction=junction)
end

function check_food_roads(input,layout)
    spec=JSON3.read(JSON3.write(input))
    obstacles=[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in spec.scene.obstacles if o.height>=1]
    @testset "food roads: connected dry routes to every food site" begin
        @test length(spec.scene.food)==length(layout.branches)==3
        @test all(f.stock==24 for f in spec.scene.food)
        for (a,b) in layout.segments
            @test all(!segment_hit(a,b,o,.2) for o in obstacles)
            @test all(landscape_material(spec.scene.landscape,(a[1]+t*(b[1]-a[1]),a[2]+t*(b[2]-a[2])))!="water" for t in 0:.02:1)
        end
        cells=Set(layout.cells);seen=Set{Tuple{Int,Int}}();todo=[(floor(Int,spec.scene.home[1]),floor(Int,spec.scene.home[2]))]
        while !isempty(todo)
            c=pop!(todo);c in seen && continue;c in cells || continue;push!(seen,c)
            for d in ((-1,0),(1,0),(0,-1),(0,1));push!(todo,(c[1]+d[1],c[2]+d[2]));end
        end
        @test seen==cells
        @test all((floor(Int,f.x),floor(Int,f.z)) in seen for f in spec.scene.food)
        wear=GroundWear(Int(spec.clock.day_us));place_roads!(wear,spec.scene.artificial_roads)
        @test wear_factor(wear,(0.,.5))==(layout.enabled ? .5 : 1.)
        @test all(wear_factor(wear,(f.x,f.z))==(layout.enabled ? .5 : 1.) for f in spec.scene.food)
        @test all(landscape_material(spec.scene.landscape,(c[1]+.5,c[2]+.5))!="water" for c in cells)
    end
end

function render_food_roads(path,input,layout)
    # Exact authored cells and obstacles, north at top. Not an agent's internal map.
    xy(x,z)=(400+20x,320-20z)
    svg=String["<svg xmlns='http://www.w3.org/2000/svg' width='800' height='800' viewBox='0 0 800 800'><rect width='800' height='800' fill='#eef2e6'/><g font-family='sans-serif' fill='#24372f'>",
        "<text x='30' y='32' font-size='23'>Branching food roads / narrow gate</text>",
        "<text x='30' y='57' font-size='14'>World layout: 3 food sites, 24 units each; road lifetime 3650 days</text>"]
    for road in input["scene"]["artificial_roads"], c in road["cells"]
        px,py=xy(c[1],c[2]+1);push!(svg,"<rect x='$px' y='$py' width='20' height='20' fill='#cbb78e'/>")
    end
    for o in input["scene"]["obstacles"]
        px,py=xy(o["x"],o["z"]);80<py<790 && 0<px<800 || continue
        color=get(o,"light_source",0)>0 ? "#e5981d" : "#798079"
        push!(svg,"<circle cx='$px' cy='$py' r='$(20o["radius"])' fill='$color'/>")
    end
    for (i,f) in enumerate(input["scene"]["food"])
        px,py=xy(f["x"],f["z"]);push!(svg,"<circle cx='$px' cy='$py' r='9' fill='#bf463c'/><text x='$(px+13)' y='$(py+5)' font-size='15'>Food $i (24)</text>")
    end
    px,py=xy(input["scene"]["home"]...);push!(svg,"<circle cx='$px' cy='$py' r='6' fill='#225b8b'/><text x='$(px+10)' y='$py' font-size='15'>Home</text>")
    push!(svg,"<text x='30' y='770' font-size='14'>Road surface does not remove rocks. The existing narrow opening is unchanged.</text></g></svg>")
    write(path,join(svg,"\n"))
end
