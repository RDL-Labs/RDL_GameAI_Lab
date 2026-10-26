const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const input=JSON.parse(fs.readFileSync(process.argv[2],'utf8')),s=input.scene,out=path.resolve(process.argv[3]);
const X=x=>450+x*15,Y=z=>300-z*15,colors=['#ef9844','#b760b5','#d74744'];
const svg=[`<svg xmlns="http://www.w3.org/2000/svg" width="900" height="800"><rect width="900" height="800" fill="#f3f5eb"/><g font-family="Yu Gothic UI,Meiryo,sans-serif" fill="#263d48"><text x="30" y="35" font-size="25">3段階の食料配置と地域の目印</text><text x="30" y="62" font-size="16">橙：近距離12食 × 3　紫：中距離24食 × 3　赤：遠距離24食 × 3</text><text x="30" y="88" font-size="15">近・中は有限／遠は再生あり　北が上　線は実際の人工道</text>`];
for(const road of s.artificial_roads)for(const[x,z]of road.cells)svg.push(`<rect x="${X(x)}" y="${Y(z+1)}" width="15" height="15" fill="#d3c39e"/>`);
const ids=new Set(s.distinctive_landmarks.world_ids);
for(const o of s.obstacles){if(o.x< -25||o.x>25||o.z< -25||o.z>13)continue;svg.push(`<circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${o.radius*15}" fill="${o.light_source?'#f3b42e':o.kind===1?'#64885d':o.color==='ochre'?'#b29a69':'#8b959e'}" stroke="${ids.has(o.world_id)?'#35444a':'none'}"/>`);}
for(let k=0;k<3;k++)for(const[x,z]of s.food_stages.sites[k])svg.push(`<circle cx="${X(x)}" cy="${Y(z)}" r="8" fill="${colors[k]}" stroke="white" stroke-width="2"/>`);
const[hx,hz]=s.home;svg.push(`<circle cx="${X(hx)}" cy="${Y(hz)}" r="${1.25*15}" fill="#6eadd6" fill-opacity=".6"/><text x="${X(hx)+23}" y="${Y(hz)-9}" font-size="18">拠点</text>`);
svg.push('<text x="100" y="195" font-size="18">西：弧状岩場</text><text x="680" y="205" font-size="18">東：並木</text><text x="540" y="460" font-size="18">南：大小の岩</text><text x="30" y="740" font-size="16">経路は世界側で通行検証済み。AIへの道順の事前登録はありません。</text><text x="30" y="770" font-size="15">地形の個性は障害物群で表現。標高・川形状は既存のまま（水域はこの図では省略）。</text></g></svg>');
fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out+'.svg',svg.join('\n'));sharp(Buffer.from(svg.join('\n'))).png().toFile(out+'.png').then(()=>console.log(out+'.png')).catch(e=>{console.error(e);process.exitCode=1;});
