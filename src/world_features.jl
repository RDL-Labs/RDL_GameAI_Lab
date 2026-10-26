module WorldFeatures
using Random
const TREE=UInt8(1); const ROCK=UInt8(2); const OTHER=UInt8(3)
const COLORS=("brown","green","gray","ochre")
const GRASS_COLORS=("green","yellow_green","brown_green")
"Stable individual traits; old geometry is only narrowed, so existing spawn clearances survive."
function enrich_scene(scene;seed=20261005)
    rng=MersenneTwister(seed+1701)
    food=collect(scene.food)
    serial=0
    function enrich(o)
        serial+=1
        color=hasproperty(o,:color) ? String(o.color) : "gray"
        kind=color in ("brown","green") ? TREE : color=="gray" ? ROCK : OTHER
        radius=Float64(o.radius)*(kind==OTHER ? 1. : .7+.3rand(rng))
        height=Float64(o.height)*(kind==OTHER ? 1. : .8+.4rand(rng))
        shade=kind==TREE ? rand(rng,("brown","green")) : kind==ROCK ? rand(rng,("gray","ochre")) : color
        # Resource identity is world-only. Food stock remains the authoritative fruit amount.
        index=kind==TREE && !isempty(food) ? argmin([hypot(f.x-o.x,f.z-o.z) for f in food]) : 0
        index>0 && hypot(food[index].x-o.x,food[index].z-o.z)>3 && (index=0)
        merge((;pairs(o)...),(x=Float64(o.x),z=Float64(o.z),radius=radius,height=height,color=shade,
         solid=hasproperty(o,:solid) ? Bool(o.solid) : true,
         kind=kind,world_id=serial,food_index=index))
    end
    obstacles=map(enrich,scene.obstacles); low=map(enrich,scene.low_obstacles)
    # Different trees can offer different quantities without adding one object per fruit.
    richfood=[(x=Float64(f.x),z=Float64(f.z),stock=max(1,round(Int,f.stock*(.5+rand(rng))))) for f in food]
    merge((;pairs(scene)...),(obstacles=obstacles,low_obstacles=low,food=richfood,world_features="color-size-patches-v1"))
end
struct GrassTraits
    color::Vector{UInt8}
    height::Vector{Float64}
    density::Vector{Float64}
    patch::Vector{Int32}
end
"A patch is up to 4x4 two-metre cells; holes retain the original water/rock mask."
function grass_traits(nx,nz;seed=20261005)
    rng=MersenneTwister(seed+2903); px=cld(nx,4); pz=cld(nz,4)
    colors=rand(rng,UInt8[1,2,3],px*pz)
    heights=.15 .+ .85rand(rng,px*pz); densities=.4 .+ .6rand(rng,px*pz)
    ids=Int32[div(mod(k-1,nx),4)+1+div(div(k-1,nx),4)*px for k in 1:nx*nz]
    GrassTraits(colors[ids],heights[ids],densities[ids],ids)
end
end
