// Observer map, with 60-tick samples. This map is never supplied to policy.
const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=process.argv[2];
const input=JSON.parse(fs.readFileSync(path.join(root,'input.json'))),s=input.scene;
const ev=JSON.parse(fs.readFileSync(path.join(root,'evidence.json'))),g=ev.wildlife;
const csv=name=>fs.readFileSync(path.join(root,name),'utf8').trim().split(/\r?\n/).slice(1).map(l=>l.split(','));
const rabbits=csv('rabbit-trajectory.csv'),humans=csv('human-trajectory.csv'),grass=csv('grass-final.csv');
const [xmin,xmax,zmin,zmax]=s.landscape.extent,scale=760/(xmax-xmin);
const X=x=>50+(x-xmin)*scale,Y=z=>85+(zmax-z)*scale;
const v=[`<svg xmlns="http://www.w3.org/2000/svg" width="1240" height="920"><rect width="1240" height="920" fill="#f4f6f2"/><g font-family="Yu Gothic UI,Meiryo,sans-serif" fill="#223834"><text x="42" y="38" font-size="25">LW 放牧：兎30体＋人3体 / ${ev.days}日</text><text x="42" y="65" font-size="15">北が上。草の残量は終了時点、線は60tick間隔の移動記録。</text>`];
for(const [x,z,m,cap,remaining] of grass.map(r=>r.map(Number))){
 const c=m===1?'#bdddea':cap>0?`hsl(92 26% ${91-13*Math.min(1,remaining/cap)}%)`:'#e6e3d9';
 v.push(`<rect x="${X(x-1)}" y="${Y(z+1)}" width="${2*scale+.1}" height="${2*scale+.1}" fill="${c}"/>`);
}
// Continuous river geometry, independent of the coarser grass bookkeeping cells.
const river=[];
for(let z=zmin;z<=zmax;z+=.5){const x=12+5*Math.sin((z-6)/22+s.landscape.phase),w=1.2+.4*(1+Math.sin(z/13));river.push([x-w/2,z]);}
for(let z=zmax;z>=zmin;z-=.5){const x=12+5*Math.sin((z-6)/22+s.landscape.phase),w=1.2+.4*(1+Math.sin(z/13));river.push([x+w/2,z]);}
v.push(`<polygon points="${river.map(([x,z])=>X(x)+','+Y(z)).join(' ')}" fill="#bdddea"/>`);
for(const o of [...s.obstacles,...s.low_obstacles])v.push(`<circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${o.radius*scale}" fill="${o.kind===1?'#709574':o.color==='ochre'?'#ad9875':'#939c99'}" opacity=".8"/>`);
for(const a of g.final){
 const rows=rabbits.filter(r=>+r[1]===a.id);
 const points=[[...a.initial],...rows.map(r=>[+r[2],+r[3]])];
 v.push(`<polyline points="${points.map(([x,z])=>X(x)+','+Y(z)).join(' ')}" fill="none" stroke="#16836d" stroke-width="1.15" opacity=".65"/>`);
 v.push(`<circle cx="${X(a.initial[0])}" cy="${Y(a.initial[1])}" r="4" fill="none" stroke="#16836d"/><circle cx="${X(a.position[0])}" cy="${Y(a.position[1])}" r="3" fill="#075e4e"/><text x="${X(a.position[0])+5}" y="${Y(a.position[1])-4}" font-size="10">${a.id}</text>`);
}
const colors=['#2779b7','#ae7b14','#a95080'];
['npc_a','npc_b','npc_c'].forEach((name,i)=>v.push(`<polyline points="${[s.positions[i],...humans.filter(r=>r[1]===name).map(r=>[+r[2],+r[3]])].map(([x,z])=>X(x)+','+Y(z)).join(' ')}" fill="none" stroke="${colors[i]}" stroke-width="1.6" opacity=".85"/>`));
for(const f of s.food)v.push(`<rect x="${X(f.x)-4}" y="${Y(f.z)-4}" width="8" height="8" fill="#c34c42"/>`);
v.push(`<circle cx="${X(s.home[0])}" cy="${Y(s.home[1])}" r="7" fill="#e3902b" stroke="#fff" stroke-width="2"/>`);
const lines=[`生存：${g.alive} / ${g.count}`,`飢餓死：${g.starvation_deaths}`,`人を見た兎：${g.final.filter(a=>a.human_seen_ticks>0).length}体`,`警戒へ切替：${g.alert_entries}回`,`逃走へ切替：${g.flee_entries}回`,`草の消費：${g.grass_eaten.toFixed(1)}`,'',`兎更新：${ev.grazing_update_seconds.toFixed(2)}秒`,`全体：${ev.measurement.call_seconds.toFixed(1)}秒`,'（コンパイル込みの単発計測）','','緑の線：兎 / ○初期位置 / ●終了','青 A・黄 B・紫 C：人','橙の丸：拠点 / 赤い四角：食料','','人の食料：初期1080、回復なし','草：2日で容量分の回復速度','捕食・狩猟・繁殖：なし','兎は人の視認に反応する段階'];
lines.forEach((t,i)=>v.push(`<text x="850" y="${110+31*i}" font-size="16">${t}</text>`));
v.push('<text x="50" y="887" font-size="14">線は間引いた点の連結です。短い蛇行・回避は省略されます。数値は生物学的な校正値ではありません。</text></g></svg>');
const svg=v.join('\n');fs.writeFileSync(path.join(root,'grazing-map.svg'),svg);
sharp(Buffer.from(svg)).png().toFile(path.join(root,'grazing-map.png'));
