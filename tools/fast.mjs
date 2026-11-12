#!/usr/bin/env node
// Bot CLI for the Fast app. Writes straight to Firestore with the Firebase CLI's
// signed-in owner account (no secrets stored here). See ../README.md.
import { createRequire } from "node:module";
import { readFileSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

process.env.TZ ||= "America/Santo_Domingo";
const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const cfgPath = join(here, "config.json");
const cfg = existsSync(cfgPath) ? JSON.parse(readFileSync(cfgPath, "utf8")) : {};
const PROJECT = process.env.FAST_PROJECT || cfg.projectId;
const EMAIL = process.env.FAST_EMAIL || cfg.email || null;
const EMU = process.env.FIRESTORE_EMULATOR_HOST;
if (!PROJECT) die("No project configured. Set projectId in tools/config.json or FAST_PROJECT.");

/* ---------- args ---------- */
const [cmd, ...rest] = process.argv.slice(2);
const args = { _: [] };
for (let i = 0; i < rest.length; i++) {
  const a = rest[i];
  if (a.startsWith("--")) {
    const k = a.slice(2);
    const v = rest[i + 1] && !rest[i + 1].startsWith("--") ? rest[++i] : true;
    args[k] = v;
  } else args._.push(a);
}
function die(m) { console.error(`error: ${m}`); process.exit(1); }
const out = (o) => console.log(JSON.stringify(o, null, 2));
function parseWhen(s) {
  if (!s || s === true) return new Date();
  // "YYYY-MM-DD HH:mm" or ISO; no offset => America/Santo_Domingo (UTC-4, no DST)
  let t = String(s).trim().replace(" ", "T");
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/.test(t)) t += "-04:00";
  const d = new Date(t);
  if (isNaN(d)) die(`Can't parse time "${s}". Use ISO or "YYYY-MM-DD HH:mm" (UTC-4).`);
  return d;
}
const numArg = (v) => (v === undefined ? undefined : v === "null" || v === "" ? null : Number(v));

/* ---------- Firestore REST ---------- */
let client;
async function api(method, path, body, queryParams) {
  if (EMU) {
    const url = new URL(`http://${EMU}/v1/${path}`);
    if (queryParams) for (const [k, v] of Object.entries(queryParams)) [].concat(v).forEach((x) => url.searchParams.append(k, x));
    const r = await fetch(url, { method, headers: { Authorization: "Bearer owner", "Content-Type": "application/json" }, body: body ? JSON.stringify(body) : undefined });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(`${r.status} ${JSON.stringify(j)}`);
    return j;
  }
  if (!client) {
    const auth = require("firebase-tools/lib/auth");
    const { requireAuth } = require("firebase-tools/lib/requireAuth");
    const { Client } = require("firebase-tools/lib/apiv2");
    const acct = auth.getGlobalDefaultAccount();
    if (!acct) die("Firebase CLI isn't logged in on this box. Run: npx -y firebase-tools@latest login --no-localhost");
    await requireAuth({ user: acct.user, tokens: acct.tokens, project: PROJECT });
    client = new Client({ urlPrefix: "https://firestore.googleapis.com", apiVersion: "v1" });
  }
  let qp;
  if (queryParams) { qp = new URLSearchParams(); for (const [k, v] of Object.entries(queryParams)) [].concat(v).forEach((x) => qp.append(k, x)); }
  const r = await client.request({ method, path: `/${path}`, body, queryParams: qp });
  return r.body;
}
const ROOT = `projects/${PROJECT}/databases/(default)/documents`;
const enc = (v) => {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === "number") return { doubleValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "object") return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, enc(x)])) } };
  return { stringValue: String(v) };
};
const dec = (v) => {
  if (!v) return null;
  if ("nullValue" in v) return null;
  if ("timestampValue" in v) return v.timestampValue;
  if ("doubleValue" in v) return Number(v.doubleValue);
  if ("integerValue" in v) return Number(v.integerValue);
  if ("stringValue" in v) return v.stringValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("mapValue" in v) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, dec(x)]));
  return v;
};
const docOut = (d) => ({ id: d.name.split("/").pop(), ...Object.fromEntries(Object.entries(d.fields || {}).map(([k, v]) => [k, dec(v)])) });
const fields = (o) => Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined).map(([k, v]) => [k, enc(v)]));
const STAMP = () => ({ updatedAt: new Date() });

async function create(coll, data) {
  return docOut(await api("POST", `${ROOT}/${coll}`, { fields: fields({ ...data, createdAt: new Date(), ...STAMP() }) }));
}
async function patch(path, data) {
  const f = fields({ ...data, ...STAMP() });
  return docOut(await api("PATCH", `${ROOT}/${path}`, { fields: f }, { "updateMask.fieldPaths": Object.keys(f), "currentDocument.exists": "true" }));
}
async function query(parent, structuredQuery) {
  const r = await api("POST", `${parent}:runQuery`, { structuredQuery });
  return (r || []).filter((x) => x.document).map((x) => docOut(x.document));
}

