const fs=require('fs'),path=require('path'),sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const dir=process.argv[2],s=JSON.parse(fs.readFileSync(path.join(dir,'input.json'))).scene,a=JSON.parse(fs.readFileSync(path.join(dir,'complex-rocks-access.json')));
const X=x=>50+(x+30)*10,Y=z=>70+(44-z)*10;
let v=['<svg xmlns="http://www.w3.org/2000/svg" width="1040" height="740"><rect width="1040" height="740" fill="#f5f6f7"/><g font-family="Yu Gothic,Meiryo,sans-serif" fill="#243b4a"><text x="30" y="35" font-size="24">開放拠点＋複雑な岩地形</text><rect x="50" y="70" width="600" height="580" fill="white"/>'];
for(let x=-30;x<=30;x+=10)v.push(`<path d="M${X(x)},70V650" stroke="#e5e9ec"/><text x="${X(x)}" y="675" font-size="14">${x}</text>`);
for(let z=-10;z<=40;z+=10)v.push(`<path d="M50,${Y(z)}H650" stroke="#e5e9ec"/><text x="15" y="${Y(z)}" font-size="14">${z}</text>`);
v.push(`<circle cx="${X(0)}" cy="${Y(6)}" r="80" fill="#e5f1e9"/>`);
for(const o of s.obstacles.filter(o=>o.x>=-30&&o.x<=30&&o.z>=-14&&o.z<=44))v.push(`<circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${o.radius*10}" fill="${o.kind===1?'#83a98b':o.color==='ochre'?'#b39b6b':'#8d969f'}"/>`);
for(const [i,p] of a.paths.entries()){v.push(`<polyline points="${p.points.map(([x,z])=>X(x)+','+Y(z)).join(' ')}" fill="none" stroke="${['#428ac0','#dd7147','#7b65b2'][i]}" stroke-width="2" stroke-dasharray="5,4"/>`);}
for(const f of s.food)v.push(`<rect x="${X(f.x)-5}" y="${Y(f.z)-5}" width="10" height="10" fill="#b72f40"/>`);
v.push(`<circle cx="${X(0)}" cy="${Y(6)}" r="8" fill="#e69324"/>`);
const lines=['拠点：岩囲いなし・中央焚火','拠点から半径8以内に追加岩なし',`追加した岩：${a.added_rocks}個`,'外側：切れ目のずれた4列＋岩群','食料：遠方3か所、各24個・回復あり','人工道なし／危険OFF','','点線：検査用の通行可能経路','AIへこの経路は渡しません。','0.5刻み・身体余裕0.3で検査。','','これは配置確認です。','AIの往復試験は未実施。'];
lines.forEach((t,i)=>v.push(`<text x="685" y="${100+i*35}" font-size="17">${t}</text>`));v.push('<text x="50" y="715" font-size="15">北が上。赤四角＝食料、緑＝木、灰・黄土＝岩。薄緑円は追加岩を避ける範囲。</text></g></svg>');
const svg=v.join('\n');fs.writeFileSync(path.join(dir,'complex-map.svg'),svg);sharp(Buffer.from(svg)).png().toFile(path.join(dir,'complex-map.png'));
