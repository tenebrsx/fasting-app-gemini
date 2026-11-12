// Fast — fasting timer + macro log. Firebase Auth (Google) + Firestore.
const V = "13.3.0";
const { initializeApp } = await import(`https://www.gstatic.com/firebasejs/${V}/firebase-app.js`);
const A = await import(`https://www.gstatic.com/firebasejs/${V}/firebase-auth.js`);
const F = await import(`https://www.gstatic.com/firebasejs/${V}/firebase-firestore.js`);

/* ---------- config ---------- */
const isLocal = ["localhost", "127.0.0.1"].includes(location.hostname);
const useEmulators = isLocal && new URLSearchParams(location.search).has("emu");

async function loadConfig() {
  try {
    const r = await fetch("/__/firebase/init.json", { cache: "no-store" });
    if (r.ok) return await r.json();
  } catch {}
  const r = await fetch("/firebase-config.json", { cache: "no-store" });
  if (!r.ok) throw new Error("Missing Firebase config");
  return r.json();
}
const config = await loadConfig();
// Serve the auth handler from our own domain so redirect sign-in works in
// installed (home-screen) apps and Safari, which block third-party storage.
if (/\.(web\.app|firebaseapp\.com)$/.test(location.hostname)) config.authDomain = location.host;

const fbApp = initializeApp(config);
const auth = A.getAuth(fbApp);
let db;
try {
  db = F.initializeFirestore(fbApp, {
    localCache: F.persistentLocalCache({ tabManager: F.persistentMultipleTabManager() }),
  });
} catch {
  db = F.getFirestore(fbApp);
}
if (useEmulators) {
  A.connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  F.connectFirestoreEmulator(db, "127.0.0.1", 8080);
  window.__fast = { auth, A }; // local emulator testing only
}

/* ---------- helpers ---------- */
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const pad = (n) => String(n).padStart(2, "0");
const HOUR = 3600e3, DAY = 86400e3;
const toDate = (v) => (v == null ? null : v.toDate ? v.toDate() : v instanceof Date ? v : new Date(v));
const num = (v) => (v === "" || v == null || Number.isNaN(Number(v)) ? null : Number(v));
const round = (v) => Math.round(v ?? 0);

function hms(ms) {
  ms = Math.max(0, ms);
  const s = Math.floor(ms / 1000);
  return `${pad(Math.floor(s / 3600))}:${pad(Math.floor((s % 3600) / 60))}:${pad(s % 60)}`;
}
function dur(ms) {
  const m = Math.round(ms / 60000);
  const h = Math.floor(m / 60), mm = m % 60;
  return h ? `${h}h ${pad(mm)}m` : `${mm}m`;
}
const fmtTime = new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" });
const fmtDayTime = new Intl.DateTimeFormat(undefined, { weekday: "short", hour: "numeric", minute: "2-digit" });
const fmtDate = new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric" });
const fmtFull = new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
function smartTime(d) {
  const now = new Date();
  if (sameDay(d, now)) return `Today ${fmtTime.format(d)}`;
  if (sameDay(d, new Date(now - DAY))) return `Yesterday ${fmtTime.format(d)}`;
  if (sameDay(d, new Date(+now + DAY))) return `Tomorrow ${fmtTime.format(d)}`;
  return Math.abs(now - d) < 6 * DAY ? fmtDayTime.format(d) : fmtFull.format(d);
}
const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const sameDay = (a, b) => startOfDay(a).getTime() === startOfDay(b).getTime();
const toInput = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
const fromInput = (s) => (s ? new Date(s) : null);
const cssVar = (n) => getComputedStyle(document.documentElement).getPropertyValue(n).trim();

