const $=id=>document.getElementById(id),ctx=$('canvas').getContext('2d');
let data=null,index=0,playing=false,last=0,carry=0;
const colors={npc_a:'#68dbc6',npc_b:'#f4be69',npc_c:'#b7a5ff',ochre:'#d5aa53',green:'#538962',brown:'#9c775a',gray:'#89939b'};
function dot(x,y,r,color){ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fillStyle=color;ctx.fill();}
function line(x,y,a,b,color){ctx.strokeStyle=color;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(a,b);ctx.stroke();}
function render(){
 if(!data)return;ctx.clearRect(0,0,900,650);const g=data.groups[index],id=$('agent').value,v=LWReplay.agentView(data,index,id);
 $('seek').value=index;$('time').textContent=`Day ${Math.floor(g.time/64000000)+1} · ${(g.time%64000000/1000000).toFixed(2)}秒 · ${index+1}/${data.groups.length}観測枠`;
 $('detail').textContent=JSON.stringify({agent:id,observation:v.packet.observation_id,pose:v.packet.pose_ref,command:v.command.kind,amount:v.command.amount,reason:v.command.reason,result:v.result.status,model_ref:v.model_ref,learning_records:v.learning_count,food_coverage:v.packet.food.coverage,visible_food:v.packet.food.visible.length},null,2);
 if($('view').value==='world'){
  const w=LWReplay.worldView(data,index);const pts=[...w.objects,...w.patches,...Object.values(w.trails).flat()];
  const extent=Math.max(48,...pts.map(p=>Math.max(Math.abs(p.x),Math.abs(p.z))))+4,s=300/extent,X=x=>450+x*s,Y=z=>325-z*s;
  for(let a=-Math.ceil(extent/10)*10;a<=extent;a+=10){line(X(a),0,X(a),650,'#203d4b');line(0,Y(a),900,Y(a),'#203d4b');}
  for(const o of w.objects)dot(X(o.x),Y(o.z),o.radius*s,colors[o.color]||'#89939b');
  for(const p of w.patches){dot(X(p.x),Y(p.z),4,p.stock>0?'#f1d46d':'#465661');ctx.fillStyle='#dce8ed';ctx.fillText(p.stock,X(p.x)+6,Y(p.z));}
  for(const [a,t] of Object.entries(w.trails)){for(let j=1;j<t.length;j++)line(X(t[j-1].x),Y(t[j-1].z),X(t[j].x),Y(t[j].z),colors[a]);const b=w.bodies[a];dot(X(b.x),Y(b.z),6,colors[a]);line(X(b.x),Y(b.z),X(b.x)+Math.sin(b.yaw*Math.PI/180)*17,Y(b.z)-Math.cos(b.yaw*Math.PI/180)*17,colors[a]);ctx.fillStyle=colors[a];ctx.fillText(a,X(b.x)+8,Y(b.z)-8);}
  $('legend').textContent='実験者用全景 · 線＝軌跡／黄点＝資源／数値＝残量／塔＝黄土色。身体は操作後の状態。';
 }else{
  const p=v.packet,s=20,X=r=>450+r*s,Y=f=>570-f*s;
  for(let d=3;d<=12;d+=3){ctx.strokeStyle='#355362';ctx.beginPath();ctx.arc(450,570,d*s,Math.PI,2*Math.PI);ctx.stroke();}
  for(const o of p.movement_surface.obstacles.items)dot(X(o.right),Y(o.forward),5,'#df9389');
  for(const f of p.food.visible)dot(X(f.right),Y(f.forward),7,'#f1d46d');
  for(const f of p.skyline.features){const a=(f.azimuth[0]+f.azimuth[1])/2*Math.PI/180,r={near:100,mid:190,far:285}[f.range_band];dot(450+Math.sin(a)*r,570-Math.cos(a)*r,3,colors[f.color]||'#ddd');}
  dot(450,570,8,colors[id]);$('legend').textContent='身体相対の取得情報 · 食料/障害物は局所距離。skyline点の半径はnear/mid/farの模式表示で、真の距離ではありません。';
 }
}
async function load(buffer,gz){try{playing=false;$('play').textContent='再生';if(gz)buffer=await new Response(new Blob([buffer]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();data=LWReplay.parse(new TextDecoder().decode(buffer));index=0;carry=0;$('seek').max=data.groups.length-1;$('status').textContent=data.complete?'完了ログ':'未完了ログ：保存済みの完全な観測枠のみ';render();}catch(e){data=null;$('status').textContent=e.message;ctx.clearRect(0,0,900,650);$('detail').textContent='';}}
$('demo').onclick=async()=>{try{const r=await fetch('demo.jsonl.gz');if(!r.ok)throw Error('サンプルを取得できません');await load(await r.arrayBuffer(),true);}catch(e){$('status').textContent=e.message;}};
$('file').onchange=async e=>{const f=e.target.files[0];if(f)await load(await f.arrayBuffer(),f.name.endsWith('.gz'));};
$('play').onclick=()=>{if(!data)return;playing=!playing;carry=0;$('play').textContent=playing?'停止':'再生';};
$('step').onclick=()=>{if(data){playing=false;$('play').textContent='再生';index=Math.min(index+1,data.groups.length-1);render();}};
$('reset').onclick=()=>{index=0;carry=0;render();};$('seek').oninput=e=>{index=+e.target.value;carry=0;render();};$('view').onchange=render;$('agent').onchange=render;
function tick(t){if(playing&&data){carry+=(t-last)*1000*Number($('speed').value);let changed=false;while(index<data.groups.length-1&&carry>=data.groups[index+1].time-data.groups[index].time){carry-=data.groups[index+1].time-data.groups[index].time;index++;changed=true;}if(changed)render();if(index===data.groups.length-1){playing=false;$('play').textContent='再生';}}last=t;requestAnimationFrame(tick);}requestAnimationFrame(tick);
if(new URLSearchParams(location.search).has('demo')) document.getElementById('demo').click();
