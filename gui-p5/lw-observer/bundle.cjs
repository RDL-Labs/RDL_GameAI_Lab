const fs=require('node:fs'),path=require('node:path');
const [input,output]=process.argv.slice(2);if(!input||!output)throw Error('Usage: node bundle.cjs replay.json output.html');
const data=JSON.parse(fs.readFileSync(input,'utf8').replace(/^\uFEFF/,''));require('./model.js').validate(data);
let html=fs.readFileSync(path.join(__dirname,'index.html'),'utf8');const script=s=>s.replace(/<\/script/gi,'<\\/script');
html=html.replace('<link rel="stylesheet" href="style.css">',()=>'<style>'+fs.readFileSync(path.join(__dirname,'style.css'),'utf8')+'</style>');
html=html.replace('<script src="model.js"></script>',()=>'<script>'+script(fs.readFileSync(path.join(__dirname,'model.js'),'utf8'))+'</script><script>window.LW_REPLAY='+script(JSON.stringify(data))+';</script>');
html=html.replace('<script src="viewer.js"></script>',()=>'<script>'+script(fs.readFileSync(path.join(__dirname,'viewer.js'),'utf8'))+'</script>');fs.writeFileSync(output,html);console.log(output);
