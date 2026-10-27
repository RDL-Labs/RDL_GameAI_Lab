const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const run=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const read=f=>JSON.parse(fs.readFileSync(path.join(run,'ordinary',f)));
const input=read('input.json'),r=read('run/result.json'),ps=read('positions.json').filter(p=>p.actor==='npc_c'),es=r.events.filter(e=>e.actor==='npc_c');
const summaries=[];let svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="760"><rect width="1200" height="760" fill="#f6f7f9"/><g font-family="Yu Gothic,Meiryo,sans-serif" fill="#263747"><text x="30" y="35" font-size="24">C：2日目からの経路</text><text x="30" y="65" font-size="15">青＝食料目的　橙＝帰還目的　赤四角＝食料初期位置　灰＝岩　◆＝拠点　北が上</text>'];
for(const day of [2,3]){
 const lo=(day-1)*17280,hi=day*17280,rows=ps.filter(p=>p.sec>=lo&&p.sec<=hi),ox=30+(day-2)*590;
 const X=x=>ox+40+(x+40)*8,Y=z=>110+(45-z)*8;
 svg.push(`<rect x="${ox}" y="85" width="570" height="600" rx="10" fill="white"/><text x="${ox+20}" y="108" font-size="20">${day}日目</text>`);
 for(let x=-40;x<=20;x+=10)svg.push(`<path d="M${X(x)},${Y(45)}V${Y(-15)}" stroke="#e7ebef"/><text x="${X(x)}" y="${Y(-15)+18}" font-size="12">${x}</text>`);
 for(let z=-10;z<=40;z+=10)svg.push(`<path d="M${X(-40)},${Y(z)}H${X(20)}" stroke="#e7ebef"/><text x="${X(-40)-25}" y="${Y(z)}" font-size="12">${z}</text>`);
 for(const o of input.scene.obstacles.filter(o=>o.x>=-40&&o.x<=20&&o.z>=-15&&o.z<=45))svg.push(`<circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${o.radius*8}" fill="#b9c0c5"/>`);
 for(const f of input.scene.food)svg.push(`<rect x="${X(f.x)-3}" y="${Y(f.z)-3}" width="6" height="6" fill="#c7424d"/>`);
 svg.push(`<path d="M${X(0)},${Y(6)-6}l6,6 -6,6 -6,-6Z" fill="#163d68"/>`);
 for(let i=1;i<rows.length;i++){const a=rows[i-1],b=rows[i];svg.push(`<path d="M${X(a.position[0])},${Y(a.position[1])}L${X(b.position[0])},${Y(b.position[1])}" stroke="${es.findLast(e=>e.us<(b.sec*1e6))?.purpose_family==='home'?'#df7b28':'#277db6'}" stroke-width="1.3" stroke-opacity=".7" fill="none"/>`);}
 const marks=day===2?[[17580,'① 近隣で3個取得'],[22020,'② 長時間休息'],[25920,'③ 帰還継続'],[34560,'④ 2日目終了']]:[[34560,'④ 開始'],[43200,'⑤ 北側へ'],[48960,'⑥ 西で休息・終了']];
 const sampled=[];
 for(const [t,label]of marks){const p=rows.reduce((a,b)=>Math.abs(b.sec-t)<Math.abs(a.sec-t)?b:a);sampled.push({label,...p});svg.push(`<circle cx="${X(p.position[0])}" cy="${Y(p.position[1])}" r="4" fill="#111"/><text x="${X(p.position[0])+6}" y="${Y(p.position[1])-7}" font-size="13" stroke="white" stroke-width="3" paint-order="stroke">${label}</text>`);}
 const returns=rows.filter(p=>p.sec>=25920),nearest=returns.reduce((a,b)=>Math.hypot(...[b.position[0],b.position[1]-10.83])<Math.hypot(a.position[0],a.position[1]-10.83)?b:a);
 const durations={};for(let i=0;i<es.length;i++){const e=es[i],start=Math.max(lo,e.us/1e6),end=Math.min(hi,(es[i+1]?.us??51840e6)/1e6);if(end>start){const k=e.purpose_family+':'+e.action;durations[k]=(durations[k]||0)+end-start;}}
 summaries.push({day,marks:sampled,nearest_gate_sample:nearest,durations,end_inventory:r.daily[day-1].physical.npc_c.inventory});
 svg.push(`<text x="${ox+20}" y="660" font-size="15">終了時の所持食料：${r.daily[day-1].physical.npc_c.inventory}個</text>`);
}
svg.push('<text x="30" y="720" font-size="15">60秒間隔の位置を直線で接続。細かな迂回は再現していません。取得などの印は最寄り位置標本です。</text></g></svg>');
fs.writeFileSync(path.join(out,'c-path.svg'),svg.join('\n'));fs.writeFileSync(path.join(out,'c-trace.json'),JSON.stringify(summaries,null,2));
sharp(Buffer.from(svg.join('\n'))).png().toFile(path.join(out,'c-path.png')).then(()=>console.log(JSON.stringify(summaries)));
