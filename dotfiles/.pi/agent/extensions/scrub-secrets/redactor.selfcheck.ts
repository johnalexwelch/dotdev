import assert from "node:assert";
import { makeRedactor, _MASK } from "./redactor.ts";

const env = {
  REDSHIFT_PASS: "sf3ciS31GY1uOK6DdeMHAVx2mDqDPqKaja30PWbP22o",
  PI_SCRUB_VARS: "MY_CUSTOM_SECRET",
  MY_CUSTOM_SECRET: "hunter2hunter2",
} as NodeJS.ProcessEnv;

const r = makeRedactor({ env });

// 1. exact env secret value is masked
assert.ok(!r("db pass is sf3ciS31GY1uOK6DdeMHAVx2mDqDPqKaja30PWbP22o now").includes("sf3ciS31"), "env literal not masked");
// 2. custom var via PI_SCRUB_VARS masked
assert.ok(!r("x=hunter2hunter2").includes("hunter2hunter2"), "PI_SCRUB_VARS literal not masked");
// 3. secret-ish assignment: key kept, value masked
assert.strictEqual(r("password=topsecretvalue"), `password=${_MASK}`, "assignment not masked");
assert.strictEqual(r('api_key: "abc123def"'), `api_key: "${_MASK}"`, "api_key not masked");
// 4. DB URI password masked, rest intact
assert.strictEqual(
  r("postgresql://user:pw12345@host:5439/db"),
  `postgresql://user:${_MASK}@host:5439/db`,
  "uri password not masked",
);
// 5. git SHA and ordinary output are left ALONE (no over-redaction)
const sha = "99b5a3674fb328dc4f73f396288777df23df5112";
assert.strictEqual(r(`commit ${sha}`), `commit ${sha}`, "git sha wrongly masked");
assert.strictEqual(r("rows: 12345 date_key=2025-06-01"), "rows: 12345 date_key=2025-06-01", "normal text wrongly masked");

console.log("scrub-secrets redactor self-check: PASS");
