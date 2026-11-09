const fs=require('fs'),sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const d=JSON.parse(fs.readFileSync(process.argv[2])),w=d.geometry;
let s=[`<svg xmlns="http://www.w3.org/2000/svg" width="1320" height="1430"><rect width="100%" height="100%" fill="#f6f7f2"/><g font-family="Meiryo,sans-serif" fill="#24343c">`];
const text=(x,y,t,n=18)=>s.push(`<text x="${x}" y="${y}" font-size="${n}">${t}</text>`);
text(30,40,'短草再生調整版：54日目の兎の移動',28);
text(30,75,'同じ日の4個体 ／ 12tick（シミュレーション60秒）間隔 ／ 保存状態との再現一致を検証',17);
text(30,103,'線：青→橙で時間経過　○開始　●終了　×死亡　緑：日初の短草残量率　灰：障害物',17);
const labels=['移動量最大の生存個体','移動量中央値の生存個体','移動量最小の生存個体','この日に餓死した個体'];
d.summaries.forEach((r,i)=>{
 const pts=d.traces[r.id],ox=30+(i%2)*650,oy=135+Math.floor(i/2)*635;
 const span=Math.max(12,Math.max(...pts.map(p=>p.x))-Math.min(...pts.map(p=>p.x))+6,Math.max(...pts.map(p=>p.z))-Math.min(...pts.map(p=>p.z))+6);
 const cx=(Math.max(...pts.map(p=>p.x))+Math.min(...pts.map(p=>p.x)))/2,cz=(Math.max(...pts.map(p=>p.z))+Math.min(...pts.map(p=>p.z)))/2;
 const mx=ox+40,my=oy+66,size=440,sc=size/span,X=x=>mx+(x-cx+span/2)*sc,Y=z=>my+(cz+span/2-z)*sc;
 text(ox,oy+20,`ID ${r.id}：${labels[i]}`,22);text(ox,oy+47,`移動量 ${r.distance.toFixed(1)} ／ 年齢 ${r.age.toFixed(0)}日 ／ 体力 ${r.start_energy.toFixed(1)} → ${r.end_energy.toFixed(1)}`,16);
 s.push(`<defs><clipPath id="p${i}"><rect x="${mx}" y="${my}" width="${size}" height="${size}"/></clipPath></defs><g clip-path="url(#p${i})"><rect x="${mx}" y="${my}" width="${size}" height="${size}" fill="#e8e5dc"/>`);
 w.capacity.forEach((c,k)=>{let x=w.xmin+(k%w.nx)*w.cellsize,z=w.zmin+(Math.floor(k/w.nx)+1)*w.cellsize;if(Math.abs(x-cx)>span/2+2||Math.abs(z-cz)>span/2+2)return;let f=c?Math.min(1,w.short[k]/(.6*c)):0;s.push(`<rect x="${X(x)}" y="${Y(z)}" width="${sc*w.cellsize+.2}" height="${sc*w.cellsize+.2}" fill="${c?`hsl(105,30%,${96-47*f}%)`:'#e8e5dc'}"/>`)});
 let river=[];for(let z=w.zmin;z<w.zmax;z+=.5){let x=12+5*Math.sin((z-6)/22+w.phase),rw=1.2+.4*(1+Math.sin(z/13));river.push([x-rw/2,z]);}for(let z=w.zmax;z>w.zmin;z-=.5){let x=12+5*Math.sin((z-6)/22+w.phase),rw=1.2+.4*(1+Math.sin(z/13));river.push([x+rw/2,z]);}
 s.push(`<polygon points="${river.map(p=>X(p[0])+','+Y(p[1])).join(' ')}" fill="#a6d9ed"/>`);
 for(const o of w.obstacles)s.push(`<circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${o.radius*sc}" fill="#777f80" opacity=".75"/>`);
 for(let j=1;j<pts.length;j++){let p=pts[j-1],q=pts[j],f=(q.tick/17280-53);s.push(`<path d="M${X(p.x)} ${Y(p.z)}L${X(q.x)} ${Y(q.z)}" stroke="hsl(${220-190*f},85%,42%)" stroke-width="1.8" fill="none" opacity=".8"/>`)}
 let a=pts[0],b=pts.at(-1);s.push(`<circle cx="${X(a.x)}" cy="${Y(a.z)}" r="6" fill="white" stroke="#1969b5" stroke-width="2"/>`);
 if(r.alive)s.push(`<circle cx="${X(b.x)}" cy="${Y(b.z)}" r="4" fill="#c45a12"/>`);else s.push(`<path d="M${X(b.x)-7} ${Y(b.z)-7}l14 14m-14 0l14 -14" stroke="#a71927" stroke-width="3"/>`);
 s.push(`</g><rect x="${mx}" y="${my}" width="${size}" height="${size}" fill="none" stroke="#88958d"/>`);
 text(mx,my+size+22,`図幅 ${span.toFixed(1)}（個別縮尺）／ 北が上`,14);
 const ey=my+size+40,eh=55;s.push(`<rect x="${mx}" y="${ey}" width="${size}" height="${eh}" fill="white"/><polyline points="${pts.map(p=>`${mx+(p.tick/17280-53)*size},${ey+eh-p.energy/100*eh}`).join(' ')}" fill="none" stroke="#a82c46" stroke-width="2"/>`);
 text(mx,ey+eh+20,'体力：日初 → 日末（縦軸 0〜100）',14);
});s.push('</g></svg>');fs.writeFileSync(process.argv[3]+'.svg',s.join(''));sharp(Buffer.from(s.join(''))).png().toFile(process.argv[3]+'.png');
