import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
const root=resolve(import.meta.dirname,'..');
const campaign=process.argv[2];
if(!/^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/.test(campaign||''))throw new Error('A valid campaign ID is required.');
const raw=resolve(root,'artifacts/artemis-campaigns',campaign);
const baselineBytes=readFileSync(resolve(root,'docs/build-evidence/artemis-summary.json'));
const baseline=JSON.parse(baselineBytes);
const attempts=JSON.parse(readFileSync(resolve(raw,'suite-results.json')));
let reviews=[];try{reviews=JSON.parse(readFileSync(resolve(raw,'adjudication.json')));}catch(e){if(e.code!=='ENOENT')throw e;}
const rows=baseline.cases.flatMap(test=>test.runs.map(original=>{
  const name=`${test.caseId}-R${original.run}`;
  const latest=attempts.filter(a=>a.name===name).at(-1);
  const review=latest&&reviews.find(r=>r.name===name&&r.session===latest.session);
  if(review&&!['PASS','FAIL','BLOCKED','PENDING_REVIEW'].includes(review.result))throw new Error(`Invalid review: ${name}`);
  if(review?.result==='PASS'&&(!review.basis||!review.evidence))throw new Error(`Missing evidence: ${name}`);
  return {name,flow:test.flow,baselineResult:original.result,baselineSession:original.session,
    rerunStatus:review?.result||(latest?'PENDING_REVIEW':'NOT_RUN'),
    currentResult:review?.result==='PASS'?'PASS':original.result,
    resultSource:review?.result==='PASS'?'reviewed_rerun':'historical_baseline',
    ...(latest?{session:latest.session,attempt:latest.attempt,start:latest.start,end:latest.end}:{}),
    agentReportedPass:latest?.reportedSuccess===true,
    assisted:review?.assisted===true,
    ...(review?{basis:review.basis,evidence:review.evidence}:{})};
}));
if(rows.length!==30||new Set(rows.map(r=>r.name)).size!==30)throw new Error('Expected 30 unique historical criteria.');
const passed=rows.filter(r=>r.currentResult==='PASS').length;
const report={campaign,baselineSha256:createHash('sha256').update(baselineBytes).digest('hex'),
  baseline:{passed:baseline.passed,failed:baseline.failed,officialRuns:30,rawAttempts:baseline.rawAttempts},
  rerun:{attempts:attempts.length,distinctRuns:new Set(attempts.map(a=>a.name)).size,
    passed:rows.filter(r=>r.rerunStatus==='PASS').length,
    agentReportedPassed:rows.filter(r=>r.agentReportedPass).length,
    assisted:rows.filter(r=>r.assisted).length,
    failed:rows.filter(r=>r.rerunStatus==='FAIL').length,
    blocked:rows.filter(r=>r.rerunStatus==='BLOCKED').length,pendingReview:rows.filter(r=>r.rerunStatus==='PENDING_REVIEW').length},
  combined:{passed,unresolved:30-passed,reportedPassed:rows.filter(r=>r.baselineResult==='PASS'||r.agentReportedPass).length,passRatePercent:Number((100*passed/30).toFixed(2)),
    basis:'Mixed historical and reviewed rerun evidence. This is not a fresh 30-run campaign.'},runs:rows};
const out=resolve(root,'docs/build-evidence/artemis-remediation');mkdirSync(out,{recursive:true});
writeFileSync(resolve(out,`${campaign}-summary.json`),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({baseline:report.baseline,rerun:report.rerun,combined:report.combined}));
