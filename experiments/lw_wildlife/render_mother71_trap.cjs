const fs=require('fs'),sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const d=JSON.parse(fs.readFileSync(process.argv[2])),w=d.geometry;
const pts=d.samples.filter(p=>p.tick>=1233930),W=1420,H=960;
let svg=[`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}"><rect width="100%" height="100%" fill="#f8f7f2"/><g font-family="Meiryo,sans-serif" fill="#263c46">`];
const text=(x,y,t,n=18)=>svg.push(`<text x="${x}" y="${y}" font-size="${n}">${t}</text>`);
text(30,40,'母親71：逃走後、岩の隙間で探索が行き詰まった経路',27);
text(30,73,'72日目・保存状態から再現一致を確認 ／ 逃走直前から毎tickの位置を記録',18);
text(30,103,'赤：逃走　青：通常行動（侵入まで）　橙：侵入後　灰：岩　破線：身体半径0.25を含む接触範囲',16);
function panel(ox,oy,xmin,zmin,span,title,zoom){
 const size=590,sc=size/span,X=x=>ox+(x-xmin)*sc,Y=z=>oy+size-(z-zmin)*sc,id=zoom?'z':'a';
 text(ox,oy-15,title,21);svg.push(`<defs><clipPath id="${id}"><rect x="${ox}" y="${oy}" width="${size}" height="${size}"/></clipPath></defs><g clip-path="url(#${id})"><rect x="${ox}" y="${oy}" width="${size}" height="${size}" fill="#ede9df"/>`);
 w.capacity.forEach((c,k)=>{let x=w.xmin+k%w.nx*w.cellsize,z=w.zmin+Math.floor(k/w.nx)*w.cellsize;if(x>xmax(xmin,span)||x+2<xmin||z>zmin+span||z+2<zmin)return;let f=c?Math.min(1,w.short[k]/(.6*c)):0;svg.push(`<rect x="${X(x)}" y="${Y(z+2)}" width="${2*sc}" height="${2*sc}" fill="${c?`hsl(104,28%,${94-43*f}%)`:'#e9e4d9'}" stroke="#c4ccba" stroke-width=".5"/>`)});
 for(const o of d.obstacles)svg.push(`<circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${(o.radius+.25)*sc}" fill="none" stroke="#697178" stroke-dasharray="4 3"/><circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${o.radius*sc}" fill="#929b9c"/>`);
 const nest=[15.341520036248587,24.98898854060123];svg.push(`<circle cx="${X(nest[0])}" cy="${Y(nest[1])}" r="7" fill="#7541a8"/>`);if(!zoom)text(X(nest[0])+10,Y(nest[1])+5,'巣・子4匹',16);
 for(let j=1;j<pts.length;j++){const a=pts[j-1],b=pts[j],color=b.tick>=1234059?'#d67810':b.state==='flee'?'#bd2745':'#146dac';svg.push(`<path d="M${X(a.position[0])},${Y(a.position[1])}L${X(b.position[0])},${Y(b.position[1])}" fill="none" stroke="${color}" stroke-width="${zoom?2:1.8}" opacity=".65"/>`)}
 if(zoom){const k=d.final.cell-1,ix=k%w.nx,iz=Math.floor(k/w.nx);for(let dz=-1;dz<=1;dz++)for(let dx=-1;dx<=1;dx++){if(!dx&&!dz)continue;let x=w.xmin+(ix+dx+.5)*2,z=w.zmin+(iz+dz+.5)*2;svg.push(`<path d="M${X(x)-5} ${Y(z)-5}l10 10m-10 0l10 -10" stroke="#962e73" stroke-width="2"/>`)} }
 let p=pts[0].position,q=d.final.position;svg.push(`<circle cx="${X(p[0])}" cy="${Y(p[1])}" r="6" fill="white" stroke="#bd2745" stroke-width="2"/><path d="M${X(q[0])-7} ${Y(q[1])-7}l14 14m-14 0l14 -14" stroke="#202a2e" stroke-width="3"/></g><rect x="${ox}" y="${oy}" width="${size}" height="${size}" fill="none" stroke="#64767d"/>`);
 text(ox,oy+size+24,`x ${xmin}〜${xmin+span} ／ z ${zmin}〜${zmin+span} ／ 北が上`,15);
}
function xmax(x,s){return x+s}
panel(40,160,6,19,18,'① 逃走して岩場へ入る',false);
panel(760,160,12,28,8,'② 岩場の拡大：橙の狭い経路を反復',true);
text(40,815,'背景の緑：72日末の短草残量率。ベージュ：草容量0。黒×：死亡位置。',17);
text(40,845,'右図の紫×：近傍8セルの中心。死亡位置からの移動候補は全て不成立。',17);
text(40,884,'逃走開始時の体力 約85 → 草容量0のセルで滞留 → 移動阻害1,964回 → 餓死',22);
text(40,919,'隙間に入れたことは確認済み。物理的に脱出不能だったという判定ではありません。',17);
svg.push('</g></svg>');fs.writeFileSync(process.argv[3]+'.svg',svg.join(''));sharp(Buffer.from(svg.join(''))).png().toFile(process.argv[3]+'.png');
