// Loopback-only local experiment host. No arbitrary command or path API.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const repo=path.resolve(__dirname,'../..'),port=Number(process.env.LW_OBSERVER_PORT||8765),origin=`http://127.0.0.1:${port}`;
const julia=process.env.LW_OBSERVER_JULIA||'C:/Users/ken_m/Documents/Codex/tools/julia-1.13.1/bin/julia.exe';
const outputRoot=path.join(repo,'outputs','local-trade-live');fs.mkdirSync(outputRoot,{recursive:true});
let child=null,current=null,status='idle',error=null;
function send(res,code,type,body){res.writeHead(code,{'Content-Type':type,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(body);}
function start(){if(child)return false;current=path.join(outputRoot,new Date().toISOString().replace(/[:.]/g,'-'));fs.mkdirSync(current);const source=path.join(current,'source');fs.mkdirSync(source);
 fs.cpSync(path.join(repo,'src'),path.join(source,'src'),{recursive:true});
 for(const file of ['experiments/portable_items/checks.jl','experiments/simple_language/reply_trade.jl','experiments/simple_language/live_trade.jl']){const dest=path.join(source,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(repo,file),dest);}
 const log=fs.openSync(path.join(current,'run.log'),'w');status='starting';error=null;
 child=cp.spawn(julia,['--startup-file=no','--threads=1',`--project=${repo}`,path.join(source,'experiments/simple_language/live_trade.jl'),path.join(current,'record'),'1'],{cwd:repo,env:{...process.env,JULIA_DEPOT_PATH:process.env.JULIA_DEPOT_PATH||'C:/Users/ken_m/Documents/Codex/tools/julia-depot'},stdio:['ignore',log,log],windowsHide:true});fs.closeSync(log);
 child.on('error',e=>{error=e.message;status='failed';child=null;});child.on('exit',code=>{status=code===0?'completed':'failed';if(code!==0)error='Julia exit '+code;child=null;});return true;
}
const server=http.createServer((req,res)=>{if(req.headers.host!==`127.0.0.1:${port}`)return send(res,403,'text/plain','Invalid host');const url=new URL(req.url,origin);if(req.method==='POST'&&url.pathname==='/start'){if(req.headers.origin&&req.headers.origin!==origin)return send(res,403,'text/plain','Invalid origin');if(req.headers['content-type']!=='application/json')return send(res,415,'text/plain','JSON required');return send(res,start()?202:409,'application/json',JSON.stringify({status}));}
 if(req.method!=='GET')return send(res,405,'text/plain','Method not allowed');
 if(url.pathname==='/live.json'){let replay=null;const file=current&&path.join(current,'record/replay.json');if(file&&fs.existsSync(file)){try{replay=JSON.parse(fs.readFileSync(file,'utf8'));}catch{}}return send(res,200,'application/json',JSON.stringify({status:child?(replay?'running':'starting'):status,error,replay}));}
 const names={'/':'index.html','/model.js':'model.js','/viewer.js':'viewer.js','/style.css':'style.css','/live.js':'live.js'};const name=names[url.pathname];if(!name)return send(res,404,'text/plain','Not found');let text=fs.readFileSync(path.join(__dirname,name),'utf8');if(name==='index.html')text=text.replace('</body>','<script src="live.js"></script></body>');send(res,200,name.endsWith('.js')?'text/javascript':name.endsWith('.css')?'text/css':'text/html; charset=utf-8',text);
});server.listen(port,'127.0.0.1',()=>console.log('LOCAL TRADE GUI '+origin));
process.on('SIGINT',()=>{if(child)child.kill();server.close(()=>process.exit());});
