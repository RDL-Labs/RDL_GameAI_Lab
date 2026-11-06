using Test
include("../../src/lw/LW.jl")
const D=LW.D;const B=LW.RDLBody
@testset "spoiled appearance is a shared negative value" begin
 m=D();body=B.Body(10.,0.,80.,0.);g=B.Digestion()
 w=LW.food_trade_weights(body,g;map=m)
 @test w[6]<0
 @test w[5]==0 # raw fish is an ingredient, not a spoiled appearance
 stock=zeros(Int,length(w));stock[1]=2
 @test LW.food_trade_gain(stock,w,1,0,6,1)<0
 @test LW.food_trade_gain(stock,w,1,0,6,2)<LW.food_trade_gain(stock,w,1,0,6,1)
 empty_items=D("held"=>Any[],"stored"=>Any[])
 after=copy(stock);after[6]=1
 @test LW.item_social_utility(empty_items,after,Dict(),w)<LW.item_social_utility(empty_items,stock,Dict(),w)
 prior=LW.food_condition_aversion(m,6)
 LW.food_condition_result!(m,6,false,1)
 @test LW.food_condition_aversion(m,6)>prior
 @test LW.food_trade_weights(body,g;map=m)[6]<w[6]
 @test LW.food_trade_weights(B.Body(10.,0.,5.,0.),g;map=m)[6]<0
end
@testset "desire chooses food rather than hard food order" begin
 map=D();a="npc_a";r=(inventory=Dict(a=>UInt8[1,3]),)
 facility=(id=1,x=0.,z=0.,work_radius=2.,processing_kinds=[3])
 stores=zeros(Int,length(B.FOOD_KIND_IDS));stores[[1,3]].=2;gut=B.Digestion();body=B.Body(10.,0.,60.,0.)
 choices=LW.food_desire_candidates(map,r,a,gut,60.,true,stores,[facility],(0.,0.))
 @test Set(c["method"] for c in choices)==Set(["meal:1:false","meal:3:false","meal:3:true","meal:defer"])
 loop=LW.BasicLoop("food";probabilistic=true,seed=1)
 @test all(>(0),LW.method_distribution(loop,choices))
 map["food_taste_experiences"]=D("red_round_fruit"=>D("base_liking"=>-2.),"brown_capped_ovoid"=>D("base_liking"=>2.))
 @test LW.food_expected_taste(map,3,gut,60.)>LW.food_expected_taste(map,1,gut,60.)
 old=LW.food_expected_taste(map,3,gut,60.);resize!(gut.recent,4);gut.recent.=[0.,0.,1.,0.]
 @test LW.food_expected_taste(map,3,gut,60.)==old
 fresh=B.Digestion()
 @test B.taste(gut,3,60.)==B.taste(fresh,3,60.)
 @test !any(c->get(c,"prepare",false),LW.food_desire_candidates(map,r,a,gut,60.,true,stores,[],(0.,0.)))
 @test !any(c->get(c,"prepare",false),LW.food_desire_candidates(map,r,a,gut,60.,true,stores,[facility],(0.,0.);processing=false))
 state=LW.food_desire_state();map["food_desire"]=state
 state["intent"]=only(c for c in choices if c["method"]=="meal:3:true")
 p=LW.food_desire_plan!(map,loop,r,a,gut,body,true,stores,[facility],(0.,0.),1;requested=true)
 @test p["action"]=="process_food" # fruit in hand does not cancel the desired prepared meal
 @test isempty(state["records"]) # no resampling while completing this feasible plan
 r.inventory[a]=UInt8[1,4]
 p=LW.food_desire_plan!(map,loop,r,a,gut,body,true,stores,[facility],(0.,0.),2)
 @test p["action"]=="eat" && p["food_kind"]==4
 LW.food_desire_result!(map,p,"ate",4,.3,3)
 @test state["intent"]===nothing
 state["intent"]=only(c for c in choices if c["method"]=="meal:3:true")
 r.inventory[a]=UInt8[1];stores[3]=0
 @test LW.food_desire_plan!(map,loop,r,a,gut,body,true,stores,[facility],(0.,0.),4)===nothing
 @test state["intent"]===nothing
end
@testset "meal aversion depends on a feasible alternative and reserve" begin
 a="npc_a";r=(inventory=Dict(a=>UInt8[3]),); stock=zeros(Int,length(B.FOOD_KIND_IDS))
 facility=(id=1,x=0.,z=0.,work_radius=2.,processing_kinds=[3])
 loop=LW.BasicLoop("food";probabilistic=true,seed=1)
 for (reserve,available) in ((80.,true),(80.,false),(10.,true))
  rows=LW.food_desire_candidates(D(),r,a,B.Digestion(),reserve,true,stock,available ? [facility] : [],(0.,0.))
  raw=findfirst(c->c["method"]=="meal:3:false",rows); p=LW.method_distribution(loop,rows)[raw]
  penalty=rows[raw]["alternative_penalty"]
  rows[raw]["priority"]+=penalty
  before=LW.method_distribution(loop,rows)[raw]
  println((reserve=reserve,workshop=available,before=before,after=p))
  if reserve==80. && available
   @test 0<p<before/2
  elseif !available
   @test p==before && penalty==0
  else
   @test p>0.1
  end
 end