/* ---------- user resolution ---------- */
async function uid() {
  if (process.env.FAST_UID || cfg.uid) return process.env.FAST_UID || cfg.uid;
  const users = await query(ROOT, { from: [{ collectionId: "users" }], limit: 50 });
  const pick = EMAIL ? users.filter((u) => (u.email || "").toLowerCase() === EMAIL.toLowerCase()) : users;
  if (pick.length === 1) return pick[0].id;
  if (!users.length) die("Nobody has signed in to the app yet. Open the app and sign in with Google first.");
  die(`Can't pick a user (${pick.length} match). Set "email" or "uid" in tools/config.json. Users: ${users.map((u) => u.email).join(", ")}`);
}

/* ---------- helpers ---------- */
async function fastsList(u, n = 20) {
  return query(`${ROOT}/users/${u}`, { from: [{ collectionId: "fasts" }], orderBy: [{ field: { fieldPath: "start" }, direction: "DESCENDING" }], limit: n });
}
async function settings(u) {
  const r = await api("GET", `${ROOT}/users/${u}/settings/main`).catch(() => null);
  return r?.fields ? docOut(r) : { targets: { protein_g: 120 }, defaultFastHours: 24 };
}
const hrs = (a, b) => Math.round(((new Date(b) - new Date(a)) / 3600e3) * 100) / 100;
function dayRange(s) {
  const d = s && s !== true ? new Date(`${s}T00:00:00-04:00`) : new Date(new Date().toLocaleDateString("en-CA") + "T00:00:00-04:00");
  return [d, new Date(+d + 86400e3)];
}
async function mealsBetween(u, a, b) {
  return query(`${ROOT}/users/${u}`, {
    from: [{ collectionId: "meals" }],
    where: { compositeFilter: { op: "AND", filters: [
      { fieldFilter: { field: { fieldPath: "time" }, op: "GREATER_THAN_OR_EQUAL", value: enc(a) } },
      { fieldFilter: { field: { fieldPath: "time" }, op: "LESS_THAN", value: enc(b) } },
    ] } },
    orderBy: [{ field: { fieldPath: "time" }, direction: "ASCENDING" }],
  });
}
function photoDataUrl(path) {
  // 560px JPEG thumbnail, under Firestore's doc-size budget (same as the app).
  const py = `import sys,io,base64\nfrom PIL import Image,ImageOps\nim=ImageOps.exif_transpose(Image.open(sys.argv[1])).convert('RGB')\nim.thumbnail((560,560))\nfor q in (72,60,45,30):\n b=io.BytesIO(); im.save(b,'JPEG',quality=q); s='data:image/jpeg;base64,'+base64.b64encode(b.getvalue()).decode()\n if len(s)<300000: print(s); break`;
  return execFileSync("python3", ["-c", py, path], { encoding: "utf8", maxBuffer: 1e7 }).trim() || null;
}
const strip = (m) => { const { photo, ...r } = m; return { ...r, hasPhoto: !!photo }; };

