# Local observer experiment. Fixed initial offer/placement only; responses use LW.
using JSON3, Test
length(ARGS)>=1 || error("usage: live_trade.jl NEW_OUTPUT [wall_seconds_per_step]")
const output=abspath(ARGS[1]);ispath(output)&&error("fresh output required");mkpath(output)
const wall_step=length(ARGS)>1 ? parse(Float64,ARGS[2]) : 1.0
const repo=normpath(joinpath(@__DIR__,"../.."))
# Load existing fixture helpers without executing their independent test suite.
const fixture_file=joinpath(repo,"experiments/portable_items/checks.jl")
include_string(Main,first(split(read(fixture_file,String),"@testset")),fixture_file)
include(joinpath(repo,"experiments/simple_language/reply_trade.jl"))
const fixture=item_fixture(objects=Any[],food_counts=[[20,0,0,0],[0,0,0,20],[0,0,0,0]],scene=(configured_negotiation=true,))
empty!(fixture.w.obstacles)
fixture.w.positions[ITEM_A]=(0.,0.);fixture.w.positions[ITEM_B]=(0.,.8);fixture.w.positions[ITEM_C]=(12.,12.)
const actors=[ITEM_A,ITEM_B]
const states=Dict(a=>LW.incidental_item_state(a,33) for a in actors)
const relations=Dict(a=>LW.social_relations_state(a;relational=true) for a in actors)
const frames=Any[];const events=Any[];const decisions=Any[]
const notes=["局所試験：配置・最初の提示・備蓄は固定。受諾・逆提案・拒否は既存LW判断。","倉庫非公開。生理・探索・移動・発話生成は今回の試験外。実時間待機は表示速度調整のみ。"]
function save_frame(now;done=false)
 rows=[(id=a,position=fixture.w.positions[a],body=Dict(string(k)=>getproperty(fixture.w.bodies[a],k) for k in fieldnames(typeof(fixture.w.bodies[a]))),held=fixture.w.inventory[a],stock=fixture.stores[a],action="wait",H=nothing) for a in actors]
 push!(frames,(us=now,actors=rows,stocks=Int[]))
 replay=(schema="lw-observer-v1",title="局所取引・進行中",day_us=17_280_000_000,sample_seconds=1,scene=(home=[0.,0.],food=Any[],obstacles=Any[],landscape=(extent=[-3.,3.,-3.,3.],)),actors=actors,frames=frames,events=events,decisions=decisions,notes=notes,live_status=done ? "completed" : "running")
 write(joinpath(output,"replay.tmp"),JSON3.write(replay));mv(joinpath(output,"replay.tmp"),joinpath(output,"replay.json");force=true)
end
function run_local_trade()
 save_frame(0);sleep(wall_step)
 # 暫定固定の開始提示。需要から自発生成した提案ではない。通常系に接続しない。
 receipt=item_act(fixture,ITEM_B,"item_offer",1_000_000;target=ITEM_A,give_food=[0,0,0,1],want_food=[1,0,0,0])
 @test receipt["status"]=="offered"
 push!(events,merge(receipt,Dict("us"=>1_000_000,"actor"=>ITEM_B,"action"=>"item_offer","configured_rule"=>"local_initial_offer","give_food"=>[0,0,0,1],"want_food"=>[1,0,0,0])))
 save_frame(1_000_000);sleep(wall_step)
 for step in 2:30
  now=step*1_000_000;LW.item_expire!(fixture.s,now)
  for actor in actors
   observed=item_view(fixture,actor;now,yaw=actor==ITEM_A ? 0. : 180.,open_stores=false)
   LW.item_social_observe!(states[actor],observed;relation=relations[actor])
   plan=LW.item_social_plan!(states[actor],observed,fixture.w.bodies[actor],nothing,fixture.foods.personal[actor],now;relation=relations[actor],allow_start=false)
   logs=get(get(relations[actor],"gradient_maps",Dict()),"records",Any[])
   if !isempty(logs)&&get(logs[end],"us",-1)==now
    push!(decisions,merge(deepcopy(logs[end]),Dict("actor"=>actor)))
   end
   plan===nothing&&continue
   response=reply_trade_execute!(fixture,actor,states[actor],relations[actor],plan,now)
   push!(events,merge(deepcopy(plan),response,Dict("us"=>now,"actor"=>actor,"target"=>get(plan,"partner",get(plan,"target",nothing)))))
  end
  item_checks(fixture);save_frame(now;done=step==30);sleep(wall_step)
 end
 write(joinpath(output,"completed.json"),JSON3.write((steps=30,events=length(events),counts=fixture.s["counts"])))
 println("COMPLETED ",JSON3.write(fixture.s["counts"]))
end
run_local_trade()
