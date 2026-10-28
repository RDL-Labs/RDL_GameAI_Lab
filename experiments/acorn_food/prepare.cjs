const fs=require('fs'),path=require('path');
const out=process.argv[2];if(!out)throw Error('usage: prepare.cjs INPUT.json');
const input=JSON.parse(fs.readFileSync(path.join(__dirname,'../rock_gate/channel_trial_spec.json'))),s=input.scene;
Object.assign(input.config,{days:3,seed:20261007,digestion:'ordinary'});
Object.assign(s,{typed_food:true,mb_navigation_mode:'goal_cues',mb_exploration_relations:true,mb_scene_abstraction:'standard',
 wildlife:{enabled:true,count:30,seed:20261028,grass_scale:1,spawn_min_distance:8,spawn_max_distance:40}});
// A taught recipe and one carried raw portion each expose processing immediately.
s.positions=[[s.home[0],s.home[1]+.3],[s.home[0]+.3,s.home[1]],[s.home[0]-.3,s.home[1]]];
s.initial_inventory=[1,1,1];s.initial_inventory_kinds=[[3],[3],[3]];s.reserve=[70,70,70];
for(const f of s.food){f.food_kind=1;f.appearance='red_round_fruit';}
const obstacles=[...s.obstacles,...s.low_obstacles],sites=[];
for(const radius of [4,7,10])for(let i=0;i<12&&sites.length<8;i++){
 const angle=i*Math.PI/6,x=s.home[0]+radius*Math.cos(angle),z=s.home[1]+radius*Math.sin(angle);
 if(obstacles.some(o=>Math.hypot(o.x-x,o.z-z)<o.radius+1.5))continue;
 const river=12+5*Math.sin((z-6)/22+s.landscape.phase),width=1.2+.4*(1+Math.sin(z/13));
 if(Math.abs(x-river)<width/2+1)continue;
 if([...s.food,...sites].some(f=>Math.hypot(f.x-x,f.z-z)<1.5))continue;
 sites.push({x,z,stock:24,renewable:false,food_kind:3,appearance:'brown_capped_ovoid'});
}
if(sites.length!==8)throw Error('need 8 separated accessible acorn sites');
s.food.push(...sites);
fs.writeFileSync(out,JSON.stringify(input),{flag:'wx'});
console.log(JSON.stringify({days:3,humans:3,rabbits:30,fruit:s.food.filter(f=>f.food_kind===1).reduce((v,f)=>v+f.stock,0),
 acorns:192,carriedRaw:3,regrowth:false,processing:'at camp, 120 work ticks per portion',decay:false,
 liking:{fruit:1,meat:1.5,acornMeal:.45},digestion:'on',seed:input.config.seed,sites},null,2));
