// Windows local setup helper, using the installed Firebase CLI's authenticated
// client. No token is exported or printed. Does not modify IAM or billing.
const path=require('node:path');
const fs=require('node:fs');
const project='longevity-plate-beff9';
const cli=process.env.FIREBASE_TOOLS_LIB??path.join(process.env.APPDATA,'npm','node_modules','firebase-tools','lib');
const auth=require(path.join(cli,'auth.js'));
const {requireAuth}=require(path.join(cli,'requireAuth.js'));
const {Client}=require(path.join(cli,'apiv2.js'));
const {ensure}=require(path.join(cli,'ensureApiEnabled.js'));
const report={project};
(async()=>{
 const options={project,nonInteractive:true};const account=auth.getGlobalDefaultAccount();if(!account)throw new Error('Firebase CLI login required');
 auth.setActiveAccount(options,account);await requireAuth(options);
 try{await ensure(project,'firebasecrashlytics.googleapis.com','lab3',true);report.crashApiEnabled=true;console.log('Crashlytics REST API enabled.');}catch(e){report.crashApiEnabled=false;console.log('Crashlytics API enable failed; no billing or IAM change attempted.');}
 const host=process.env.LAB3_WORKER_HOST;
 if(!host||!/^[a-z0-9.-]+\.workers\.dev$/.test(host))throw new Error('Expected staging workers.dev hostname');
 const configClient=new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'admin/v2'});
 const config=await configClient.get(`/projects/${project}/config`,{skipLog:{resBody:true}});
 const domains=config.body.authorizedDomains??[];
 if(!domains.includes(host))await configClient.patch(`/projects/${project}/config`,{authorizedDomains:[...domains,host]},{queryParams:{updateMask:'authorizedDomains'},skipLog:{reqBody:true,resBody:true}});
 report.authorizedDomain=host;console.log('Firebase Auth authorized domain configured: '+host);
 const email=process.env.LAB3_ADMIN_EMAIL;
 if(!email||!email.includes('@'))throw new Error('Admin target email required');
 const usersClient=new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'v1'});
 const result=await usersClient.post(`/projects/${project}/accounts:lookup`,{email:[email]},{skipLog:{reqBody:true,resBody:true}});
 const user=(result.body.users??[]).find(u=>u.email?.toLowerCase()===email.toLowerCase());
 if(user){report.admin={uid:user.localId,emailVerified:user.emailVerified===true,googleProvider:(user.providerUserInfo??[]).some(p=>p.providerId==='google.com')};console.log('Target Firebase UID: '+user.localId+'; verified Google account: '+(report.admin.emailVerified&&report.admin.googleProvider));}
 else{report.admin=null;console.log('Target email has not signed into this Firebase project yet.');}
})().catch(()=>{report.setupError=true;console.log('Firebase setup request failed; private response omitted.');process.exitCode=1;}).finally(()=>{
 const dir=path.join(__dirname,'..','artifacts','backend-implementation');fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'firebase-staging-setup.json'),JSON.stringify(report,null,2)+'\n');
});
