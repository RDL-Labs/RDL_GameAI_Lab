using Random

const WORLD_GENERATOR="julia-lw-sparse-mt-v1"
function native_clock()
    (profile="human_scale_v1",day_us=17_280_000_000,
     phase_boundaries_us=[60_000_000,8_640_000_000,11_520_000_000,17_280_000_000],
     quiet_night_us=14_400_000_000,sleep_rest_us=2_880_000_000,
     real_m_per_world_m=10,real_seconds_per_world_second=5,
     reserve_rate_scale=64_000_000/17_280_000_000,strain_rate_scale=1/60,
     authority="simulation calibration, not human physiology")
end

function native_scene(seed::Int)
    seed>=0 || error("seed must be nonnegative")
    rng=MersenneTwister(seed)
    objects=[(x=0.,z=8.,radius=1.,height=12.,color="ochre",solid=true)]
    for _ in 1:22
        angle=deg2rad(-180+360rand(rng));distance=14+29rand(rng)
        push!(objects,(x=sin(angle)*distance,z=cos(angle)*distance,
            radius=.6+.9rand(rng),height=rand(rng,[2.,5.,8.]),
            color=rand(rng,["brown","green","gray"]),solid=true))
    end
    food=[(x=o.x+o.radius+1.,z=o.z,stock=12) for o in objects[2:9]]
    (name="julia_lw_sparse",positions=[[-2.,4.],[0.,4.],[2.,4.]],food=food,
     obstacles=objects[[1,2,5,8,11,15]],initial_inventory=[0,2,2],
     reserve=[30,90,90],home=[0,4],hearing=true,
     low_obstacles=[(x=x,z=4.5,radius=.15,height=.4) for x in (-2.,0.,2.)],
     ground_patches=[(x=0.,z=5.,radius=3.,resistance=4.),(x=12.,z=12.,radius=6.,resistance=3.)],
     hazards=[(x=0.,z=8.,vx=.05,vz=0.,start=60,stop=180)])
end
