import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 5173);
const types = {'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.svg':'image/svg+xml'};

const server = http.createServer((req,res)=>{
  const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
  let target = path.join(__dirname, urlPath === '/' ? 'index.html' : urlPath.replace(/^\//,''));
  if (!target.startsWith(__dirname)) { res.writeHead(403); return res.end('Forbidden'); }
  fs.stat(target,(err,stat)=>{
    if (err || !stat.isFile()) target = path.join(__dirname,'index.html');
    fs.readFile(target,(readErr,data)=>{
      if(readErr){res.writeHead(500);return res.end('Server error');}
      res.writeHead(200,{'Content-Type':types[path.extname(target)]||'application/octet-stream','Cache-Control':'no-store'});
      res.end(data);
    });
  });
});
server.listen(port,()=>console.log(`VMC Scheduler running at http://localhost:${port}`));
