#!/usr/bin/env bash
# subdomain-search.sh - Find + optionally check subdomains via crt.name
# Also extract clean subdomain prefixes for wordlists

set -euo pipefail

API="https://crt.name/v1/search"
DOMAIN=""
DATES=0
JSON=0
CHECK=0
HTTPS_ONLY=0
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
OUTPUT_FILE=""
WORDLIST_FILE=""
TIMEOUT=5
MAX_PARALLEL=10

usage() {
  cat <<EOF
Usage: $(basename "$0") <domain> [options]

Options:
  --dates, -d              Include first-seen dates from crt.name
  --json,  -j              Return JSON from crt.name (ignored when --check is used)
  --check, -c              Check if each subdomain actually responds
  --https-only             Only try HTTPS (skip HTTP)
  --ua <string>            Custom User-Agent for the checker (default: Chrome)
  -o, --output <file>      Save full results (or live check results) to a file
  -w, --wordlist <file>    Extract subdomain prefixes and save unique ones to this file
  --timeout <sec>          Connection timeout in seconds (default: 5)
  -h, --help               Show this help

Wordlist examples:
  api.x.com           → api
  staging.api.x.com   → staging.api
  new.domain.x.com    → new.domain

Examples:
  $(basename "$0") x.com -w words.txt
  $(basename "$0") x.com --check -o live.txt -w words.txt
  $(basename "$0") microsoft.com --check --https-only -w ms-words.txt
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)          usage ;;
    --dates|-d)         DATES=1; shift ;;
    --json|-j)          JSON=1; shift ;;
    --check|-c)         CHECK=1; shift ;;
    --https-only)       HTTPS_ONLY=1; shift ;;
    --ua)               USER_AGENT="$2"; shift 2 ;;
    -o|--output)        OUTPUT_FILE="$2"; shift 2 ;;
    -w|--wordlist)      WORDLIST_FILE="$2"; shift 2 ;;
    --timeout)          TIMEOUT="$2"; shift 2 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage
      fi
      shift
      ;;
  esac
done

[[ -z "$DOMAIN" ]] && usage

########################################
# 1. Fetch subdomains from crt.name
########################################
QUERY="apex=${DOMAIN}"
[[ $DATES -eq 1 ]] && QUERY+="&dates=1"
[[ $JSON -eq 1 && $CHECK -eq 0 ]] && QUERY+="&format=json"

echo "[*] Querying crt.name for $DOMAIN ..." >&2
RAW=\( (curl -sS --fail --max-time 30 " \){API}?${QUERY}" || true)

if [[ -z "$RAW" ]]; then
  echo "[!] No subdomains returned" >&2
  exit 1
fi

# Always work with a clean list of hostnames (strip dates if present)
CLEAN_LIST=$(echo "$RAW" | awk '{print $1}' | sort -u)

########################################
# 2. Wordlist extraction (if requested)
########################################
if [[ -n "$WORDLIST_FILE" ]]; then
  echo "[*] Building wordlist of subdomain prefixes ..." >&2

  # Remove the apex domain and the leading/trailing dots
  # e.g. staging.api.x.com → staging.api
  #      api.x.com         → api
  WORDLIST=$(echo "\( CLEAN_LIST" | sed -E "s/\.? \){DOMAIN//./\.}\( //" | sed '/^ \)/d' | sort -u)

  echo "$WORDLIST" > "$WORDLIST_FILE"
  COUNT=$(echo "$WORDLIST" | wc -l)
  echo "[+] Saved $COUNT unique prefixes to $WORDLIST_FILE" >&2
fi

########################################
# 3. If not checking → just output the list and exit
########################################
if [[ $CHECK -eq 0 ]]; then
  if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$CLEAN_LIST" > "$OUTPUT_FILE"
    echo "[+] Saved full subdomain list to $OUTPUT_FILE" >&2
  else
    echo "$CLEAN_LIST"
  fi
  exit 0
fi

########################################
# 4. Checker function
########################################
check_host() {
  local host="$1"
  local schemes=("https" "http")
  [[ $HTTPS_ONLY -eq 1 ]] && schemes=("https")

  for scheme in "${schemes[@]}"; do
    local code
    code=$(curl -sS -o /dev/null -w "%{http_code}" \
      --connect-timeout "$TIMEOUT" \
      --max-time $((TIMEOUT + 3)) \
      -A "$USER_AGENT" \
      -L -k \
      "\( {scheme}:// \){host}" 2>/dev/null || echo "000")

    if [[ "$code" != "000" ]]; then
      echo "[LIVE] \( {scheme}:// \){host}  →  HTTP $code"
      return 0
    fi
  done

  echo "[DEAD] $host"
  return 1
}

export -f check_host
export USER_AGENT TIMEOUT HTTPS_ONLY

########################################
# 5. Run the checks
########################################
echo "[*] Checking subdomains (timeout=${TIMEOUT}s, UA=\"$USER_AGENT\") ..." >&2
echo

RESULTS=""
if command -v parallel >/dev/null 2>&1; then
  RESULTS=$(echo "$CLEAN_LIST" | parallel -j "$MAX_PARALLEL" check_host)
else
  RESULTS=$(echo "$CLEAN_LIST" | xargs -P "\( MAX_PARALLEL" -I {} bash -c 'check_host " \)@"' _ {})
fi

########################################
# 6. Output results
########################################
if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$RESULTS" > "$OUTPUT_FILE"
  echo
  echo "[+] Full check results saved to: $OUTPUT_FILE" >&2
  echo "[+] Live hosts:" >&2
  echo "$RESULTS" | grep "\[LIVE\]" || true
else
  echo "$RESULTS"
fi
