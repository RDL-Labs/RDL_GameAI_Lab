// Add physical objects; optional in-reach collection requires an explicit mode.
const fs=require('fs'),path=require('path');
const [base,out,dayArg='3',mode='placement']=process.argv.slice(2),days=Number(dayArg);
if(!base||!out||process.argv.length>6||!Number.isInteger(days)||days<1||days>90||!['placement','incidental'].includes(mode))
  throw Error('usage: prepare.cjs BASE_INPUT.json NEW_INPUT.json [DAYS=3] [placement|incidental]');
const input=JSON.parse(fs.readFileSync(base,'utf8')),s=input.scene;
if(s.loose_items?.length||s.portable_items?.length||s.world_history)throw Error('fresh map without loose items required');
const obstacles=[...(s.obstacles||[]),...(s.low_obstacles||[])],items=[];
for(const radius of [2,4,7,12,18])for(let j=0;j<12&&items.length<9;j++){
  const angle=j*Math.PI/6,x=s.home[0]+radius*Math.sin(angle),z=s.home[1]+radius*Math.cos(angle);
  if(obstacles.some(o=>Math.hypot(o.x-x,o.z-z)<o.radius+.6))continue;
  if(s.landscape){
    const river=12+5*Math.sin((z-6)/22+s.landscape.phase),width=1.2+.4*(1+Math.sin(z/13));
    if(Math.abs(x-river)<width/2+.6)continue;
  }
  if([...(s.food||[]),...items].some(o=>Math.hypot(o.x-x,o.z-z)<.8))continue;
  const id=items.length+1,kind=(id-1)%3+1;
  items.push({id,kind,x,z});
}
if(items.length!==9)throw Error('could not place nine separated, dry, accessible objects');
input.config.days=days;delete s.portable_items;s.loose_items=items;
delete s.configured_item_actions;
if(mode==='incidental')s.incidental_items=true;else delete s.incidental_items;
fs.mkdirSync(path.dirname(path.resolve(out)),{recursive:true});
fs.writeFileSync(out,JSON.stringify(input),{flag:'wx'});
console.log(JSON.stringify({base:path.resolve(base),output:path.resolve(out),days,
  kinds:{glowing_stone:3,shell:3,feather:3},food:'unchanged from base',
  collectionReward:mode==='incidental'?'weak novelty prior and observed outcome learning':'not assigned',
  automaticCollection:mode==='incidental'?'optional in-reach pickup candidates':'not connected',
  scriptedActions:0,operations:['pickup','drop','store','retrieve','give','offer','accept','decline'],items},null,2));
