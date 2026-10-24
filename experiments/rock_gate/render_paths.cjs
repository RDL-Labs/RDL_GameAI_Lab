const fs=require('fs'),path=require('path'),assert=require('assert');
const sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const run=path.resolve(process.argv[2]),prior=path.resolve(process.argv[3]);
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const input=read(path.join(run,'narrow/input.json')),scene=input.scene;
assert.deepStrictEqual(read(path.join(run,'narrow/run/result.json')),read(path.join(prior,'narrow/run/result.json')));
const rows=read(path.join(run,'narrow/positions.json'));
const actors=['npc_a','npc_b','npc_c'],days=3,daySec=17280;
const points=actors.map(a=>rows.filter(p=>p.actor===a));
points.forEach(ps=>{assert.equal(ps.length,days*daySec);ps.forEach((p,i)=>assert.equal(p.sec,i+1));});
const colors=['#147d92','#258b9e','#3b9a9a','#65a58d','#97ad71','#c8a653','#df8a3f','#e46637'];
let svg=[];
const put=s=>svg.push(s),text=(x,y,t,size=20,fill='#243847',anchor='start')=>put(`<text x="${x}" y="${y}" font-size="${size}" fill="${fill}" text-anchor="${anchor}">${t}</text>`);
const summary=[];
put('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1880" viewBox="0 0 1800 1880"><rect width="1800" height="1880" fill="#f7f6f1"/><g font-family="Yu Gothic UI,Meiryo,sans-serif">');
text(60,55,'狭い入口：3体 × 3日間の実際の移動経路',34);
text(60,92,'共通の局所移動場あり ／ 1秒ごとの実測位置 ／ 各図は同じ範囲・同じ縮尺',20);
text(60,128,'○ 開始　● 終了　灰色：岩　薄灰：人工道　橙色：松明　◇：拠点',19);
text(1100,128,'各日の時間：早い',18);
colors.forEach((c,i)=>put(`<rect x="${1245+i*40}" y="111" width="40" height="20" fill="${c}"/>`));text(1580,128,'遅い',18);
for(let day=0;day<days;day++)for(let ai=0;ai<actors.length;ai++){
 const ox=60+ai*580,oy=168+day*550,scale=34;
 const X=x=>ox+70+(x+6)*scale,Y=z=>oy+52+(12-z)*scale;
 put(`<rect x="${ox}" y="${oy}" width="560" height="528" rx="12" fill="white" stroke="#dcdedb"/>`);
 text(ox+22,oy+33,`${String.fromCharCode(65+ai)}  ｜  ${day+1}日目`,24);
 for(let v=-6;v<=6;v+=2){put(`<path d="M ${X(v)} ${Y(0)} V ${Y(12)}" stroke="#edf0ed"/>`);text(X(v),Y(0)+23,String(v),13,'#7a898e','middle');}
 for(let z=0;z<=12;z+=2){put(`<path d="M ${X(-6)} ${Y(z)} H ${X(6)}" stroke="#edf0ed"/>`);text(X(-6)-12,Y(z)+5,String(z),13,'#7a898e','end');}
 for(const road of scene.artificial_roads)for(const [x,z] of road.cells)put(`<rect x="${X(x)}" y="${Y(z+1)}" width="${scale}" height="${scale}" fill="#e6e9df"/>`);
 for(const o of scene.obstacles){if(Math.abs(o.x)>7||o.z< -1||o.z>13)continue;put(`<circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${o.radius*scale}" fill="${o.color==='orange'?'#ffbd45':o.color==='gray'?'#a2a9aa':'#bba882'}" stroke="${o.color==='orange'?'#bc6723':'#6c777b'}" stroke-width="1.3"/>`);}
 const hx=X(scene.home[0]),hy=Y(scene.home[1]);put(`<path d="M ${hx} ${hy-7} l 7 7 -7 7 -7 -7 Z" fill="#fdfafa" stroke="#334b65" stroke-width="2"/>`);
 const ps=points[ai].slice(day*daySec,(day+1)*daySec),start=day===0?scene.positions[ai]:points[ai][day*daySec-1].position;
 let p=start,distance=0,moves=0;
 const paths=colors.map(()=>[]);
 for(const row of ps){const q=row.position,d=Math.hypot(q[0]-p[0],q[1]-p[1]);if(d>1e-9){distance+=d;moves++;const k=Math.min(7,Math.floor(((row.sec-1)%daySec)/daySec*8));paths[k].push(`M${X(p[0]).toFixed(2)},${Y(p[1]).toFixed(2)}L${X(q[0]).toFixed(2)},${Y(q[1]).toFixed(2)}`);}p=q;}
 paths.forEach((d,i)=>put(`<path d="${d.join('')}" fill="none" stroke="${colors[i]}" stroke-width="1.4" stroke-opacity=".48"/>`));
 put(`<circle cx="${X(start[0])}" cy="${Y(start[1])}" r="7" fill="white" stroke="#183747" stroke-width="2.5"/>`);
 put(`<circle cx="${X(p[0])}" cy="${Y(p[1])}" r="6" fill="#182e40" stroke="white" stroke-width="1.5"/>`);
 text(X(0),Y(0)+23,'入口 ↓',15,'#b24b36','middle');
 text(ox+22,oy+517,`移動 ${moves.toLocaleString()} 回 ／ 距離 ${distance.toFixed(1)} ／ 残量 ${ps.at(-1).reserve.toFixed(1)}`,17);
 summary.push({actor:actors[ai],day:day+1,moves,distance,end:p,reserve:ps.at(-1).reserve});
}
text(60,1842,'線の重なりは同じ場所への再訪。停止中は線が増えません。壁の外へ出た個体はありません。',20);
put('</g></svg>');
const dest=path.join(run,'paths.svg');fs.writeFileSync(dest,svg.join('\n'));
fs.writeFileSync(path.join(run,'path-summary.json'),JSON.stringify(summary,null,2));
sharp(Buffer.from(svg.join('\n'))).png().toFile(path.join(run,'paths.png')).then(()=>console.log(JSON.stringify({image:path.join(run,'paths.png'),matched_previous_result:true,summary})));
