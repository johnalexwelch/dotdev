/**
 * Impact / regression corpus: proves the redactor masks real secrets WITHOUT
 * mangling the ordinary tool output the model relies on (git, sql, dbt, json,
 * urls, ids). Run: node --experimental-strip-types impact.test.ts
 */
import { makeRedactor } from "./redactor.ts";

const env = {
  REDSHIFT_PASS: "sf3ciS31GY1uOK6DdeMHAVx2mDqDPqKaja30PWbP22o",
  AWS_SECRET_ACCESS_KEY: "wJalrXUtnFEMIK7MDENGbPxRfiCYEXAMPLEKEY",
} as NodeJS.ProcessEnv;
const r = makeRedactor({ env });

// (label, input) — output MUST differ from input (secret masked)
const MUST_MASK: [string, string][] = [
  ["env literal", `PGPASSWORD=sf3ciS31GY1uOK6DdeMHAVx2mDqDPqKaja30PWbP22o psql -h host`],
  ["aws key literal", `secret is wJalrXUtnFEMIK7MDENGbPxRfiCYEXAMPLEKEY here`],
  ["pg uri password", `postgresql://analytics:hunter2pw@redshift.host:5439/prod`],
  ["password assign", `DB_PASSWORD=SuperSecretValue123`],
  ["token assign", `export GITHUB_TOKEN=ghp_AbCdEf1234567890abcdef`],
];

// (label, input) — output MUST be byte-identical (no false positive)
const MUST_KEEP: [string, string][] = [
  ["git sha", `commit 99b5a3674fb328dc4f73f396288777df23df5112 (HEAD)`],
  ["git short log", `3f46645 Use delete+insert instead of merge for daily active summary`],
  ["pr url", `https://github.com/classdojo/astronomer/pull/9322`],
  ["dbt run", `1 of 3 OK created incremental model analytics_agg.daily_active_summary ... [INSERT 0 12345 in 4.2s]`],
  ["psql rows", ` date_key   | wact\n------------+-------\n 2025-06-01 | 42123`],
  ["json ids", `{"id":"5B8F11F76D9DB5001B228CE200000000","status":"ok","count":42}`],
  ["non-secret env", `PATH=/usr/local/bin:/usr/bin\nHOME=/Users/alexwelch\nSHELL=/bin/zsh`],
  ["pg uri no pass", `postgresql://analytics@redshift.host:5439/prod`],
  ["base64 id blob", `s3://bucket/AKIAIOSFODNN7EXAMPLEabcdef0123456789/file.parquet`],
  ["sql column name", `SELECT user_id, access_key_created_at FROM dim_users WHERE id = 5`],
  ["sql short code", `WHERE api_key = 'abc' AND status = 'ok'`],
  ["python none kwarg", `Client(client_secret=None, timeout=30)`],
  ["yaml bool", `enable_token: true`],
  ["pass count", `tests: pass = 5, fail = 0`],
  ["sql _key idents", `date_key=2025-06-01 sort_key=user_id dist_key=school_id primary_key=id`],
];

let fail = 0;
const note: string[] = [];
for (const [label, input] of MUST_MASK) {
  const out = r(input);
  if (out === input) { fail++; note.push(`  ✗ NOT masked  [${label}]: ${input}`); }
}
for (const [label, input] of MUST_KEEP) {
  const out = r(input);
  if (out !== input) { fail++; note.push(`  ✗ CHANGED     [${label}]\n      in:  ${input}\n      out: ${out}`); }
}

if (fail) { console.log(`impact corpus: ${fail} FAILURE(S)\n` + note.join("\n")); process.exit(1); }
console.log(`impact corpus: PASS (${MUST_MASK.length} masked, ${MUST_KEEP.length} untouched)`);