/* ---------- commands ---------- */
const cmds = {
  async whoami() { out({ project: PROJECT, uid: await uid(), emulator: !!EMU }); },

  async status() {
    const u = await uid();
    const [fasts, s] = await Promise.all([fastsList(u, 5), settings(u)]);
    const active = fasts.find((f) => !f.end);
    const [a, b] = dayRange(args.date);
    const meals = await mealsBetween(u, a, b);
    const t = { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 };
    meals.forEach((m) => Object.keys(t).forEach((k) => (t[k] += Number(m[k]) || 0)));
    out({
      activeFast: active ? { ...active, elapsedHours: hrs(active.start, new Date()) } : null,
      lastFast: fasts.find((f) => f.end) || null,
      day: a.toLocaleDateString("en-CA"), totals: t, targets: s.targets, mealCount: meals.length,
    });
  },

  async "start-fast"() {
    const u = await uid();
    const active = (await fastsList(u, 5)).find((f) => !f.end);
    if (active && !args.force) die(`A fast is already running (id ${active.id}, started ${active.start}). End it first or pass --force.`);
    const s = await settings(u);
    const f = await create(`users/${u}/fasts`, {
      start: parseWhen(args.at), end: null, targetHours: numArg(args.hours) ?? s.defaultFastHours ?? 24,
      notes: args.notes === true ? "" : args.notes || "", source: "bot",
    });
    out(f);
  },

  async "end-fast"() {
    const u = await uid();
    const active = args.id ? { id: args.id } : (await fastsList(u, 5)).find((f) => !f.end);
    if (!active) die("No fast is running.");
    const data = { end: parseWhen(args.at) };
    if (typeof args.notes === "string") data.notes = args.notes;
    const f = await patch(`users/${u}/fasts/${active.id}`, data);
    out({ ...f, durationHours: hrs(f.start, f.end), hitTarget: hrs(f.start, f.end) >= f.targetHours });
  },

  async "edit-fast"() {
    const u = await uid();
    const id = args._[0] || die("Usage: edit-fast <id> [--start T] [--end T|null] [--hours N] [--notes S]");
    const d = {};
    if (args.start) d.start = parseWhen(args.start);
    if (args.end) d.end = args.end === "null" ? null : parseWhen(args.end);
    if (args.hours) d.targetHours = Number(args.hours);
    if (typeof args.notes === "string") d.notes = args.notes;
    out(await patch(`users/${u}/fasts/${id}`, d));
  },

  async "set-target"() {
    const u = await uid();
    const active = (await fastsList(u, 5)).find((f) => !f.end);
    if (!active) die("No fast is running.");
    out(await patch(`users/${u}/fasts/${active.id}`, { targetHours: Number(args.hours || die("--hours required")) }));
  },

  async "list-fasts"() { out(await fastsList(await uid(), Number(args.n || 20))); },

  async "delete-fast"() {
    const u = await uid();
    await api("DELETE", `${ROOT}/users/${u}/fasts/${args._[0] || die("Usage: delete-fast <id>")}`);
    out({ deleted: args._[0] });
  },

  async "add-meal"() {
    const u = await uid();
    if (!args.desc || args.desc === true) die('--desc "what was eaten" is required');
    const photo = args.photo && args.photo !== true ? photoDataUrl(args.photo) : null;
    const m = await create(`users/${u}/meals`, {
      time: parseWhen(args.at), description: args.desc,
      calories: numArg(args.cal) ?? null, protein_g: numArg(args.protein) ?? null,
      carbs_g: numArg(args.carbs) ?? null, fat_g: numArg(args.fat) ?? null,
      source: args.source || (photo ? "photo" : "manual"), notes: typeof args.notes === "string" ? args.notes : "",
      photo,
    });
    out(strip(m));
  },

  async "edit-meal"() {
    const u = await uid();
    const id = args._[0] || die("Usage: edit-meal <id> [--desc] [--at] [--cal] [--protein] [--carbs] [--fat] [--notes] [--photo path]");
    const d = {};
    if (args.desc) d.description = args.desc;
    if (args.at) d.time = parseWhen(args.at);
    for (const [a, k] of [["cal", "calories"], ["protein", "protein_g"], ["carbs", "carbs_g"], ["fat", "fat_g"]]) if (args[a] !== undefined) d[k] = numArg(args[a]);
    if (typeof args.notes === "string") d.notes = args.notes;
    if (args.photo) d.photo = args.photo === "null" ? null : photoDataUrl(args.photo);
    out(strip(await patch(`users/${u}/meals/${id}`, d)));
  },

  async "list-meals"() {
    const u = await uid();
    const [a, b] = dayRange(args.date);
    out((await mealsBetween(u, a, b)).map(strip));
  },

  async "delete-meal"() {
    const u = await uid();
    await api("DELETE", `${ROOT}/users/${u}/meals/${args._[0] || die("Usage: delete-meal <id>")}`);
    out({ deleted: args._[0] });
  },

  async "set-targets"() {
    const u = await uid();
    const s = await settings(u);
    const t = { calories: null, protein_g: 120, carbs_g: null, fat_g: null, ...(s.targets || {}) };
    for (const [a, k] of [["cal", "calories"], ["protein", "protein_g"], ["carbs", "carbs_g"], ["fat", "fat_g"]]) if (args[a] !== undefined) t[k] = numArg(args[a]);
    const d = { targets: t };
    if (args["default-hours"]) d.defaultFastHours = Number(args["default-hours"]);
    const r = await api("PATCH", `${ROOT}/users/${u}/settings/main`, { fields: fields({ ...d, ...STAMP() }) }, { "updateMask.fieldPaths": Object.keys(fields({ ...d, ...STAMP() })) });
    out(docOut(r));
  },
};

if (!cmd || !cmds[cmd]) {
  console.log(`Usage: node fast.mjs <command> [options]
  whoami | status [--date YYYY-MM-DD]
  start-fast [--at T] [--hours N] [--notes S] [--force]
  end-fast [--at T] [--notes S] [--id ID]
  set-target --hours N            (active fast)
  edit-fast <id> [--start T] [--end T|null] [--hours N] [--notes S]
  list-fasts [--n 20] | delete-fast <id>
  add-meal --desc S [--at T] [--cal N] [--protein N] [--carbs N] [--fat N] [--source photo|manual] [--photo path] [--notes S]
  edit-meal <id> [...same flags]  | list-meals [--date YYYY-MM-DD] | delete-meal <id>
  set-targets [--cal N|null] [--protein N] [--carbs N|null] [--fat N|null] [--default-hours N]
Times: ISO, or "YYYY-MM-DD HH:mm" in America/Santo_Domingo (UTC-4). Default: now.`);
  process.exit(cmd ? 1 : 0);
}
await cmds[cmd]().catch((e) => die(e.message));