end
@testset "same exchange, opposite personal tastes" begin
 body=B.Body(10.,0.,80.,0.);gut=B.Digestion();stock=[2,0,0,2,0,0,0,0]
 preference(fruit,meal)=D("food_taste_experiences"=>D("red_round_fruit"=>D("base_liking"=>fruit),"brown_meal"=>D("base_liking"=>meal)))
 weight(m)=LW.food_trade_weights(body,gut;map=m)
 # Give one fruit for one prepared acorn, evaluated separately by each observer.
 @test LW.food_trade_gain(stock,weight(preference(-1.,2.)),1,1,4,1)>0
 @test LW.food_trade_gain(stock,weight(preference(2.,-1.)),1,1,4,1)<0
 @test LW.food_taste_value(1.,80.)>LW.food_taste_value(1.,10.)
end
@testset "food composition in tasting, meals and exchange" begin
    sweet=B.Digestion(taste_preference=(0.6,-0.6,0.0))
    protein=B.Digestion(taste_preference=(-0.6,0.6,0.0))
    body=B.Body(10.,0.,80.,0.)
    @test all(x->all(>=(0),x) && isapprox(sum(x),1.),B.FOOD_COMPOSITION[[1,2,3,4,5,7]])
    for g in (sweet,protein), kind in (1,3,4,7)
        @test LW.food_expected_taste(D(),kind,g,80.)≈B.food_base_taste(g,kind)
    end
    subjective(g)=LW.food_trade_weights(body,g)
    @test subjective(sweet)[1]>subjective(protein)[1]
    @test subjective(sweet)[7]<subjective(protein)[7]
    @test B.taste(sweet,3,80.)<B.taste(sweet,4,80.)
    liking=B.ingest!(sweet,1,80.,0)
    @test last(sweet.records).composition==B.FOOD_COMPOSITION[1]
    @test last(sweet.records).liking==liking && sweet.gut==1.
end
@testset "body demand changes with absorbed food independently of preference" begin
    body=B.Body(10.,0.,80.,0.); fruit=B.Digestion(); fish=B.Digestion()
    for (g,kind) in ((fruit,1),(fish,7))
        B.ingest!(g,kind,80.,0)
        @test B.nutrient_need(g)==(0.,0.,0.)
        B.digest!(g,body,1800.);B.digest!(g,body,7200.)
        @test sum(g.gut_components)≈g.gut
    end
    @test B.nutrient_need(fruit)[2]>B.nutrient_need(fish)[2]
    @test B.nutrient_need(fish)[1]>B.nutrient_need(fruit)[1]
    @test LW.food_trade_weights(body,fruit)==LW.food_trade_weights(body,fish)
    @test B.taste(fish,1,80.)>B.taste(fruit,1,80.)
    m=D("food_taste_experiences"=>D("roasted_fish"=>D("base_liking"=>1.5)))
    @test LW.food_expected_taste(m,7,fruit,80.)==1.5
    @test fruit.taste_preference==fish.taste_preference
    @test B.digestion_snapshot(fruit)["eaten"]==1
end
@testset "taste acquired under need persists after the need subsides" begin
 m=D();g=B.Digestion();g.nutrient_stores=(0.5,0.,0.25)
 liking=B.ingest!(g,7,80.,0)
 LW.food_remember_taste!(m,7,2,liking,0)
 fresh=B.Digestion()
 @test m["food_taste_experiences"]["roasted_fish"]["mean_liking"]==liking
 @test liking>B.taste(fresh,7,80.)
 @test LW.food_expected_taste(m,7,g,80.)==liking
 @test LW.food_expected_taste(m,7,fresh,80.)==liking
 @test LW.food_expected_taste(m,7,fresh,10.)==liking
 # The remembered request survives satiety changes, but the next sensory
 # outcome can disappoint it and must lower the subsequent expectation.
 actual=B.ingest!(fresh,7,80.,1)
 @test actual<liking
 updated=deepcopy(m)
 LW.food_remember_taste!(updated,7,2,actual,1)
 @test LW.food_expected_taste(updated,7,fresh,80.)≈(liking+actual)/2
 @test LW.food_expected_taste(updated,7,fresh,80.)<liking
 @test LW.food_trade_weights(B.Body(10.,0.,80.,0.),fresh;map=m)[7]==LW.food_trade_weights(B.Body(10.,0.,80.,0.),g;map=m)[7]
 LW.food_remember_taste!(m,7,2,-0.1,1)
 @test m["food_taste_experiences"]["roasted_fish"]["mean_liking"]≈(liking-0.1)/2
end
@testset "value raw ingredients by their feasible uses" begin
    g=B.Digestion();body=B.Body(10.,0.,80.,0.)
    workshop=(id=1,x=0.,z=0.,work_radius=2.,processing_kinds=[3,5])
    k=(actor="npc_a",foods=nothing,facilities=[workshop],position=(0.,0.),processing=true)
    w=LW.food_trade_weights(body,g;kitchen=k)
    absent=LW.food_trade_weights(body,g;kitchen=merge(k,(position=(8.,0.),)))
    @test w[3]>absent[3]
    @test 0<w[5]<w[7] && absent[5]==0
    @test absent==LW.food_trade_weights(body,g;kitchen=merge(k,(processing=false,)))
    m=D("food_taste_experiences"=>D("brown_capped_ovoid"=>D("mean_liking"=>5.0)))
    @test LW.food_trade_weights(body,g;map=m,kitchen=k)[3]==LW.food_trade_weights(body,g;map=m)[3]
end
