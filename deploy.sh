#!/usr/bin/env bash
# One-shot setup + deploy of the Fast app to a Firebase project.
# Usage: ./deploy.sh <project-id> [owner-email] [extra-site-ids,comma-separated]
#   First run on a fresh project: creates the web app, Firestore (standard, nam5),
#   Google sign-in, rules, and hosting. Re-running just redeploys.
set -euo pipefail
cd "$(dirname "$0")"
P="${1:?usage: ./deploy.sh <project-id> [owner-email]}"
EMAIL="${2:-tenebrsx@gmail.com}"
EXTRA_SITES="${3:-}"   # comma-separated extra Hosting site ids (must already exist)
FB="npx -y firebase-tools@latest"

printf '{ "projects": { "default": "%s" } }\n' "$P" > .firebaserc

# Hosting sites (default + optional extras) and Google sign-in provider config.
node -e '
const fs=require("fs"); const [p,e,extra]=process.argv.slice(1);
const j=JSON.parse(fs.readFileSync("firebase.json","utf8"));
const base=Array.isArray(j.hosting)?j.hosting[0]:j.hosting; delete base.site;
const sites=[p,...(extra||"").split(",").filter(Boolean)];
j.hosting=sites.map(s=>({site:s,...base}));
const uris=sites.flatMap(s=>[`https://${s}.web.app/__/auth/handler`,`https://${s}.firebaseapp.com/__/auth/handler`]);
j.auth={providers:{googleSignIn:{oAuthBrandDisplayName:"Fasting Tracker",supportEmail:e,authorizedRedirectUris:uris}}};
fs.writeFileSync("firebase.json",JSON.stringify(j,null,2)+"\n");' "$P" "$EMAIL" "$EXTRA_SITES"

# Web app (needed for the auto-served /__/firebase/init.json config).
if ! $FB apps:list WEB --project "$P" 2>/dev/null | grep -q "WEB"; then
  $FB apps:create WEB "Fast web" --project "$P"
fi

# Firestore (default) database, standard edition (works on the free Spark plan).
if ! $FB firestore:databases:list --project "$P" 2>/dev/null | grep -q "databases/(default)"; then
  $FB firestore:databases:create "(default)" --location nam5 --edition standard --project "$P"
fi

$FB deploy --only auth,firestore,hosting --project "$P" --non-interactive

# Point the bot CLI at this project.
node -e 'const fs=require("fs");const f="tools/config.json";const c=JSON.parse(fs.readFileSync(f));c.projectId=process.argv[1];c.email=process.argv[2];fs.writeFileSync(f,JSON.stringify(c,null,2)+"\n")' "$P" "$EMAIL"
echo "Live at https://$P.web.app"
