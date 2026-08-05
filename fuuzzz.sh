#!/usr/bin/env bash
# fuzz_apigw.sh - wide fuzzing of API Gateway resource paths with ffuf,
# using SecLists wordlists. Filters out the known noise responses.
#
# Usage: /bin/bash fuzz_apigw.sh

BASE="https://3q931syi7b.execute-api.us-east-1.amazonaws.com/dev"
PAYLOAD='{"domain":"example.com"}'

# Common SecLists locations on Kali
WORDLIST_CANDIDATES=(
  "/usr/share/seclists/Discovery/Web-Content/api/objects.txt"
  "/usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt"
  "/usr/share/seclists/Discovery/Web-Content/raft-small-words.txt"
  "/usr/share/seclists/Discovery/Web-Content/raft-small-directories.txt"
  "/usr/share/wordlists/seclists/Discovery/Web-Content/raft-small-words.txt"
)

WORDLIST=""
for w in "${WORDLIST_CANDIDATES[@]}"; do
  if [[ -f "$w" ]]; then
    WORDLIST="$w"
    break
  fi
done

if [[ -z "$WORDLIST" ]]; then
  echo "No SecLists wordlist found in common locations."
  echo "Install with: sudo apt install seclists"
  echo "Or clone manually: git clone https://github.com/danielmiessler/SecLists.git ~/SecLists"
  echo "Then re-run pointing WORDLIST at, e.g.:"
  echo "  ~/SecLists/Discovery/Web-Content/raft-small-words.txt"
  exit 1
fi

echo "Using wordlist: $WORDLIST"
echo "Target: $BASE/FUZZ"
echo ""

# -X POST                    : method
# -H Content-Type             : json
# -d "$PAYLOAD"                : body
# -w "$WORDLIST"               : wordlist -> FUZZ keyword
# -u "$BASE/FUZZ"               : target url pattern
# -mc all                      : match all status codes initially, we'll filter after
# -fr "wip|Missing Authentication Token|message.:.Forbidden"  : filter by regex on response body (skip known noise)
# -t 40                        : 40 threads, reasonable for API Gateway without tripping throttling too hard
# -p 0.05                      : small delay between requests per thread to reduce risk of rate-limiting/WAF block

ffuf -w "$WORDLIST" \
  -u "$BASE/FUZZ" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  -mc all \
  -fr 'wip|Missing Authentication Token|"message":\s*"Forbidden"|Could not parse request body' \
  -t 40 \
  -p 0.05 \
  -o ffuf_results.json -of json

echo ""
echo "Done. Full results saved to ffuf_results.json"
echo "Any surviving hits (not filtered) are printed above."
