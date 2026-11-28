using Test, Random, JSON3
include("../../src/lw/configured_paths/fire_rest_local.jl")
# 抽出した休息場所選択モデル。全員に既知の同じ候補を与える実験設定。
# 自宅・現在地・焚火周囲を各1候補とし、周囲の点数による重み水増しを避ける。
const FIRE_REST_FIXTURE=(seeds=200,actors=4,episodes=40,travel_cost=.12,home_value=.20,
    speed=.5,rest_ticks=12,arrival=.2)
function rest_trial(seed,enabled;safety=1.)
    rng=MersenneTwister(seed);cfg=FIRE_REST_FIXTURE
    homes=[(6cospi(i/2),6sinpi(i/2)) for i in 0:3]
    positions=copy(homes);selected=zeros(Int,3);near_ticks=0;gather_ticks=0;total_ticks=0
    for episode in 1:cfg.episodes
        targets=Tuple{Float64,Float64}[]
        for actor in 1:cfg.actors
            p=positions[actor];radius=hypot(p...)
            ring=radius>0 ? (2p[1]/radius,2p[2]/radius) : (2.,0.)
            sites=[p,homes[actor],ring]
            base=[0.,cfg.home_value,0.]
            scores=[base[j]-cfg.travel_cost*hypot(sites[j][1]-p[1],sites[j][2]-p[2])+
                configured_fire_rest_bias(hypot(sites[j]...),safety;enabled) for j in 1:3]
            weights=exp.(scores.-maximum(scores));probs=weights/sum(weights)
            chosen=min(searchsortedfirst(cumsum(probs),rand(rng)),3)
            selected[chosen]+=1;push!(targets,sites[chosen])
        end
        # 同期した局所移動・待機。通常の身体/障害物/取引スケジューラではない。
        rested=zeros(Int,cfg.actors)
        for tick in 1:80
            for actor in 1:cfg.actors
                p=positions[actor];q=targets[actor];dx,dz=q[1]-p[1],q[2]-p[2];d=hypot(dx,dz)
                if d>cfg.arrival
                    stride=min(cfg.speed,d);positions[actor]=(p[1]+stride*dx/d,p[2]+stride*dz/d)
                else
                    rested[actor]+=1
                end
            end
            total_ticks+=1
            nearby=count(p->1.2<hypot(p...)<=3.,positions)
            near_ticks+=nearby;gather_ticks+=nearby>=2
            minimum(rested)>=cfg.rest_ticks && break
        end
    end
    (selected=selected,near_ticks=near_ticks,gather_ticks=gather_ticks,total_ticks=total_ticks)
end
@testset "weak fire rest bias" begin
    @test configured_fire_rest_bias(2.,1.)==0
    @test configured_fire_rest_bias(nothing,1.;enabled=true)==0
    @test configured_fire_rest_bias(2.,0.;enabled=true)==0
    @test configured_fire_rest_bias(2.,1.;enabled=true)==.4
    @test configured_fire_rest_bias(0.,1.;enabled=true)<0
    @test configured_fire_rest_bias(10.,1.;enabled=true)==0
    @test rest_trial(1,false)==rest_trial(1,false)
    @test rest_trial(1,true;safety=0.)==rest_trial(1,false)
end
trials=[(off=rest_trial(seed,false),on=rest_trial(seed,true)) for seed in 1:FIRE_REST_FIXTURE.seeds]
summaries=Dict()
for mode in (:off,:on)
    runs=[getproperty(t,mode) for t in trials]
    summaries[string(mode)]=(selected=reduce(+,r.selected for r in runs),
        near_actor_ticks=sum(r.near_ticks for r in runs),gather_ticks=sum(r.gather_ticks for r in runs),total_ticks=sum(r.total_ticks for r in runs))
end
summaries["seeds_more_gathering"]=count(t->t.on.gather_ticks>t.off.gather_ticks,trials)
summaries["conditions"]=FIRE_REST_FIXTURE
println(JSON3.write(summaries))
length(ARGS)>0 && write(ARGS[1],JSON3.write(summaries))
