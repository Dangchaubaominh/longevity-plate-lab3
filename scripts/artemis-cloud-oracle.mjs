// Read-only cloud evidence for the already signed-in, approved test account.
// Secrets stay in local .dev.vars. Never print tokens or private delivery URLs.
import {readFileSync,writeFileSync} from 'node:fs';
import {parseEnv} from 'node:util';
import {sign,createHash} from 'node:crypto';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const uid=process.env.LAB3_TEST_UID;
if(!uid)throw new Error('LAB3_TEST_UID must match the approved account signed in on the device.');
const [campaign,kind,date]=process.argv.slice(2);
if(!/^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/.test(campaign||'')||!['meals','plans'].includes(kind)||!/^\d{4}-\d{2}-\d{2}$/.test(date||''))throw new Error('Expected campaign, meals|plans, YYYY-MM-DD');
const c=parseEnv(readFileSync(resolve(root,'server/.dev.vars'),'utf8'));
const account=JSON.parse(c.GOOGLE_SERVICE_ACCOUNT_JSON),web=JSON.parse(c.FIREBASE_WEB_CONFIG);
const now=Math.floor(Date.now()/1000),encode=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
const unsigned=encode({alg:'RS256',typ:'JWT'})+'.'+encode({iss:account.client_email,sub:account.client_email,aud:'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',iat:now,exp:now+300,uid});
const token=unsigned+'.'+sign('RSA-SHA256',Buffer.from(unsigned),account.private_key).toString('base64url');
const login=await fetch('https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key='+web.apiKey,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token,returnSecureToken:true})});
const session=await login.json();if(!login.ok)throw new Error('Firebase oracle authentication failed; details withheld.');
const base='https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev/api/v1';
const headers={Authorization:'Bearer '+session.idToken,'Content-Type':'application/json'};
let cursor='',items=[],status;
do{
  const r=await fetch(`${base}/${kind}?from=${date}&to=${date}&limit=50${cursor?'&cursor='+encodeURIComponent(cursor):''}`,{headers});
  status=r.status;if(!r.ok)throw new Error('Staging read failed: HTTP'+status);
  const data=await r.json();items.push(...data.items);cursor=data.nextCursor;
}while(cursor);
const tests=kind==='plans'?items:items.filter(row=>(row.data?.description||'').includes(campaign));
const out=resolve(root,'artifacts/artemis-campaigns',campaign);
for(const row of tests.filter(row=>row.photoAsset?.id)){
  const response=await fetch(`${base}/media/${row.photoAsset.id}/url`,{method:'POST',headers,body:'{}'});
  const link=await response.json();if(!response.ok||!link.url)throw new Error('Private photo URL unavailable');
  const download=await fetch(link.url),bytes=Buffer.from(await download.arrayBuffer());
  if(!download.ok)throw new Error('Private photo download failed: '+download.status);
  writeFileSync(resolve(out,`photo-${row.id}.jpg`),bytes);
  row.downloadProof={status:download.status,contentType:download.headers.get('content-type'),bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};
}
const proof={time:new Date().toISOString(),status,date,totalInRange:items.length,tests};
writeFileSync(resolve(out,`${kind}-${date}.json`),JSON.stringify(proof,null,2)+'\n');
console.log(JSON.stringify(proof));
