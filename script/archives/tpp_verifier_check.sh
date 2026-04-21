#!/usr/bin/env bash
set -euo pipefail

cd "/Users/Shared/dev/Salt Edge/compliance_test_app"
set -a
source ./.env
set +a

CERT_PATH="${SE_QSEAL_CERT_PATH}"
APP_ID="${SE_APP_ID}"
APP_SECRET="${SE_APP_SECRET}"
URL="${SE_API_BASE_URL:-https://priora.saltedge.com}/api/tpp_verifiers/v2/certificates"

if [ ! -f "$CERT_PATH" ]; then
  echo "ERROR: certificate file not found at $CERT_PATH"
  exit 1
fi

CERT_PEM="$(cat "$CERT_PATH")"
PAYLOAD="$(jq -Rn --arg cert "$CERT_PEM" '{data:{certificate:$cert}}')"

HTTP_CODE="$(curl -sS -o /tmp/tpp_verifier_response.json -w "%{http_code}" \
  -X POST "$URL" \
  -H "App-Id: $APP_ID" \
  -H "App-Secret: $APP_SECRET" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")"

echo "HTTP_STATUS:${HTTP_CODE}"
cat /tmp/tpp_verifier_response.json
