# Fasting & macro tracker

Source of truth for tenebris’s extended fasts and daily macros.

Timezone for all start, end, and meal times: **America/Santo_Domingo (UTC−4, Atlantic time)**.

## Files

- `/workspace/fasting/data.json` — official log (the bot updates this first)
- `/workspace/fasting/README.md` — this file

## Page

- **Name:** Fasting
- **Canvas id:** `e496d9ae-b8cf-48ef-a8ca-ce59523c1a6f`
- **Link:** https://cursor.com/canvas/store-663286e4-a17c-458f-9a47-844f07cab8ce/e496d9ae-b8cf-48ef-a8ca-ce59523c1a6f
- **Kit:** `grok/canvas` (Grok Bot Page via WriteCanvas / EditCanvas)
- **Title:** Fasting
- **Width:** `column` (mobile-first, Zero-style)

## How to update the Page from data.json

1. Edit `/workspace/fasting/data.json` only with real events (start/stop a fast, estimated meal macros, target changes). Do **not** invent sample fasts or meals.
2. Keep the JSON shape:

```json
{
  "settings": {
    "dailyTargets": {
      "calories": null,
      "protein_g": 120,
      "carbs_g": null,
      "fat_g": null
    },
    "defaultFastHours": 24
  },
  "fasts": [
    {
      "id": "fast-...",
      "start": "2026-11-12T15:00:00-04:00",
      "end": null,
      "targetHours": 24,
      "notes": ""
    }
  ],
  "meals": [
    {
      "id": "meal-...",
      "time": "2026-11-12T19:30:00-04:00",
      "description": "…",
      "calories": 0,
      "protein_g": 0,
      "carbs_g": 0,
      "fat_g": 0,
      "source": "photo",
      "notes": ""
    }
  ]
}
```

3. Rewrite the Page in place (do not create a second canvas). Use **EditCanvas** for a small patch, or **WriteCanvas** with `canvas_id: e496d9ae-b8cf-48ef-a8ca-ce59523c1a6f` for a full rewrite.
4. The live Page embeds a copy of the JSON as the `DATA` constant at the top of the `.canvas.tsx` source. Replace that object so it matches `data.json` exactly. Leave the rest of the file alone unless the layout also needs to change.
5. ISO timestamps must include the `-04:00` offset (Santo Domingo has no DST).

### Sections to refresh after a data change

| Section id | Heading | What to refresh |
|---|---|---|
| `current-fast` | (hero, no heading) | Zero-style ring, live elapsed time, start/goal, zone labels. Driven by the active fast (`end: null`) in `DATA.fasts`. |
| `fast-history` | Fast history | Metrics (total, longest, average, current streak) and the history table. |
| `todays-macros` | Today’s macros | Totals vs daily targets, protein treated as a **120g+ minimum**, pie + meal list for the Santo Domingo calendar day. |
| `macro-history` | Macro history | Last 14 days stacked P/C/F chart, calories line, daily table. |
| `log-controls` | Log in this page | In-page start/stop, manual meal form, target inputs. Usually unchanged when only `DATA` changes. |

Empty states (do not invent rows to fill them):

- No fasts: “No fasts logged yet — tell Fasting bot ‘starting my fast’”
- No meals: “No meals logged yet — send Fasting bot a photo of your food…”

### Targets

- `settings.dailyTargets.protein_g` is **120** and is a **minimum**, shown as **120g+**.
- `calories`, `carbs_g`, and `fat_g` stay `null` until tenebris sets them. The Page then shows a “set a target” hint.

## Bot workflow

When tenebris says he is starting or breaking a fast, or sends a food photo:

1. Update `/workspace/fasting/data.json`.
2. Copy the new JSON into the Page’s `DATA` constant and save the same canvas (`e496d9ae-b8cf-48ef-a8ca-ce59523c1a6f`).
3. Official log entries are the only permanent record.

## In-page controls vs official log

The Page has start/stop, meal, and target controls that use `useState`. They change **only the current page view**. They are not written to `data.json`. Tell the user to message Fasting bot to make a change permanent. Those local entries may disappear after a refresh or after the bot rewrites the Page.
