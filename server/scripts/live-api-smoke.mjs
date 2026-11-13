// Local Worker + actual Firebase/Cloudinary/Crashlytics verification.
// Creates only random, temporary Firebase test users and owned test assets.
// Never prints/persists credentials, ID tokens, refresh tokens or signed URLs.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {parseEnv} from 'node:util';
import {sign,randomUUID,createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {signParams} from '../src/index.js';

const config=parseEnv(readFileSync('.dev.vars','utf8'));
function jsonConfig(name){try{return JSON.parse(config[name]||'{}');}catch{throw new Error(name+' is invalid JSON (contents hidden)');}}
const credentials=jsonConfig('GOOGLE_SERVICE_ACCOUNT_JSON');
const web=jsonConfig('FIREBASE_WEB_CONFIG');
if(credentials.project_id!=='longevity-plate-beff9'||web.projectId!=='longevity-plate-beff9')throw new Error('Unexpected project (values hidden)');
const base=process.env.STAGING_API_URL??process.env.LOCAL_WORKER_URL??'http://127.0.0.1:8793';
const remote=base==='https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev';
if(!remote&&!['127.0.0.1','localhost'].includes(new URL(base).hostname))throw new Error('Only local or the explicitly configured Lab3 staging Worker is allowed');
const report={time:new Date().toISOString(),source:remote?'staging-worker-with-real-providers':'local-worker-with-real-providers',checks:[],notes:[]};
const users=[],assets=[];const nonce=randomUUID().replaceAll('-','');
const check=(name,pass,status,code)=>{report.checks.push({name,pass,status,...(code?{code}:{} )});console.log(`${name}: ${pass?'PASS':'FAIL'}${status?` (HTTP ${status})`:''}${code?` [${code}]`:''}`);};
const fetchSafe=(url,init={})=>fetch(url,{...init,signal:AbortSignal.timeout(25000)});
const segment=value=>Buffer.from(JSON.stringify(value)).toString('base64url');
function jwt(payload){const unsigned=segment({alg:'RS256',typ:'JWT'})+'.'+segment(payload);return unsigned+'.'+sign('RSA-SHA256',Buffer.from(unsigned),credentials.private_key).toString('base64url');}
async function identity(action,body){
 const response=await fetchSafe(`https://identitytoolkit.googleapis.com/v1/accounts:${action}?key=${web.apiKey}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
 const result=await response.json().catch(()=>({}));return {response,result};
}
async function makeUser(suffix){
 const uid=`acceptance_e2e_${nonce}_${suffix}`;const now=Math.floor(Date.now()/1000);
 const token=jwt({iss:credentials.client_email,sub:credentials.client_email,aud:'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',iat:now,exp:now+300,uid});
 const {response,result}=await identity('signInWithCustomToken',{token,returnSecureToken:true});
 const ok=response.ok&&typeof result.idToken==='string'&&result.isNewUser!==false;
 const providerCode=String(result.error?.details?.find(d=>d.reason)?.reason??result.error?.message??'').match(/^[A-Z][A-Z0-9_]{1,60}/)?.[0];
 check(`firebase_token_${suffix}`,ok,response.status,providerCode);
 if(!ok)throw new Error('Unable to create controlled Firebase session (details hidden)');
 const user={uid,token:result.idToken};users.push(user);return user;
}
async function api(user,path,method='GET',body){
 const response=await fetchSafe(base+'/api/v1'+path,{method,headers:{...(user?{Authorization:`Bearer ${user.token}`} : {}),...(body===undefined?{}:{'Content-Type':'application/json'})},...(body===undefined?{}:{body:JSON.stringify(body)})});
 const data=await response.json().catch(()=>({}));return {response,data};
}
function localSql(sql){
 const result=spawnSync(process.execPath,['node_modules/wrangler/bin/wrangler.js','d1','execute','DB',...(remote?['--remote','--config','wrangler.staging.toml']:['--local']),'--command',sql],{timeout:45000,encoding:'utf8'});
 if(result.status!==0)throw new Error('Local D1 fixture statement failed (output hidden)');
}
async function oauth(scope){
 const now=Math.floor(Date.now()/1000);const assertion=jwt({iss:credentials.client_email,scope,aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+300});
 const response=await fetchSafe('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})});
 const data=await response.json().catch(()=>({}));if(!response.ok||!data.access_token)throw new Error('Google OAuth rejected (details hidden)');return data.access_token;
}
function pdf(){
 const out=['%PDF-1.4\n'],offsets=[];const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> /Contents 4 0 R >>','<< /Length 0 >>\nstream\n\nendstream'];
 objects.forEach((obj,i)=>{offsets.push(Buffer.byteLength(out.join('')));out.push(`${i+1} 0 obj\n${obj}\nendobj\n`);});const xref=Buffer.byteLength(out.join(''));
 out.push(`xref\n0 5\n0000000000 65535 f \n${offsets.map(n=>`${String(n).padStart(10,'0')} 00000 n \n`).join('')}trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`);return Buffer.from(out.join(''));
}
try{
 const anon=await api(null,'/me');check('anonymous_401',anon.response.status===401,anon.response.status);
 const a=await makeUser('a'),b=await makeUser('b');
 for(const [name,user] of [['a',a],['b',b]]){const me=await api(user,'/me');check(`worker_real_firebase_jwt_${name}`,me.response.ok&&me.data.uid===user.uid,me.response.status);if(!me.response.ok)throw new Error('Worker JWT verification failed');}
 const forbidden=await api(a,'/admin/overview');check('ordinary_user_admin_403',forbidden.response.status===403,forbidden.response.status);
 localSql(`INSERT INTO admin_users(uid,active) VALUES('${a.uid}',1);`);
 const admin=await api(a,'/admin/overview');check('local_admin_allowlist',admin.response.ok,admin.response.status);
 const mutation=data=>({opId:randomUUID(),baseVersion:0,data});const mealId=`verification_${nonce}`;
 const input=mutation({date:new Date().toISOString().slice(0,10),type:'lunch',description:'Controlled Lab3 live verification'});
 const saved=await api(a,'/meals/'+mealId,'PUT',input);check('meal_create_d1',saved.response.ok&&saved.data.record?.version===1,saved.response.status);
 const repeat=await api(a,'/meals/'+mealId,'PUT',input);check('meal_idempotency',repeat.data.record?.version===1,repeat.response.status);
 const foreign=await api(b,'/meals/'+mealId);check('other_owner_read_404',foreign.response.status===404,foreign.response.status);
 const foreignWrite=await api(b,'/meals/'+mealId,'PUT',{...input,opId:randomUUID(),baseVersion:1});check('other_owner_update_404',foreignWrite.response.status===404,foreignWrite.response.status);
 const conflict=await api(a,'/meals/'+mealId,'PUT',{...input,opId:randomUUID()});check('revision_conflict',conflict.response.status===409,conflict.response.status);
 const profile=await api(a,'/me/profile','PUT',mutation({displayName:'Lab3 verification',timezone:'Asia/Bangkok'}));check('profile_update',profile.response.ok,profile.response.status);
 const goals=await api(a,'/me/goals','PUT',mutation({goals:['logMeals']}));check('goals_update',goals.response.ok,goals.response.status);
 const planId=new Date().toISOString().slice(0,10)+'_lunch';
 const plan=await api(a,'/plans/'+planId,'PUT',mutation({date:new Date().toISOString().slice(0,10),slot:'lunch',recipeId:'rice-veg-beans'}));check('weekly_plan_create',plan.response.ok,plan.response.status);
 for(const [kind,format,bytes] of [['photo','jpg',readFileSync(new URL('../test/fixtures/smoke.jpg',import.meta.url))],['pdf','pdf',pdf()]]){
  const ticket=await api(a,'/media/sign','POST',{kind,contentHash:createHash('sha256').update(bytes).digest('hex'),...(kind==='photo'?{mealId,mealVersion:1}: {})});
  check(`${kind}_worker_ticket`,ticket.response.ok,ticket.response.status);if(!ticket.response.ok)continue;
  const publicId=ticket.data.publicId;if(!publicId.startsWith(`${kind==='photo'?'meal_photos':'reports'}/${a.uid}/`))throw new Error('Unexpected asset ownership');
  assets.push(publicId);const form=new FormData();for(const [key,value] of Object.entries(ticket.data.fields))form.set(key,value);form.set('file',new Blob([bytes],{type:kind==='photo'?'image/jpeg':'application/pdf'}),`fixture.${format}`);
  const upload=await fetchSafe(ticket.data.uploadUrl,{method:'POST',body:form});const uploaded=await upload.json();check(`${kind}_direct_upload`,upload.ok,upload.status);if(!upload.ok)continue;
  const receipt={publicId,version:String(uploaded.version),signature:uploaded.signature};
  const foreignConfirm=await api(b,`/media/${ticket.data.assetId}/complete`,'POST',receipt);check(`${kind}_other_owner_confirm_404`,foreignConfirm.response.status===404,foreignConfirm.response.status);
  const complete=await api(a,`/media/${ticket.data.assetId}/complete`,'POST',receipt);check(`${kind}_worker_confirmation`,complete.response.ok,complete.response.status,complete.data.error?.code);if(!complete.response.ok)continue;
  const reconciled=await api(a,`/media/${ticket.data.assetId}/reconcile`,'POST',{});check(`${kind}_reconcile_idempotent`,reconciled.response.ok&&reconciled.data.asset?.id===ticket.data.assetId,reconciled.response.status);
  const link=await api(a,`/media/${ticket.data.assetId}/url`,'POST',{});const download=link.response.ok?await fetchSafe(link.data.url):null;
  check(`${kind}_worker_private_download`,download?.ok===true,download?.status??link.response.status);if(download?.ok)await download.arrayBuffer();
  const denied=await api(b,`/media/${ticket.data.assetId}/url`,'POST',{});check(`${kind}_other_owner_link_404`,denied.response.status===404,denied.response.status);
 }
 const pull=await api(a,'/sync/pull?cursor=0&limit=20');check('sync_cursor_real_changes',pull.response.ok&&pull.data.items?.some(r=>r.id===mealId),pull.response.status);
 const latest=await api(a,'/meals/'+mealId);const deleted=await api(a,'/meals/'+mealId,'DELETE',{opId:randomUUID(),baseVersion:latest.data.record.version,data:{}});check('meal_soft_delete',deleted.response.ok,deleted.response.status);
 const after=await api(a,`/sync/pull?cursor=${pull.data.nextCursor}&limit=20`);check('sync_tombstone',after.data.items?.some(r=>r.id===mealId&&r.deletedAt!==null),after.response.status);
 try{
  const token=await oauth('https://www.googleapis.com/auth/firebase.messaging');
  const validated=await fetchSafe(`https://fcm.googleapis.com/v1/projects/${credentials.project_id}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({validate_only:true,message:{topic:'lab3-verification-validation-only',notification:{title:'Lab3 API validation',body:'Validation only; no device delivery'}}})});
  check('fcm_provider_validate_only',validated.ok,validated.status);report.notes.push('FCM used validate_only=true. No device message was sent; no claim of delivery.');
 }catch{check('fcm_provider_validate_only',false);}
 const crash=await api(a,'/admin/crashlytics/refresh','POST',{});check('crashlytics_live_refresh',crash.response.ok,crash.response.status,crash.data.error?.code);
 if(crash.response.ok){
  const groups=crash.data.payload?.groups??[];report.notes.push(`Actual Crashlytics groups returned: ${groups.length}. No synthetic crash data inserted.`);
  const id=groups[0]?.issue?.id;if(id){const detail=await api(a,'/admin/crashlytics/issues/'+encodeURIComponent(id));check('crashlytics_actual_issue_events',detail.response.ok,detail.response.status);}
 }
}catch(error){
 const value=String(error?.cause?.code??error?.name??'unknown');
 report.failureCode=/^[a-zA-Z0-9_]{1,80}$/.test(value)?value:'request_failed';
 check('live_flow_completed',false,undefined,report.failureCode);
}
finally{
 for(const publicId of assets){
  if(!users.some(u=>publicId.startsWith(`meal_photos/${u.uid}/`)||publicId.startsWith(`reports/${u.uid}/`)))throw new Error('Cleanup owner guard rejected asset');
  try{const params={public_id:publicId,type:'authenticated',timestamp:String(Math.floor(Date.now()/1000))};const response=await fetchSafe(`https://api.cloudinary.com/v1_1/${encodeURIComponent(config.CLOUDINARY_CLOUD_NAME)}/image/destroy`,{method:'POST',body:new URLSearchParams({...params,api_key:config.CLOUDINARY_API_KEY,signature:await signParams(params,config.CLOUDINARY_API_SECRET)})});const data=await response.json();check('owned_cloud_fixture_cleanup',response.ok&&['ok','not found'].includes(data.result),response.status);}catch{check('owned_cloud_fixture_cleanup',false);}
 }
 for(const user of users){try{const {response}=await identity('delete',{idToken:user.token});check('temporary_firebase_user_cleanup',response.ok,response.status);}catch{check('temporary_firebase_user_cleanup',false);}}
 if(users.length){
  const ids=users.map(u=>{if(!/^acceptance_e2e_[a-f0-9]{32}_[ab]$/.test(u.uid))throw new Error('Cleanup UID guard');return `'${u.uid}'`;}).join(',');
  try{localSql(`DELETE FROM maintenance_jobs WHERE asset_id IN(SELECT id FROM assets WHERE uid IN(${ids}));DELETE FROM assets WHERE uid IN(${ids});DELETE FROM device_tokens WHERE uid IN(${ids});DELETE FROM changes WHERE uid IN(${ids});DELETE FROM sync_operations WHERE uid IN(${ids});DELETE FROM records WHERE uid IN(${ids});DELETE FROM admin_users WHERE uid IN(${ids});DELETE FROM admin_audit_logs WHERE actor_uid IN(${ids});DELETE FROM users WHERE uid IN(${ids});`);check('local_d1_fixture_cleanup',true);}catch{check('local_d1_fixture_cleanup',false);}
 }
 mkdirSync('../artifacts/backend-implementation',{recursive:true});writeFileSync('../artifacts/backend-implementation/'+(remote?'staging-api-smoke.json':'live-api-smoke.json'),JSON.stringify(report,null,2)+'\n');
}
if(report.checks.some(c=>!c.pass))process.exitCode=1;
