#!/usr/bin/env bash
# check_site.sh - pull every discoverable file from the CloudFront-hosted site
# and grep them for API endpoints, comments, alternate stages, etc.
#
# Usage: /bin/bash check_site.sh

CURL=/usr/bin/curl
SITE="https://d67nf28gqfurd.cloudfront.net"
WORKDIR="./site_dump"

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

echo "===== Fetching known files ====="
KNOWN_FILES=(
  "index.html"
  "css/styles.css"
  "js/scripts.js"
  "images/favicon.ico"
)

for f in "${KNOWN_FILES[@]}"; do
  echo "----- $f -----"
  mkdir -p "$(dirname "$f")"
  $CURL -s -o "$f" "$SITE/$f"
  file "$f" 2>/dev/null
done

echo ""
echo "===== Guessing additional common JS/config filenames ====="
GUESS_FILES=(
  "js/main.js" "js/app.js" "js/config.js" "js/index.js" "js/api.js"
  "js/scripts.js.map" "config.js" "config.json" "env.js" ".env"
  "js/scripts.min.js" "js/bundle.js" "manifest.json" "robots.txt"
  "sitemap.xml" "css/main.css"
)

for f in "${GUESS_FILES[@]}"; do
  code=$($CURL -s -o /tmp/_probe_body -w "%{http_code}" "$SITE/$f")
  if [[ "$code" == "200" ]]; then
    echo "----- FOUND: $f (HTTP $code) -----"
    mkdir -p "$(dirname "$f")" 2>/dev/null
    cp /tmp/_probe_body "$f"
  fi
done

echo ""
echo "===== Directory listing attempt (in case CloudFront/S3 allows it) ====="
$CURL -s "$SITE/" | head -50
$CURL -s "$SITE/js/" | head -50
$CURL -s "$SITE/css/" | head -50
$CURL -s "$SITE/images/" | head -50

echo ""
echo "===== Grepping all downloaded files for endpoints / comments / secrets ====="
grep -r -i -E "execute-api|api-gateway|apigateway|stage|http[s]?://|TODO|FIXME|password|secret|key|token|domain" . \
  2>/dev/null

echo ""
echo "===== Full contents of scripts.js (for manual review) ====="
cat js/scripts.js 2>/dev/null

echo ""
echo "===== Done. Dump saved in: $(pwd) ====="
