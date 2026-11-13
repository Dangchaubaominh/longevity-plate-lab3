// Run only after explicit project-owner authorization. This adds exactly one
// read-only role, preserving other policy bindings and the IAM etag.
if(!process.argv.includes('--approved'))throw new Error('Explicit approval required; no IAM change performed.');
const path=require('node:path'),fs=require('node:fs');
const cli=process.env.FIREBASE_TOOLS_LIB??path.join(process.env.APPDATA,'npm','node_modules','firebase-tools','lib');
const auth=require(path.join(cli,'auth.js'));const{requireAuth}=require(path.join(cli,'requireAuth.js'));const{Client}=require(path.join(cli,'apiv2.js'));
const project='longevity-plate-beff9',role='roles/firebasecrashlytics.viewer',member='serviceAccount:firebase-adminsdk-fbsvc@longevity-plate-beff9.iam.gserviceaccount.com';
(async()=>{
 const options={project,nonInteractive:true};auth.setActiveAccount(options,auth.getGlobalDefaultAccount());await requireAuth(options);
 const client=new Client({urlPrefix:'https://cloudresourcemanager.googleapis.com',apiVersion:'v1'});
 const current=await client.post(`/projects/${project}:getIamPolicy`,{options:{requestedPolicyVersion:3}},{skipLog:{reqBody:true,resBody:true}});const policy=current.body;
 const bindings=policy.bindings??[];let binding=bindings.find(b=>b.role===role&&!b.condition);let changed=false;
 if(!binding){binding={role,members:[member]};bindings.push(binding);changed=true;}
 else if(!binding.members.includes(member)){binding.members.push(member);changed=true;}
 if(changed)await client.post(`/projects/${project}:setIamPolicy`,{policy:{...policy,bindings}},{skipLog:{reqBody:true,resBody:true}});
 const result={time:new Date().toISOString(),project,role,member,changed,explicitlyApproved:true};const dir=path.join(__dirname,'..','artifacts','backend-implementation');fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'crashlytics-iam-result.json'),JSON.stringify(result,null,2)+'\n');console.log('Crashlytics read-only role '+(changed?'added':'already assigned')+'; other IAM bindings preserved.');
})().catch(()=>{console.log('IAM update failed; private policy and credentials omitted.');process.exitCode=1;});