function toast(msg) {
  const t = $("#toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toast.t);
  toast.t = setTimeout(() => t.classList.remove("show"), 2200);
}

/* ---------- zones (approximations) ---------- */
const ZONES = [
  { h: 0, name: "Blood sugar settling", desc: "Digesting your last meal; insulin coming down.", c: "--sky" },
  { h: 12, name: "Glycogen depleting", desc: "Liver glycogen runs low; the body leans on fat.", c: "--ember" },
  { h: 18, name: "Fat burning", desc: "Fat becomes a main fuel and ketones start rising.", c: "--coral" },
  { h: 24, name: "Autophagy", desc: "Cellular cleanup is thought to pick up around here.", c: "--orchid" },
  { h: 36, name: "Deeper autophagy", desc: "Ketones keep climbing; hunger often eases.", c: "--orchid", alt: 0.7 },
  { h: 48, name: "Deep ketosis", desc: "Growth hormone is reported to rise. Mind electrolytes.", c: "--teal" },
  { h: 72, name: "Prolonged fast", desc: "Extended territory. Electrolytes and how you feel come first.", c: "--teal", alt: 0.7 },
];
const zoneAt = (h) => [...ZONES].reverse().find((z) => h >= z.h) || ZONES[0];
const PRESETS = [16, 18, 24, 36, 48, 72];

/* ---------- state ---------- */
const state = {
  user: null,
  fasts: [],
  meals: [],
  settings: { targets: { calories: null, protein_g: 120, carbs_g: null, fat_g: null }, defaultFastHours: 24 },
  selectedHours: null,
  day: startOfDay(new Date()),
  chartKey: "protein_g",
  tab: "timer",
  unsub: [],
  pending: { fasts: false, meals: false },
};
const activeFast = () => state.fasts.find((f) => !f.end);
const lastEnded = () => state.fasts.find((f) => f.end);
const uref = () => F.doc(db, "users", state.user.uid);
const col = (name) => F.collection(db, "users", state.user.uid, name);

/* ---------- auth ---------- */
const standalone = matchMedia("(display-mode: standalone)").matches || navigator.standalone;
$("#btn-google").addEventListener("click", async () => {
  $("#signin-error").textContent = "";
  const provider = new A.GoogleAuthProvider();
  provider.setCustomParameters({ prompt: "select_account" });
  try {
    if (standalone) await A.signInWithRedirect(auth, provider);
    else await A.signInWithPopup(auth, provider);
  } catch (e) {
    if (["auth/popup-blocked", "auth/operation-not-supported-in-this-environment", "auth/cancelled-popup-request"].includes(e.code)) {
      try { await A.signInWithRedirect(auth, provider); return; } catch (e2) { e = e2; }
    }
    if (e.code !== "auth/popup-closed-by-user") $("#signin-error").textContent = `Sign-in failed (${e.code || e.message}). Try again.`;
  }
});
A.getRedirectResult(auth).catch((e) => ($("#signin-error").textContent = `Sign-in failed (${e.code || e.message}).`));
$("#btn-signout").addEventListener("click", () => A.signOut(auth));

A.onAuthStateChanged(auth, async (user) => {
  state.unsub.forEach((u) => u());
  state.unsub = [];
  state.user = user;
  $("#boot").hidden = true;
  $("#signin").hidden = !!user;
  $("#app").hidden = !user;
  if (!user) return;
  $("#acct-email").textContent = user.email || user.displayName || user.uid;
  F.setDoc(uref(), { email: user.email || null, name: user.displayName || null, lastSeen: F.serverTimestamp() }, { merge: true }).catch(() => {});
  subscribe();
});

/* ---------- data ---------- */
function subscribe() {
  const meta = { includeMetadataChanges: true };
  state.unsub.push(
    F.onSnapshot(F.doc(col("settings"), "main"), (s) => {
      if (!s.exists()) {
        if (!s.metadata.fromCache) F.setDoc(s.ref, { ...state.settings, updatedAt: F.serverTimestamp() }).catch(() => {});
      } else {
        const d = s.data();
        state.settings = {
          targets: { calories: null, protein_g: 120, carbs_g: null, fat_g: null, ...(d.targets || {}) },
          defaultFastHours: d.defaultFastHours || 24,
        };
      }
      fillSettingsForm();
      renderAll();
    }),
    F.onSnapshot(F.query(col("fasts"), F.orderBy("start", "desc"), F.limit(500)), meta, (s) => {
      state.fasts = s.docs.map((d) => ({ id: d.id, ...d.data(), start: toDate(d.data().start), end: toDate(d.data().end) })).filter((f) => f.start);
      state.pending.fasts = s.metadata.hasPendingWrites;
      renderAll();
    }, onErr),
    F.onSnapshot(
      F.query(col("meals"), F.where("time", ">=", F.Timestamp.fromDate(new Date(Date.now() - 120 * DAY))), F.orderBy("time", "desc")),
      meta,
      (s) => {
        state.meals = s.docs.map((d) => ({ id: d.id, ...d.data(), time: toDate(d.data().time) })).filter((m) => m.time);
        state.pending.meals = s.metadata.hasPendingWrites;
        renderAll();
      },
      onErr
    )
  );
}
function onErr(e) { console.error(e); toast(`Couldn't load data: ${e.code || e.message}`); }

/* ---------- tabs ---------- */
$$(".tabbar button").forEach((b) =>
  b.addEventListener("click", () => {
    state.tab = b.dataset.tab;
    $$(".tabbar button").forEach((x) => x.classList.toggle("on", x === b));
    $$(".view").forEach((v) => (v.hidden = v.dataset.view !== state.tab));
    scrollTo(0, 0);
    renderAll();
  })
);

function renderAll() {
  if (!state.user) return;
  $("#sync-dot").classList.toggle("off", state.pending.fasts || state.pending.meals || !navigator.onLine);
  renderTimer();
  if (state.tab === "macros") renderMacros();
  if (state.tab === "history") renderHistory();
}

/* ---------- timer ---------- */
const R = 138, CX = 160, CY = 160;
const pt = (f, r = R) => {
  const a = f * 2 * Math.PI - Math.PI / 2;
  return [CX + r * Math.cos(a), CY + r * Math.sin(a)];
};
function arcPath(f0, f1) {
  f1 = Math.min(f1, 0.99999);
  if (f1 <= f0) return "";
  const [x0, y0] = pt(f0), [x1, y1] = pt(f1);
  return `M${x0.toFixed(2)} ${y0.toFixed(2)} A${R} ${R} 0 ${f1 - f0 > 0.5 ? 1 : 0} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}`;
}
function targetHours() {
  const f = activeFast();
  return f ? f.targetHours || state.settings.defaultFastHours : state.selectedHours || state.settings.defaultFastHours;
}

let lastTicksKey = "";
function renderTimer() {
  const f = activeFast();
  const now = Date.now();
  const T = targetHours();
  const elapsedMs = f ? now - f.start : 0;
  const eh = elapsedMs / HOUR;
  const frac = f ? Math.min(eh / T, 1) : 0;

  // arcs coloured by zone
  let arcs = "";
  if (f) {
    ZONES.forEach((z, i) => {
      const zEnd = ZONES[i + 1]?.h ?? Infinity;
      if (z.h >= T) return;
      const a = z.h / T, b = Math.min(zEnd, T, Math.max(eh, 0)) / T;
      if (b > a) arcs += `<path class="ring-arc" d="${arcPath(a, b)}" stroke="${cssVar(z.c)}" stroke-opacity="${z.alt || 1}"/>`;
    });
  }
  $("#ring-arcs").innerHTML = arcs;

  // zone ticks
  const ticksKey = `${T}|${!!f}`;
  if (ticksKey !== lastTicksKey) {
    lastTicksKey = ticksKey;
    $("#ring-ticks").innerHTML = ZONES.filter((z) => f && z.h > 0 && z.h < T)
      .map((z) => {
        const [x, y] = pt(z.h / T), [lx, ly] = pt(z.h / T, R - 26);
        return `<circle class="ring-tick-dot" cx="${x}" cy="${y}" r="4" fill="var(--bg)"/><text class="ring-tick-label" x="${lx}" y="${ly}">${z.h}h</text>`;
      })
      .join("");
  }
  const head = $("#ring-head");
  head.style.opacity = f ? 1 : 0;
  const [hx, hy] = pt(frac === 1 ? 0.99999 : frac);
  head.setAttribute("cx", hx);
  head.setAttribute("cy", hy);

  const btn = $("#btn-fast");
  if (f) {
    const done = eh >= T;
    $("#timer-title").textContent = "Fasting";
    $("#ring-caption").textContent = done ? "Goal reached" : "Elapsed";
    $("#ring-time").textContent = hms(elapsedMs);
    $("#ring-sub").innerHTML = done
      ? `<b>+${hms(elapsedMs - T * HOUR)}</b> past ${T}h`
      : `<b>${Math.floor(frac * 100)}%</b> of ${T}h · ${hms(T * HOUR - elapsedMs)} left`;
    const z = zoneAt(eh);
    $("#zone-now").innerHTML = `<span class="dot" style="background:${cssVar(z.c)}"></span><span><b>${esc(z.name)}</b> · ${esc(z.desc)}</span>`;
    $("#t-start").textContent = smartTime(f.start);
    $("#btn-edit-start").disabled = false;
    $("#t-goal-label").textContent = "Goal";
    $("#t-goal").textContent = smartTime(new Date(+f.start + T * HOUR));
    $("#t-goal-hint").textContent = `${T}h`;
    btn.textContent = "End fast";
    btn.classList.add("ending");
  } else {
    const le = lastEnded();
    $("#timer-title").textContent = "Not fasting";
    $("#ring-caption").textContent = le ? "Since your last fast" : "Ready when you are";
    $("#ring-time").textContent = le ? hms(now - le.end) : "00:00:00";
    $("#ring-sub").innerHTML = `Next fast: <b>${T}h</b>`;
    $("#zone-now").textContent = le ? `Last fast: ${dur(le.end - le.start)}, ended ${smartTime(le.end)}` : "";
    $("#t-start").textContent = "—";
    $("#btn-edit-start").disabled = true;
    $("#t-goal-label").textContent = "Goal if you start now";
    $("#t-goal").textContent = smartTime(new Date(now + T * HOUR));
    $("#t-goal-hint").textContent = "";
    btn.textContent = `Start ${T}h fast`;
    btn.classList.remove("ending");
  }

  // presets
  const presetsKey = `${T}|${PRESETS.includes(T)}`;
  if ($("#presets").dataset.k !== presetsKey) {
    $("#presets").dataset.k = presetsKey;
    const custom = !PRESETS.includes(T);
    $("#presets").innerHTML =
      PRESETS.map((h) => `<button class="preset ${h === T ? "on" : ""}" role="radio" aria-checked="${h === T}" data-h="${h}">${h}h</button>`).join("") +
      `<button class="preset ${custom ? "on" : ""}" role="radio" aria-checked="${custom}" data-h="custom">${custom ? `${T}h` : "Custom"}</button>`;
  }

  // zone list
  const zl = ZONES.filter((z) => z.h > 0)
    .map((z) => {
      const reached = f && eh >= z.h;
      return `<li class="${reached ? "reached" : ""} ${z.h > T ? "dim" : ""}"><span class="h">${z.h}h</span><span>${esc(z.name)}<span class="d">${esc(z.desc)}</span></span><span class="st" style="${reached ? `background:${cssVar(z.c)}` : ""}"></span></li>`;
    })
    .join("");
  if ($("#zone-list").innerHTML !== zl) $("#zone-list").innerHTML = zl;
}

$("#presets").addEventListener("click", async (e) => {
  const b = e.target.closest(".preset");
  if (!b) return;
  if (b.dataset.h === "custom") {
    openSheet({
      title: "Custom fast length",
      body: `<label>Hours <input name="h" type="number" inputmode="decimal" min="1" max="240" step="0.5" value="${targetHours()}" required></label>`,
      onSubmit: async (fd) => setTarget(Number(fd.get("h"))),
    });
  } else setTarget(Number(b.dataset.h));
});
async function setTarget(h) {
  if (!(h > 0 && h <= 240)) throw new Error("Pick between 1 and 240 hours.");
  const f = activeFast();
  state.selectedHours = h;
  if (f) await F.updateDoc(F.doc(col("fasts"), f.id), { targetHours: h, updatedAt: F.serverTimestamp() });
  renderTimer();
}

$("#btn-fast").addEventListener("click", async () => {
  const f = activeFast();
  if (!f) {
    await F.addDoc(col("fasts"), {
      start: F.Timestamp.fromDate(new Date()), end: null, targetHours: targetHours(), notes: "", source: "app",
      createdAt: F.serverTimestamp(), updatedAt: F.serverTimestamp(),
    });
    toast(`Fast started · ${targetHours()}h goal`);
    return;
  }
  const now = new Date();
  openSheet({
    title: "End fast",
    okText: "End fast",
    body: `
      <p class="fine">You've fasted <b>${dur(now - f.start)}</b> of your ${f.targetHours}h goal.</p>
      <label>Ended at <input name="end" type="datetime-local" value="${toInput(now)}" required></label>
      <label>Notes <textarea name="notes" placeholder="How did it go?">${esc(f.notes)}</textarea></label>`,
    onSubmit: async (fd) => {
      const end = fromInput(fd.get("end"));
      if (end <= f.start) throw new Error("End time has to be after the start.");
      if (end > new Date(Date.now() + 60e3)) throw new Error("End time can't be in the future.");
      await F.updateDoc(F.doc(col("fasts"), f.id), { end: F.Timestamp.fromDate(end), notes: fd.get("notes") || "", updatedAt: F.serverTimestamp() });
      toast(`Fast ended · ${dur(end - f.start)}`);
    },
  });
});

$("#btn-edit-start").addEventListener("click", () => {
  const f = activeFast();
  if (!f) return;
  openSheet({
    title: "Edit start time",
    body: `<label>Started at <input name="start" type="datetime-local" value="${toInput(f.start)}" required></label>`,
    onSubmit: async (fd) => {
      const s = fromInput(fd.get("start"));
      if (s > new Date()) throw new Error("Start time can't be in the future.");
      await F.updateDoc(F.doc(col("fasts"), f.id), { start: F.Timestamp.fromDate(s), updatedAt: F.serverTimestamp() });
      toast("Start time updated");
    },
  });
});

/* ---------- macros ---------- */
const MACROS = [
  { k: "protein_g", name: "Protein", unit: "g", c: "--ember", min: true },
  { k: "calories", name: "Calories", unit: "kcal", c: "--coral" },
  { k: "carbs_g", name: "Carbs", unit: "g", c: "--sky" },
  { k: "fat_g", name: "Fat", unit: "g", c: "--orchid" },
];
const mealsOn = (day) => state.meals.filter((m) => sameDay(m.time, day));
function totals(meals) {
  const t = { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 };
  meals.forEach((m) => MACROS.forEach(({ k }) => (t[k] += Number(m[k]) || 0)));
  return t;
}

function renderMacros() {
  const day = state.day, today = startOfDay(new Date());
  $("#day-title").textContent = sameDay(day, today) ? "Today" : sameDay(day, new Date(today - DAY)) ? "Yesterday" : fmtDate.format(day);
  $("#day-next").disabled = day >= today;
  $("#day-prev").disabled = today - day >= 119 * DAY;
  const meals = mealsOn(day).sort((a, b) => a.time - b.time);
  const t = totals(meals), tg = state.settings.targets;
  $("#macro-bars").innerHTML = MACROS.map((m, i) => {
    const v = round(t[m.k]), target = tg[m.k];
    const pct = target ? Math.min(100, (v / target) * 100) : 0;
    let note = "No target";
    let met = false;
    if (target) {
      if (m.min) { met = v >= target; note = met ? "Target met" : `${round(target - v)} ${m.unit} to go · at least ${target}`; }
      else note = v <= target ? `${round(target - v)} ${m.unit} left` : `${round(v - target)} ${m.unit} over`;
    }
    return `<div class="mb-row ${i === 0 ? "hero" : ""}">
      <div class="mb-top"><span class="mb-name">${m.name}</span><span class="mb-val"><b>${v}</b>${target ? ` / ${target}` : ""} ${m.unit}</span></div>
      <div class="mb-track"><div class="mb-fill" style="width:${pct}%;background:${cssVar(met ? "--ok" : m.c)}"></div></div>
      <div class="mb-note ${met ? "met" : ""}">${note}</div></div>`;
  }).join("");
  $("#meal-list").innerHTML = meals.length
    ? meals.map((m) => `<li><button class="meal" data-id="${m.id}">
        ${m.photo ? `<img class="meal-thumb" src="${esc(m.photo)}" alt="">` : `<span class="meal-thumb">${m.calories != null ? round(m.calories) : "—"}</span>`}
        <span class="meal-main"><div class="meal-desc">${esc(m.description || "Meal")}</div>
        <div class="meal-meta">${fmtTime.format(m.time)} · <span class="p">${round(m.protein_g)}g protein</span> · ${m.calories != null ? round(m.calories) + " kcal" : "— kcal"} · C ${m.carbs_g != null ? round(m.carbs_g) : "—"} · F ${m.fat_g != null ? round(m.fat_g) : "—"}${m.source === "photo" ? " · from photo" : ""}</div></span>
      </button></li>`).join("")
    : `<li class="empty">Nothing logged ${sameDay(day, today) ? "today" : "this day"}. Add a meal, or send a food photo to your bot.</li>`;
}
$("#day-prev").addEventListener("click", () => { state.day = startOfDay(new Date(+state.day - 12 * HOUR)); renderMacros(); });
$("#day-next").addEventListener("click", () => { state.day = startOfDay(new Date(+state.day + DAY + 2 * HOUR)); renderMacros(); });
$("#btn-add-meal").addEventListener("click", () => mealSheet());
$("#meal-list").addEventListener("click", (e) => {
  const b = e.target.closest(".meal");
  if (b) mealSheet(state.meals.find((m) => m.id === b.dataset.id));
});

async function compressPhoto(file) {
  const img = await createImageBitmap(file).catch(() => null);
  if (!img) throw new Error("Couldn't read that photo.");
  const max = 560, s = Math.min(1, max / Math.max(img.width, img.height));
  const c = document.createElement("canvas");
  c.width = Math.round(img.width * s);
  c.height = Math.round(img.height * s);
  c.getContext("2d").drawImage(img, 0, 0, c.width, c.height);
  for (const q of [0.72, 0.6, 0.45, 0.3]) {
    const url = c.toDataURL("image/jpeg", q);
    if (url.length < 300000) return url;
  }
  throw new Error("Photo is too large.");
}

function mealSheet(m) {
  const now = new Date();
  const defTime = sameDay(state.day, now) ? now : new Date(+state.day + 12 * HOUR);
  let photo = m?.photo || null;
  openSheet({
    title: m ? "Edit meal" : "Add meal",
    okText: m ? "Save meal" : "Add meal",
    onDelete: m ? async () => { await F.deleteDoc(F.doc(col("meals"), m.id)); toast("Meal deleted"); } : null,
    body: `
      <label>What did you eat? <input name="description" maxlength="500" required value="${esc(m?.description)}" placeholder="e.g. 3 eggs, avocado, toast"></label>
      <label>Time <input name="time" type="datetime-local" required value="${toInput(m?.time || defTime)}"></label>
      <div class="grid2">
        <label>Protein (g) <input name="protein_g" type="number" inputmode="decimal" min="0" step="any" value="${m?.protein_g ?? ""}"></label>
        <label>Calories <input name="calories" type="number" inputmode="decimal" min="0" step="any" value="${m?.calories ?? ""}"></label>
        <label>Carbs (g) <input name="carbs_g" type="number" inputmode="decimal" min="0" step="any" value="${m?.carbs_g ?? ""}"></label>
        <label>Fat (g) <input name="fat_g" type="number" inputmode="decimal" min="0" step="any" value="${m?.fat_g ?? ""}"></label>
      </div>
      <div class="photo-pick">
        <img id="photo-prev" alt="" ${photo ? `src="${esc(photo)}"` : "hidden"}>
        <label class="btn btn-soft">${photo ? "Change photo" : "Add photo"}<input id="photo-in" type="file" accept="image/*"></label>
        <button type="button" class="btn btn-danger" id="photo-rm" ${photo ? "" : "hidden"}>Remove</button>
      </div>
      <label>Notes <textarea name="notes" placeholder="Optional">${esc(m?.notes)}</textarea></label>`,
    onOpen: () => {
      $("#photo-in").addEventListener("change", async (e) => {
        const file = e.target.files[0];
        if (!file) return;
        try {
          photo = await compressPhoto(file);
          $("#photo-prev").src = photo; $("#photo-prev").hidden = false; $("#photo-rm").hidden = false;
        } catch (err) { $("#sheet-error").textContent = err.message; }
      });
      $("#photo-rm").addEventListener("click", () => { photo = null; $("#photo-prev").hidden = true; $("#photo-rm").hidden = true; });
    },
    onSubmit: async (fd) => {
      const data = {
        description: String(fd.get("description")).trim(),
        time: F.Timestamp.fromDate(fromInput(fd.get("time"))),
        calories: num(fd.get("calories")), protein_g: num(fd.get("protein_g")),
        carbs_g: num(fd.get("carbs_g")), fat_g: num(fd.get("fat_g")),
        notes: fd.get("notes") || "", photo: photo || null,
        updatedAt: F.serverTimestamp(),
      };
      if (!data.description) throw new Error("Describe the meal.");
      if (m) await F.updateDoc(F.doc(col("meals"), m.id), data);
      else await F.addDoc(col("meals"), { ...data, source: photo ? "photo" : "manual", createdAt: F.serverTimestamp() });
      state.day = startOfDay(data.time.toDate());
      toast(m ? "Meal saved" : "Meal added");
    },
  });
}

/* ---------- history ---------- */
function renderHistory() {
  const done = state.fasts.filter((f) => f.end);
  const ds = done.map((f) => f.end - f.start);
  const total = ds.reduce((a, b) => a + b, 0);
  let streak = 0;
  for (const f of done) { if ((f.end - f.start) / HOUR >= (f.targetHours || 0)) streak++; else break; }
  const hits = done.filter((f) => (f.end - f.start) / HOUR >= (f.targetHours || 0)).length;
  const stats = [
    [done.length, "Fasts"],
    [ds.length ? dur(Math.max(...ds)) : "—", "Longest"],
    [ds.length ? dur(total / ds.length) : "—", "Average"],
    [streak, "Goal streak"],
    [`${Math.round(total / HOUR)}h`, "Total fasted"],
    [done.length ? `${Math.round((hits / done.length) * 100)}%` : "—", "Goals hit"],
  ];
  $("#stats").innerHTML = stats.map(([v, l]) => `<div class="stat"><div class="stat-v">${v}</div><div class="stat-l">${l}</div></div>`).join("");
  renderChart();
  $("#fast-list").innerHTML = state.fasts.length
    ? state.fasts.map((f) => {
        const live = !f.end, d = (f.end || Date.now()) - f.start, hit = !live && d / HOUR >= f.targetHours;
        return `<li><button class="fast" data-id="${f.id}">
          <span class="fast-dur">${dur(d)}</span>
          <span class="fast-when">${fmtFull.format(f.start)} → ${live ? "now" : smartTime(f.end)}</span>
          <span class="fast-badge ${live ? "live" : hit ? "hit" : ""}">${live ? "In progress" : hit ? `${f.targetHours}h goal ✓` : `${f.targetHours}h goal`}</span>
        </button></li>`;
      }).join("")
    : `<li class="empty">No fasts yet. Start one from the Timer tab.</li>`;
}
function renderChart() {
  const k = state.chartKey, target = state.settings.targets[k];
  const today = startOfDay(new Date());
  const days = [...Array(14)].map((_, i) => startOfDay(new Date(+today - (13 - i) * DAY + 2 * HOUR)));
  const vals = days.map((d) => totals(mealsOn(d))[k]);
  const max = Math.max(target || 0, ...vals, k === "calories" ? 500 : 50) * 1.1;
  const W = 340, H = 150, top = 8, bottom = 22, ch = H - top - bottom, bw = W / 14;
  const y = (v) => top + ch - (v / max) * ch;
  let svg = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${k === "calories" ? "Calories" : "Protein"} per day, last 14 days">`;
  vals.forEach((v, i) => {
    const h = Math.max(v ? 3 : 2, (v / max) * ch);
    const cls = !v ? "zero" : k === "protein_g" && target && v >= target ? "met" : "";
    svg += `<rect class="bar ${cls}" x="${i * bw + 4}" y="${top + ch - h}" width="${bw - 8}" height="${h}" rx="4"><title>${fmtDate.format(days[i])}: ${round(v)}</title></rect>`;
    svg += `<text class="lbl" x="${i * bw + bw / 2}" y="${H - 6}">${days[i].getDate()}</text>`;
  });
  if (target) svg += `<line class="tline" x1="0" x2="${W}" y1="${y(target)}" y2="${y(target)}"/><text class="tlbl" x="${W - 2}" y="${y(target) - 4}">${target}${k === "calories" ? "" : "g"}</text>`;
  $("#chart").innerHTML = svg + "</svg>";
}
$("#chart-seg").addEventListener("click", (e) => {
  const b = e.target.closest("button");
  if (!b) return;
  state.chartKey = b.dataset.k;
  $$("#chart-seg button").forEach((x) => x.classList.toggle("on", x === b));
  renderChart();
});
$("#fast-list").addEventListener("click", (e) => {
  const b = e.target.closest(".fast");
  if (!b) return;
  const f = state.fasts.find((x) => x.id === b.dataset.id);
  openSheet({
    title: "Edit fast",
    onDelete: async () => { await F.deleteDoc(F.doc(col("fasts"), f.id)); toast("Fast deleted"); },
    body: `
      <label>Started <input name="start" type="datetime-local" required value="${toInput(f.start)}"></label>
      <label>Ended <input name="end" type="datetime-local" value="${f.end ? toInput(f.end) : ""}"></label>
      <p class="fine">Leave "Ended" empty if the fast is still going.</p>
      <label>Goal (hours) <input name="targetHours" type="number" inputmode="decimal" min="1" max="240" step="0.5" required value="${f.targetHours}"></label>
      <label>Notes <textarea name="notes">${esc(f.notes)}</textarea></label>`,
    onSubmit: async (fd) => {
      const s = fromInput(fd.get("start")), en = fromInput(fd.get("end"));
      if (en && en <= s) throw new Error("End time has to be after the start.");
      if (!en && state.fasts.some((x) => !x.end && x.id !== f.id)) throw new Error("Another fast is already in progress. Add an end time.");
      await F.updateDoc(F.doc(col("fasts"), f.id), {
        start: F.Timestamp.fromDate(s), end: en ? F.Timestamp.fromDate(en) : null,
        targetHours: Number(fd.get("targetHours")), notes: fd.get("notes") || "", updatedAt: F.serverTimestamp(),
      });
      toast("Fast saved");
    },
  });
});

/* ---------- settings ---------- */
function fillSettingsForm() {
  const f = $("#settings-form"), t = state.settings.targets;
  if (f.contains(document.activeElement)) return;
  ["calories", "protein_g", "carbs_g", "fat_g"].forEach((k) => (f.elements[k].value = t[k] ?? ""));
  f.elements.defaultFastHours.value = state.settings.defaultFastHours;
}
$("#settings-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const f = e.target;
  const targets = {};
  ["calories", "protein_g", "carbs_g", "fat_g"].forEach((k) => (targets[k] = num(f.elements[k].value)));
  const defaultFastHours = num(f.elements.defaultFastHours.value) || 24;
  F.setDoc(F.doc(col("settings"), "main"), { targets, defaultFastHours, updatedAt: F.serverTimestamp() }, { merge: true });
  state.settings = { targets, defaultFastHours };
  state.selectedHours = null;
  f.querySelector("button").blur();
  $("#settings-msg").textContent = "Settings saved";
  setTimeout(() => ($("#settings-msg").textContent = ""), 2000);
  renderAll();
});

