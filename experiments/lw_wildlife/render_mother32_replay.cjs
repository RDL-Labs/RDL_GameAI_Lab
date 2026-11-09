// Read-only diagnostic replay. Usage: node render_mother32_replay.cjs INPUT OUTPUT.html
const fs=require('fs');
const diagnostic=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
// The exported nest field is not a verified contemporaneous nursing nest; omit it.
delete diagnostic.nest;
const html=`<!doctype html><meta charset="utf-8"><title>母個体32：採食探索の追跡</title>
<style>body{font:16px sans-serif;background:#eef1f4;color:#182334;max-width:1100px;margin:24px auto}canvas{width:100%;background:white}button,input{margin:10px}table{border-collapse:collapse;width:100%}td,th{padding:6px;border-bottom:1px solid #ccd} .selected{background:#ffe2a0}small{color:#526070}</style>
<h1>母個体32：327〜328日目の追跡</h1><p>保存状態からの再生。緑＝その時刻の草残量／容量、青＝経路、赤＝現在位置。草は240 tick間隔、経路は60 tick間隔。巣位置は未検証のため表示しません。</p>
<button id="play">▶ 再生</button><input id="slider" type="range" min="0" max="87" value="0" style="width:65%"><span id="status"></span>
<canvas id="map" width="1100" height="430"></canvas><h2 id="choiceTitle"></h2><small>表は直前に実際に行った選択です。現在位置の候補とは限りません。草0.005未満は診断用の分類で、行動の閾値ではありません。</small><table id="table"></table>
<p>選択得点＝草量 − 0.25×距離 ＋ 0.2×向きの一致 − 直前セルへの減点1 − H。H圧が0なら最高得点、正なら確率選択。</p>
<script>const d=${JSON.stringify(diagnostic)};
const canvas=document.querySelector('#map'),ctx=canvas.getContext('2d'),slider=document.querySelector('#slider');slider.max=d.frames.length-1;
const px=x=>40+(x+62)*13,py=z=>390-(z-44)*13;
function draw(){const f=d.frames[+slider.value];ctx.fillStyle='white';ctx.fillRect(0,0,1100,430);
for(let k=0;k<f.grass.length;k++){let x=d.world.xmin+(k%d.world.nx)*2,z=d.world.zmin+Math.floor(k/d.world.nx)*2;if(x< -62||x>16||z<44)continue;let q=Math.max(0,Math.min(1,f.grass[k]/(d.world.capacity[k]||1)));ctx.fillStyle='rgb('+Math.round(248-205*q)+','+Math.round(246-84*q)+','+Math.round(232-160*q)+')';ctx.fillRect(px(x),py(z+2),26,26)}
ctx.strokeStyle='#64748b';ctx.strokeRect(px(-62),py(70),80*13,26*13);
ctx.fillStyle='#9ca3af';for(const o of d.world.obstacles){ctx.beginPath();ctx.arc(px(o.x),py(o.z),o.radius*13,0,7);ctx.fill()}
ctx.strokeStyle='#1765be';ctx.lineWidth=2;ctx.beginPath();let first=true;for(const p of d.trace){if(p.tick>f.tick)break;if(first){ctx.moveTo(px(p.x),py(p.z));first=false}else ctx.lineTo(px(p.x),py(p.z))}ctx.stroke();ctx.fillStyle='#cf293c';ctx.beginPath();ctx.arc(px(f.x),py(f.z),5,0,7);ctx.fill();
document.querySelector('#status').textContent='日 '+(Math.floor(f.tick/17280)+1)+' / '+((f.tick%17280)/17280*100).toFixed(1)+'%';ctx.fillStyle='#182334';ctx.font='17px sans-serif';ctx.fillText('energy '+f.energy.toFixed(2)+' / gut '+f.gut.toFixed(3)+' / '+f.state,40,25);
const c=d.choices[f.choice_index-1];if(!c){document.querySelector('#choiceTitle').textContent='この再生区間では未選択';document.querySelector('#table').innerHTML='';return}
document.querySelector('#choiceTitle').textContent='直前の選択：'+(f.tick-c.tick)+' tick前 / H圧 '+c.pressure.toFixed(3);
document.querySelector('#table').innerHTML='<tr><th>選択</th><th>セル</th><th>草量</th><th>距離</th><th>H</th><th>総合得点</th></tr>'+c.observations.map((o,i)=>'<tr class="'+(i===c.chosen-1?'selected':'')+'"><td>'+(i===c.chosen-1?'▶':'')+'</td><td>'+o.cell+'</td><td>'+o.grass.toFixed(4)+'</td><td>'+o.distance.toFixed(2)+'</td><td>'+c.H[i].toFixed(3)+'</td><td>'+c.scores[i].toFixed(3)+'</td></tr>').join('');}
slider.oninput=draw;let timer=null;document.querySelector('#play').onclick=()=>{if(timer){clearInterval(timer);timer=null;document.querySelector('#play').textContent='▶ 再生'}else{document.querySelector('#play').textContent='⏸ 停止';timer=setInterval(()=>{slider.value=(+slider.value+1)%d.frames.length;draw()},250)}};draw();</script>`;
fs.writeFileSync(process.argv[3],html);
console.log(process.argv[3]);
const sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
let svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="840"><rect width="1100" height="840" fill="white"/><g font-family="Yu Gothic UI,Meiryo,sans-serif">'];
svg.push('<text x="25" y="35" font-size="24">母個体32：時刻ごとの草量と移動経路</text><text x="25" y="63" font-size="16">緑：その時刻の残量／容量　青：ここまでの経路　赤：現在位置　北が上</text>');
for(const [panel,index] of [15,60,87].entries()){
 const f=diagnostic.frames[index],X=x=>30+(x+62)*12.8,Y=z=>100+panel*240+(70-z)*7.5;
 svg.push('<g>');for(let k=0;k<f.grass.length;k++){const x=-64+(k%64)*2,z=-58+Math.floor(k/64)*2;if(x< -62||x>14||z<46)continue;let q=Math.min(1,f.grass[k]/(diagnostic.world.capacity[k]||1));svg.push(`<rect x="${X(x)}" y="${Y(z+2)}" width="25.7" height="15.1" fill="hsl(105,35%,${96-55*q}%)"/>`)}
 const pts=diagnostic.trace.filter(p=>p.tick<=f.tick);svg.push(`<polyline points="${pts.map(p=>X(p.x)+','+Y(p.z)).join(' ')}" fill="none" stroke="#1765be" stroke-width="2"/><circle cx="${X(f.x)}" cy="${Y(f.z)}" r="5" fill="#cf293c"/><text x="30" y="${Y(46)+28}" font-size="17">${Math.floor(f.tick/17280)+1}日目 ${((f.tick%17280)/17280*100).toFixed(1)}% ／ energy ${f.energy.toFixed(2)} ／ ${f.state}</text></g>`);
}
svg.push('<text x="25" y="826" font-size="15">横 x=-62〜16、縦 z=46〜70（軸の縮尺は異なる）。草は240 tick、経路は60 tick間隔。</text></g></svg>');
const base=process.argv[3].replace(/\.html$/,'');fs.writeFileSync(base+'.svg',svg.join(''));sharp(Buffer.from(svg.join(''))).png().toFile(base+'.png');
