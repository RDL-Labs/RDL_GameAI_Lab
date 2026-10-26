// node experiments/rock_gate/render_daily_paths.cjs RUN [CASE] [OUTPUT]
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const run=path.resolve(process.argv[2]),caseName=process.argv[3]||'ordinary';
const dir=path.join(run,caseName),dest=path.resolve(process.argv[4]||path.join(dir,'daily-paths'));
const read=f=>JSON.parse(fs.readFileSync(path.join(dir,f),'utf8'));
const input=read('input.json'),scene=input.scene,rows=read('positions.json'),report=read('report.json');
const actors=Object.keys(report.actors).sort(),daySec=input.clock.day_us/1e6;
const days=Math.ceil(rows.reduce((m,x)=>Math.max(m,x.sec),0)/daySec);
const tracks=Object.fromEntries(actors.map(a=>[a,rows.filter(x=>x.actor===a)]));
let cadence=0;for(const ps of Object.values(tracks))for(let i=1;i<ps.length;i++){assert.ok(ps[i].sec>ps[i-1].sec);cadence=Math.max(cadence,ps[i].sec-ps[i-1].sec);}
const coords=[scene.home,...scene.food.map(f=>[f.x,f.z]),...rows.map(r=>r.position)];
const xmin=Math.floor(coords.reduce((m,p)=>Math.min(m,p[0]),Infinity)/5)*5-5,xmax=Math.ceil(coords.reduce((m,p)=>Math.max(m,p[0]),-Infinity)/5)*5+5;
const zmin=Math.floor(coords.reduce((m,p)=>Math.min(m,p[1]),Infinity)/5)*5-5,zmax=Math.ceil(coords.reduce((m,p)=>Math.max(m,p[1]),-Infinity)/5)*5+5;
const scale=Math.min(440/(xmax-xmin),440/(zmax-zmin)),colors=['#176db0','#218d84','#b79c28','#dc702b','#a82e61'];
fs.mkdirSync(dest,{recursive:true});const summaries=[];
(async()=>{
 for(let day=1;day<=days;day++){
  const svg=[`<svg xmlns="http://www.w3.org/2000/svg" width="1560" height="680"><rect width="1560" height="680" fill="#f4f5f0"/><g font-family="Yu Gothic UI,Meiryo,sans-serif" fill="#253849"><text x="30" y="38" font-size="26">${day}日目：移動経路</text><text x="30" y="68" font-size="16">○開始 ●終了　青→緑→黄→橙→紫：時間経過　◆拠点　赤四角：食料の初期位置（残量は表していません）</text>`];
  for(let ai=0;ai<actors.length;ai++){
   const a=actors[ai],all=tracks[a],ps=all.filter(p=>p.sec>(day-1)*daySec&&p.sec<=day*daySec);assert.ok(ps.length);
   const prior=all.findLast(p=>p.sec<=(day-1)*daySec),start=prior?.position||scene.positions[ai],ox=30+ai*510,oy=135;
   const X=x=>ox+25+(x-xmin)*scale,Y=z=>oy+(zmax-z)*scale;
   const text=(x,y,t,size=15)=>svg.push(`<text x="${x}" y="${y}" font-size="${size}">${t}</text>`);
   svg.push(`<rect x="${ox}" y="90" width="495" height="535" rx="10" fill="white"/>`);text(ox+18,120,a.toUpperCase(),21);
   svg.push(`<defs><clipPath id="c${ai}"><rect x="${X(xmin)}" y="${Y(zmax)}" width="${(xmax-xmin)*scale}" height="${(zmax-zmin)*scale}"/></clipPath></defs><g clip-path="url(#c${ai})">`);
   for(let x=xmin;x<=xmax;x+=10)svg.push(`<path d="M${X(x)},${Y(zmax)}V${Y(zmin)}" stroke="#e5e9eb"/>`);
   for(let z=zmin;z<=zmax;z+=10)svg.push(`<path d="M${X(xmin)},${Y(z)}H${X(xmax)}" stroke="#e5e9eb"/>`);
   for(const road of scene.artificial_roads||[])for(const[x,z]of road.cells)svg.push(`<rect x="${X(x)}" y="${Y(z+1)}" width="${scale}" height="${scale}" fill="#ded6bf"/>`);
   for(const o of [...scene.obstacles,...(scene.low_obstacles||[])])svg.push(`<circle cx="${X(o.x)}" cy="${Y(o.z)}" r="${Math.max(1,o.radius*scale)}" fill="${o.light_source?'#e6a526':o.kind===1?'#a4baa1':'#b6b9bd'}"/>`);
   const hx=X(scene.home[0]),hy=Y(scene.home[1]);svg.push(`<circle cx="${hx}" cy="${hy}" r="${1.25*scale}" fill="#d2e9f8"/><path d="M${hx},${hy-6}l6,6 -6,6 -6,-6Z" fill="#163d68"/>`);
   for(const f of scene.food)svg.push(`<rect x="${X(f.x)-3}" y="${Y(f.z)-3}" width="6" height="6" fill="#c94c46"/>`);
   let p=start;for(const row of ps){const q=row.position,k=Math.min(4,Math.floor((row.sec-(day-1)*daySec)/daySec*5));svg.push(`<path d="M${X(p[0])},${Y(p[1])}L${X(q[0])},${Y(q[1])}" fill="none" stroke="${colors[k]}" stroke-opacity=".65" stroke-width="1.5"/>`);p=q;}
   svg.push(`<circle cx="${X(start[0])}" cy="${Y(start[1])}" r="5" fill="white" stroke="#172e43" stroke-width="2"/><circle cx="${X(p[0])}" cy="${Y(p[1])}" r="4" fill="#172e43" stroke="white"/></g>`);
   const reserve=ps.at(-1).reserve,distance=Math.hypot(p[0]-scene.home[0],p[1]-scene.home[1]);text(ox+18,600,`終了エネルギー ${reserve.toFixed(1)}　拠点距離 ${distance.toFixed(1)}`);
   summaries.push({actor:a,day,samples:ps.length,start,end:p,reserve,distance});
  }
  svg.push(`<text x="30" y="655" font-size="16">最大${cadence}秒間隔の位置記録を直線で接続。間の迂回・停止は復元できません。全日・全個体で共通縮尺／北が上。</text></g></svg>`);
  const name=`day-${String(day).padStart(2,'0')}`,source=svg.join('\n');fs.writeFileSync(path.join(dest,name+'.svg'),source);await sharp(Buffer.from(source)).png().toFile(path.join(dest,name+'.png'));
 }
 fs.writeFileSync(path.join(dest,'summary.json'),JSON.stringify({days,cadence,bounds:{xmin,xmax,zmin,zmax},summaries},null,2));
 fs.writeFileSync(path.join(dest,'index.html'),`<!doctype html><meta charset="utf-8"><title>日別経路</title><style>body{font-family:sans-serif;background:#f4f5f0;margin:24px}img{width:100%}input{width:50%}button{padding:8px}a{margin:8px}</style><h1>日ごとの経路</h1><p>最大${cadence}秒間隔の観測位置。線は補間で、実際の細かい経路ではありません。食料は初期配置です。</p><button onclick="setDay(+s.value-1)">前日</button><input id="s" type="range" min="1" max="${days}" value="1" oninput="setDay(this.value)"><button onclick="setDay(+s.value+1)">翌日</button><b id="label"></b><a id="download">PNG</a><img id="map" alt="日別経路図"><script>const s=document.querySelector('#s');function setDay(v){v=Math.max(1,Math.min(${days},+v));s.value=v;document.querySelector('#label').textContent=v+'日目';const p='day-'+String(v).padStart(2,'0')+'.png';document.querySelector('#map').src=p;document.querySelector('#download').href=p;}setDay(1);</script>`);
 console.log(JSON.stringify({dest,days,actors:actors.length,cadence}));
})().catch(e=>{console.error(e);process.exitCode=1;});
