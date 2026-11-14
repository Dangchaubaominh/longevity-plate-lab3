import {resolve} from 'node:path';

// A new campaign must never consume the historical agent's success flags.
export function campaignSettings(root, env, cases) {
  const campaign = env.LAB3_ARTEMIS_CAMPAIGN;
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/.test(campaign || '')) {
    throw new Error('Set a unique LAB3_ARTEMIS_CAMPAIGN (letters, digits, _ or -, max 64 characters).');
  }
  const test = cases.find(item => item.id === env.LAB3_ARTEMIS_CASE);
  if (!test) throw new Error('LAB3_ARTEMIS_CASE must name one of the ten configured cases.');
  if (!/^[123]$/.test(env.LAB3_ARTEMIS_RUN || '')) throw new Error('LAB3_ARTEMIS_RUN must be 1, 2 or 3.');
  return {campaign, test, run: Number(env.LAB3_ARTEMIS_RUN),
    runs: resolve(root, 'artifacts/artemis-campaigns', campaign)};
}

export function failedBaselineRuns(baseline) {
  const rows = baseline.cases.flatMap(test => test.runs.map(run => ({
    caseId: test.caseId, run: run.run, baselineResult: run.result,
    baselineSession: run.session,
  })));
  if (rows.length !== 30 || new Set(rows.map(row => `${row.caseId}-R${row.run}`)).size !== 30)
    throw new Error('Baseline must contain exactly 30 unique case/run pairs.');
  return rows.filter(row => row.baselineResult === 'FAIL');
}
