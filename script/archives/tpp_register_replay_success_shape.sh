#!/usr/bin/env bash
set -euo pipefail

cd "/Users/Shared/dev/Salt Edge/compliance_test_app"

ENV_CERT_PATH_OVERRIDE="${SE_QSEAL_CERT_PATH-}"
ENV_KEY_PATH_OVERRIDE="${SE_QSEAL_KEY_PATH-}"

set -a
source ./.env
set +a

if [ -n "${ENV_CERT_PATH_OVERRIDE}" ]; then
  SE_QSEAL_CERT_PATH="${ENV_CERT_PATH_OVERRIDE}"
fi

if [ -n "${ENV_KEY_PATH_OVERRIDE}" ]; then
  SE_QSEAL_KEY_PATH="${ENV_KEY_PATH_OVERRIDE}"
fi

CERT_PATH="${SE_QSEAL_CERT_PATH}"
KEY_PATH="${SE_QSEAL_KEY_PATH}"
URL="${SE_API_BASE_URL:-https://priora.saltedge.com}/api/berlingroup/v1/tpp/register"

b64_encode_file() {
  if [ "${SE_USE_OPENSSL_BASE64:-0}" = "1" ]; then
    # Optional compatibility mode for diagnostics; default remains BSD base64.
    openssl base64 -A -in "$1"
  else
    base64 -b 0 -i "$1"
  fi
}

CERT_ATTEMPT_DIR="$(basename "$(dirname "$CERT_PATH")")"
KEY_ATTEMPT_DIR="$(basename "$(dirname "$KEY_PATH")")"
CERT_FINGERPRINT="$(openssl x509 -in "$CERT_PATH" -noout -fingerprint -sha256 | sed 's/^.*=//')"

echo "Using certificate attempt folder: ${CERT_ATTEMPT_DIR}" >&2
echo "Using key attempt folder: ${KEY_ATTEMPT_DIR}" >&2
echo "Certificate fingerprint (SHA-256): ${CERT_FINGERPRINT}" >&2

REQUEST_ID="$(tr 'A-Z' 'a-z' <<< "$(uuidgen)")"
DATE_HDR="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S GMT')"

BODY="$(jq -c -n \
  --arg city "$SE_TPP_COMPANY_CITY" \
  --arg address "$SE_TPP_COMPANY_ADDRESS" \
  --arg email "$SE_TPP_COMPANY_EMAIL" \
  --arg name "$SE_TPP_COMPANY_NAME" \
  --arg phone "$SE_TPP_COMPANY_PHONE_NUMBER" \
  --arg zip "$SE_TPP_COMPANY_ZIP_CODE" \
  --arg rep_email "$SE_TPP_REPRESENTATIVE_EMAIL" \
  --arg rep_name "$SE_TPP_REPRESENTATIVE_NAME" \
  --arg cert_name "$SE_TPP_CERTIFICATE_NAME" \
  --arg cert_type "${SE_TPP_CERTIFICATE_TYPE:-qseal}" \
  '{company:{city:$city,address:$address,email:$email,name:$name,phone_number:$phone,zip_code:$zip},representative:{email:$rep_email,name:$rep_name},certificate:{name:$cert_name,type:$cert_type}}')"

printf '%s' "$BODY" > /tmp/tpp_register_replay_payload.json
rm -f /tmp/tpp_register_replay_digest.bin
openssl dgst -sha256 -binary -out /tmp/tpp_register_replay_digest.bin /tmp/tpp_register_replay_payload.json
DIGEST_HDR="SHA-256=$(b64_encode_file /tmp/tpp_register_replay_digest.bin)"

echo "Digest artifact mtime: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" /tmp/tpp_register_replay_digest.bin)" >&2
echo "Digest header used: ${DIGEST_HDR}" >&2

CERT_B64="$(b64_encode_file "$CERT_PATH")"

# Build DN-style keyId from the certificate subject itself to avoid .env/cert mismatches.
SUBJECT_RFC2253="$(openssl x509 -in "$CERT_PATH" -noout -subject -nameopt RFC2253 | sed 's/^subject=//')"
extract_subject_attr() {
  printf '%s' "$SUBJECT_RFC2253" | awk -F',' -v key="$1" '
    {
      for (i = 1; i <= NF; i++) {
        gsub(/^ +| +$/, "", $i)
        n = split($i, kv, "=")
        k = kv[1]
        v = $i
        sub(/^[^=]*=/, "", v)
        if (k == key) {
          print v
          exit
        }
      }
    }
  '
}

ORG_ID="$(extract_subject_attr "organizationIdentifier")"
if [ -z "$ORG_ID" ]; then
  ORG_ID="$(extract_subject_attr "2.5.4.97")"
fi

CN="$(extract_subject_attr "CN")"
O="$(extract_subject_attr "O")"
C="$(extract_subject_attr "C")"
ST="$(extract_subject_attr "ST")"

KEY_ID="SN=0,DN=/organizationIdentifier=${ORG_ID}/CN=${CN}/O=${O}/C=${C}/ST=${ST}"

printf 'digest: %s\ndate: %s\nx-request-id: %s' "$DIGEST_HDR" "$DATE_HDR" "$REQUEST_ID" > /tmp/tpp_register_replay_signing_string.txt
openssl dgst -sha256 -sign "$KEY_PATH" -out /tmp/tpp_register_replay_signature.bin /tmp/tpp_register_replay_signing_string.txt
SIGNATURE_B64="$(b64_encode_file /tmp/tpp_register_replay_signature.bin)"
SIGNATURE_HDR="keyId=\"${KEY_ID}\",algorithm=\"rsa-sha256\",headers=\"digest date x-request-id\",signature=\"${SIGNATURE_B64}\""

HTTP_CODE="$(curl --trace-time --trace-ascii /tmp/tpp_register_replay_trace.txt -sS \
  -o /tmp/tpp_register_replay_response.json \
  -w '%{http_code}' \
  -X POST "$URL" \
  -H "X-Request-ID: ${REQUEST_ID}" \
  -H "Digest: ${DIGEST_HDR}" \
  -H "Date: ${DATE_HDR}" \
  -H "TPP-Signature-Certificate: ${CERT_B64}" \
  -H "Signature: ${SIGNATURE_HDR}" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/tpp_register_replay_payload.json)"

echo "HTTP_STATUS:${HTTP_CODE}"
cat /tmp/tpp_register_replay_response.json
