import test from 'node:test';
import assert from 'node:assert/strict';
import {campaignSettings,failedBaselineRuns} from './artemis-campaign.mjs';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
const cases=[{id:'AR04'}];
const env={LAB3_ARTEMIS_CAMPAIGN:'rerun_20261114',LAB3_ARTEMIS_CASE:'AR04',LAB3_ARTEMIS_RUN:'1'};
test('fresh campaign writes outside historical evidence',()=>{
  const result=campaignSettings('.',env,cases);
  assert.equal(result.runs,resolve('artifacts/artemis-campaigns/rerun_20261114'));
  assert.notEqual(result.runs,resolve('artifacts/artemis-runs'));
  assert.equal(result.test.id,'AR04');
});
test('failure-only plan selects all 14 adjudicated failures and no baseline passes',()=>{
  const baseline=JSON.parse(readFileSync(new URL('../docs/build-evidence/artemis-summary.json',import.meta.url)));
  const failed=failedBaselineRuns(baseline);
  assert.equal(failed.length,14);
  assert.deepEqual(failed.map(row=>`${row.caseId}-R${row.run}`),[
    'AR03-R2','AR03-R3','AR04-R1','AR04-R2','AR04-R3','AR05-R3',
    'AR07-R1','AR07-R2','AR07-R3','AR08-R2','AR08-R3','AR13-R1','AR13-R2','AR13-R3',
  ]);
  assert.ok(failed.every(row=>row.baselineResult==='FAIL'&&row.baselineSession));
  assert.throws(()=>failedBaselineRuns({cases:[]}));
});
test('campaign and case validation rejects missing or escaping destinations',()=>{
  for(const campaign of [undefined,'','../artemis-runs','x/y','x\\y','x'.repeat(65)])
    assert.throws(()=>campaignSettings('.',{...env,LAB3_ARTEMIS_CAMPAIGN:campaign},cases));
  assert.throws(()=>campaignSettings('.',{...env,LAB3_ARTEMIS_CASE:'AR99'},cases));
  assert.throws(()=>campaignSettings('.',{...env,LAB3_ARTEMIS_RUN:'0'},cases));
});
