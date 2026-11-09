const fs=require('fs'),sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const d=JSON.parse(fs.readFileSync(process.argv[2])),g=JSON.parse(fs.readFileSync(process.argv[3])),w=g.geometry;
let s=[`<svg xmlns="http://www.w3.org/2000/svg" width="1180" height="850"><rect width="100%" height="100%" fill="#f8f7f2"/><g font-family="Meiryo,sans-serif" fill="#263c46">`];
const text=(x,y,t,n=18)=>s.push(`<text x="${x}" y="${y}" font-size="${n}">${t}</text>`);
text(30,40,'母71：局所ρを細かくすると、岩の隙間から脱出',26);
text(30,74,'橙：従来の往復　青：局所ρあり　紫○：細かな中間目標　破線：身体を含む岩の接触範囲',16);
const ox=35,oy=110,size=620,span=10,xmin=11,zmin=25,sc=size/span,X=x=>ox+(x-xmin)*sc,Y=z=>oy+size-(z-zmin)*sc;
s.push(`<defs><clipPath id="map"><rect x="${ox}" y="${oy}" width="${size}" height="${size}"/></clipPath></defs><g clip-path="url(#map)">`);
w.capacity.forEach((c,k)=>{let x=w.xmin+k%w.nx*2,z=w.zmin+Math.floor(k/w.nx)*2;if(x>21||x+2<11||z>35||z+2<25)return;let f=c?Math.min(1,w.short[k]/(.6*c)):0;s.push(`<rect x="${X(x)}" y="${Y(z+2)}" width="${2*sc}" height="${2*sc}" fill="${c?`hsl(104,28%,${94-43*f}%)`:'#e9e4d9'}" stroke="#c4ccba" stroke-width=".5"/>`)});
for(const o of g.obstacles)s.push(`<circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${(o.radius+.25)*sc}" fill="none" stroke="#697178" stroke-dasharray="4 3"/><circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${o.radius*sc}" fill="#929b9c"/>`);
for(const [r,color,end] of [[d.baseline,'#d67810',Infinity],[d.treatment,'#1267ba',1234300]]){
 const pts=r.samples.filter(p=>p.tick>=1234059&&p.tick<=end);
 s.push(`<polyline points="${pts.map(p=>X(p.position[0])+','+Y(p.position[1])).join(' ')}" fill="none" stroke="${color}" stroke-width="${r===d.baseline?6:2.7}"/>`);
}
for(const r of d.treatment.records.filter(r=>r.event==='fine_choice'))s.push(`<circle cx="${X(r.waypoint[0])}" cy="${Y(r.waypoint[1])}" r="4" stroke="#79399b" fill="white" stroke-width="1.5"/>`);
s.push('</g>');text(ox,760,'背景：元試験72日末の草。青線は脱出後しばらくまで。北が上。',15);
text(700,145,'同じ保存状態・同じ侵入経路',23);
let y=198;for(const t of ['候補なし → H蓄積','H = 1 で局所詳細観測','半径1.6以内、最大128点','中間目標を8回選択','12tick後に通常候補が復活','翌tick、採食再開']){text(700,y,t,20);y+=40;}
text(700,485,'72日末の結果',23);
text(700,530,'従来：体力0、餓死',21);text(700,570,'局所ρ：体力87.9、生存',21);text(700,610,'授乳も再開、子4匹は体力7.78',18);
text(700,660,'移動阻害：1,964 → 3回',21);
text(35,810,'母71のみの局所実験。世界の格子は2mのまま。通常系には未接続。',20);
s.push('</g></svg>');fs.writeFileSync(process.argv[4]+'.svg',s.join(''));sharp(Buffer.from(s.join(''))).png().toFile(process.argv[4]+'.png');
