// Uses the official local ARTEMIS CLI; never substitutes deterministic UI scripts
// for the autonomous agent. Logs/screenshots stay in ignored artifacts.
import {readFileSync,mkdirSync,writeFileSync,createWriteStream} from 'node:fs';
import {spawn} from 'node:child_process';
import {resolve,delimiter} from 'node:path';
import {campaignSettings} from './artemis-campaign.mjs';
const root=resolve(import.meta.dirname,'..');
// --locked-app is a navigation hint, NOT a security boundary. AR13-R3
// launched an unrelated app despite that flag. Bulk unattended runs are retired.
if(process.env.LAB3_ARTEMIS_SUPERVISED!=='1')throw new Error('Unattended ARTEMIS disabled after an out-of-scope launch. A human must supervise every action; see docs/ARTEMIS_RESULTS.md.');
if(!/^AR\d{2}$/.test(process.env.LAB3_ARTEMIS_CASE||'')||! /^[123]$/.test(process.env.LAB3_ARTEMIS_RUN||''))throw new Error('Supervised mode requires exactly one LAB3_ARTEMIS_CASE and LAB3_ARTEMIS_RUN (1..3). Never leave the device unattended.');
const serial=process.env.LAB3_DEVICE_SERIAL;
if(!serial)throw new Error('Set LAB3_DEVICE_SERIAL to the authorized Android device.');
const toolRoot=resolve(root,'../tools/artemis');
const runtime=resolve(root,'artifacts/artemis-runtime');
const cases=JSON.parse(readFileSync(resolve(import.meta.dirname,'artemis-cases.json'),'utf8'));
const {campaign,runs}=campaignSettings(root,process.env,cases);
mkdirSync(runtime,{recursive:true});
mkdirSync(runs,{recursive:true});
const model=process.env.LAB3_ARTEMIS_MODEL||'gemini-3.5-flash-lite';
const config=resolve(runtime,'suite.jsonc');
writeFileSync(config,JSON.stringify({default:{provider:'google',model,fallback:{provider:'google',model:process.env.LAB3_ARTEMIS_FALLBACK_MODEL||model}},flash:{max_turns:40,step_summarizer:{enabled:false}},memory:{chunking:{model},runtime:{retry_limit:1,flush_timeout_s:10}},committee:{enabled:false}}));
const resultPath=resolve(runs,'suite-results.json');
let results=[];try{results=JSON.parse(readFileSync(resultPath,'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
const env={...process.env,ARTEMIS_APP_DIR:runtime,ARTEMIS_ARTEMIS_JSONC:config,ARTEMIS_HELPER_AUTO_INSTALL:'false',ARTEMIS_HIERARCHY_BACKEND:'uiautomator',PYTHONUTF8:'1',PATH:[resolve(process.env.LOCALAPPDATA,'Android/Sdk/platform-tools'),resolve(root,'../tools/scrcpy/scrcpy-win64-v5.0.1'),process.env.PATH].join(delimiter)};
const selected=process.env.LAB3_ARTEMIS_CASE?.split(',');
// Local driver patch verifies ASCII input in the app EditText, not clipboard UI.
env.ARTEMIS_INPUT_VERIFY_PACKAGE='com.longevityplate.longevity_plate';
env.ARTEMIS_SCOPE_PACKAGE='com.longevityplate.longevity_plate';
env.ARTEMIS_SCOPE_NATIVE_PACKAGES=process.env.LAB3_ARTEMIS_CASE==='AR13'?'com.google.android.providers.media.module,com.android.providers.media.module,com.android.providers.media,com.android.documentsui,com.google.android.documentsui,com.android.permissioncontroller,com.google.android.permissioncontroller':'';
suite: for(let run=1;run<=3;run++)for(const test of cases){
 if(run!==Number(process.env.LAB3_ARTEMIS_RUN))continue;
 if(selected&&!selected.includes(test.id))continue;
 const name=`${test.id}-R${run}`;
 const prior=results.filter(r=>r.name===name);const previous=prior.at(-1);
 if(previous&&process.env.LAB3_ARTEMIS_RETRY!=='1')throw new Error(`${name} already attempted in ${campaign}. Review evidence first; explicit LAB3_ARTEMIS_RETRY=1 retains a new attempt.`);
 const attempt=prior.length+1;const traceName=attempt===1?name:`${name}-A${attempt}`;
 const logPath=resolve(runs,traceName+'.log'),log=createWriteStream(logPath);
 const formGuidance=['AR03','AR05','AR13'].includes(test.id)?' FORM NAVIGATION: swipe UP on the WHOLE SCREEN without a target parameter (finger from 70% screen height to 30%) until the actual food text box is fully visible above Save. A partially visible description card label is not the text box. Do not use the photo illustration or a clipped card as a swipe target. If typing fails because the field is not focused, scroll further before trying again.':'';
 if(test.goal.includes('{adminEmail}')&&!process.env.LAB3_ADMIN_EMAIL)throw new Error('Set LAB3_ADMIN_EMAIL to the account approved for device testing.');
 const goal=`Campaign ${campaign}, test ${name}. ${test.goal.replaceAll('{campaign}',campaign).replaceAll('{run}',`${run}_${campaign}`).replaceAll('{adminEmail}',process.env.LAB3_ADMIN_EMAIL||'')}${formGuidance} Use only the app and the specifically required native system UI. Never send messages to other people, change system security settings, or trigger crash. Report concrete observed evidence and PASS/FAIL; do not infer success from taps alone. Read back entered values in the app field itself; keyboard clipboard suggestions are not entered values. Stop if a required precondition is missing.`;
 const args=['run',goal,'--profile','flash','--device-serial',serial,'--test-name',traceName,'--traces-path',runs,'--without-video-recording-tools','--disable-committee','--disable-step-summarizer','--standalone'];
 if(!test.external)args.push('--locked-app','com.longevityplate.longevity_plate');
 const start=new Date().toISOString();console.log(`${start} START ${name}`);
 let output='',timedOut=false;
 const child=spawn(resolve(toolRoot,'.venv/Scripts/artemis.exe'),args,{cwd:runs,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',data=>{log.write(data);output+=data.toString();});
 const timer=setTimeout(()=>{timedOut=true;spawn('taskkill',['/PID',String(child.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});},10*60*1000);
 const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);});clearTimeout(timer);log.end();
 const session=[...output.matchAll(/Session started: ([0-9a-f-]{36})/g)].at(-1)?.[1];
 const reportedSuccess=!timedOut&&/Automation .* is success/.test(output)&&/report_task_status/.test(output);
 const row={campaign,name,caseId:test.id,run,attempt,flow:test.flow,start,end:new Date().toISOString(),exitCode:code,timedOut,reportedSuccess,observedResult:'PENDING_REVIEW',session,log:logPath};
 // Preserve evidence review attached while this supervised attempt was running.
 try{results=JSON.parse(readFileSync(resultPath,'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
 row.model=model;
 results.push(row);writeFileSync(resultPath,JSON.stringify(results,null,2)+'\n');
 console.log(`${row.end} END ${name}: ${reportedSuccess?'AGENT_REPORTED_PASS':'REVIEW_REQUIRED'} session=${session||'none'}`);
 if(timedOut){console.log('Stopped suite after timeout; inspect current device and logs before resuming.');process.exitCode=1;break suite;}
}
console.log('Review raw session screenshots/actions and observed data before publishing success rates.');
