// Uses the official local ARTEMIS CLI; never substitutes deterministic UI scripts
// for the autonomous agent. Logs/screenshots stay in ignored artifacts.
import {readFileSync,mkdirSync,writeFileSync,createWriteStream} from 'node:fs';
import {spawn} from 'node:child_process';
import {resolve,delimiter} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const serial=process.env.LAB3_DEVICE_SERIAL;
if(!serial)throw new Error('Set LAB3_DEVICE_SERIAL to the authorized Android device.');
const toolRoot=resolve(root,'../tools/artemis');
const runtime=resolve(root,'artifacts/artemis-runtime');
const runs=resolve(root,'artifacts/artemis-runs');
mkdirSync(runs,{recursive:true});
const model=process.env.LAB3_ARTEMIS_MODEL||'gemini-3.5-flash-lite';
const config=resolve(runtime,'suite.jsonc');
writeFileSync(config,JSON.stringify({default:{provider:'google',model,fallback:{provider:'google',model:'gemini-3-flash-preview'}},flash:{max_turns:40,step_summarizer:{enabled:false}},memory:{chunking:{model},runtime:{retry_limit:1,flush_timeout_s:10}},committee:{enabled:false}}));
const cases=JSON.parse(readFileSync(resolve(import.meta.dirname,'artemis-cases.json'),'utf8'));
const resultPath=resolve(runs,'suite-results.json');
let results=[];try{results=JSON.parse(readFileSync(resultPath,'utf8'));}catch{/* first run */}
const env={...process.env,ARTEMIS_APP_DIR:runtime,ARTEMIS_ARTEMIS_JSONC:config,ARTEMIS_HELPER_AUTO_INSTALL:'false',ARTEMIS_HIERARCHY_BACKEND:'uiautomator',PYTHONUTF8:'1',PATH:[resolve(process.env.LOCALAPPDATA,'Android/Sdk/platform-tools'),resolve(root,'../tools/scrcpy/scrcpy-win64-v5.0.1'),process.env.PATH].join(delimiter)};
const selected=process.env.LAB3_ARTEMIS_CASE?.split(',');
suite: for(let run=1;run<=3;run++)for(const test of cases){
 if(selected&&!selected.includes(test.id))continue;
 const name=`${test.id}-R${run}`;
 const prior=results.filter(r=>r.name===name);const previous=prior.at(-1);
 if(previous?.reportedSuccess&&!previous?.observationRejected)continue;
 const attempt=prior.length+1;const traceName=attempt===1?name:`${name}-A${attempt}`;
 const logPath=resolve(runs,traceName+'.log'),log=createWriteStream(logPath);
 if(test.goal.includes('{adminEmail}')&&!process.env.LAB3_ADMIN_EMAIL)throw new Error('Set LAB3_ADMIN_EMAIL to the account approved for device testing.');
 const goal=`Test ${name}. ${test.goal.replaceAll('{run}',String(run)).replaceAll('{adminEmail}',process.env.LAB3_ADMIN_EMAIL||'')} Use only the app and the specifically required native system UI. Never send messages to other people, change system security settings, or trigger crash. Report concrete observed evidence and PASS/FAIL; do not infer success from taps alone.`;
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
 const row={name,caseId:test.id,run,attempt,flow:test.flow,start,end:new Date().toISOString(),exitCode:code,timedOut,reportedSuccess,session,log:logPath};
 results.push(row);writeFileSync(resultPath,JSON.stringify(results,null,2)+'\n');
 console.log(`${row.end} END ${name}: ${reportedSuccess?'AGENT_REPORTED_PASS':'REVIEW_REQUIRED'} session=${session||'none'}`);
 if(timedOut){console.log('Stopped suite after timeout; inspect current device and logs before resuming.');process.exitCode=1;break suite;}
}
console.log('Review raw session screenshots/actions and observed data before publishing success rates.');