/* ---------- sheet ---------- */
const sheet = $("#sheet");
let sheetCfg = null;
function openSheet(cfg) {
  sheetCfg = cfg;
  $("#sheet-title").textContent = cfg.title;
  $("#sheet-body").innerHTML = cfg.body;
  $("#sheet-body").className = "form";
  $("#sheet-error").textContent = "";
  $("#sheet-ok").textContent = cfg.okText || "Save";
  $("#sheet-delete").hidden = !cfg.onDelete;
  $("#sheet-delete").dataset.confirm = "";
  $("#sheet-delete").textContent = "Delete";
  $("#sheet-ok").disabled = false;
  sheet.showModal();
  cfg.onOpen?.();
}
$("#sheet-cancel").addEventListener("click", () => sheet.close());
sheet.addEventListener("click", (e) => { if (e.target === sheet) sheet.close(); });
$("#sheet-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  if (!sheetCfg) return;
  $("#sheet-ok").disabled = true;
  try {
    // Firestore resolves writes once the server acks; offline we don't want to hang, so cap the wait.
    await Promise.race([sheetCfg.onSubmit(new FormData(e.target)), new Promise((r) => setTimeout(r, 1500))]);
    sheet.close();
  } catch (err) {
    $("#sheet-error").textContent = err.message || String(err);
  } finally {
    $("#sheet-ok").disabled = false;
  }
});
$("#sheet-delete").addEventListener("click", async () => {
  if (!sheetCfg?.onDelete) return;
  if ($("#sheet-delete").dataset.confirm !== "1") {
    $("#sheet-delete").dataset.confirm = "1";
    $("#sheet-delete").textContent = "Tap again to delete";
    setTimeout(() => { $("#sheet-delete").dataset.confirm = ""; $("#sheet-delete").textContent = "Delete"; }, 3000);
    return;
  }
  $("#sheet-delete").dataset.confirm = "";
  $("#sheet-delete").textContent = "Delete";
  sheetCfg.onDelete().catch((err) => toast(err.message));
  sheet.close();
});

/* ---------- tick + PWA ---------- */
setInterval(() => { if (state.user && state.tab === "timer" && !document.hidden) renderTimer(); }, 1000);
document.addEventListener("visibilitychange", () => { if (!document.hidden) { renderAll(); } });
addEventListener("online", renderAll);
addEventListener("offline", renderAll);
matchMedia("(prefers-color-scheme: light)").addEventListener("change", () => { lastTicksKey = ""; renderAll(); });
if ("serviceWorker" in navigator && !isLocal) navigator.serviceWorker.register("/sw.js").catch(() => {});
