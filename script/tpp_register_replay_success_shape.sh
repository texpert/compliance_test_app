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

REQUEST_ID="$(tr 'A-Z' 'a-z' <<< "$(uuidgen)")"
DATE_HDR="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S GMT')"

BODY="$(jq -n \
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
openssl dgst -sha256 -binary -out /tmp/tpp_register_replay_digest.bin /tmp/tpp_register_replay_payload.json
DIGEST_HDR="SHA-256=$(base64 -b 0 -i /tmp/tpp_register_replay_digest.bin)"

CERT_B64="$(base64 -b 0 -i "$CERT_PATH")"
KEY_ID="SN=0,DN=/organizationIdentifier=$SE_QSEAL_SUBJECT_ORGANIZATION_IDENTIFIER/CN=$SE_QSEAL_SUBJECT_CN/O=$SE_QSEAL_SUBJECT_O/C=$SE_QSEAL_SUBJECT_C/ST=$SE_QSEAL_SUBJECT_ST"

printf 'digest: %s\ndate: %s\nx-request-id: %s' "$DIGEST_HDR" "$DATE_HDR" "$REQUEST_ID" > /tmp/tpp_register_replay_signing_string.txt
openssl dgst -sha256 -sign "$KEY_PATH" -out /tmp/tpp_register_replay_signature.bin /tmp/tpp_register_replay_signing_string.txt
SIGNATURE_B64="$(base64 -b 0 -i /tmp/tpp_register_replay_signature.bin)"
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
  -d @/tmp/tpp_register_replay_payload.json)"

echo "HTTP_STATUS:${HTTP_CODE}"
cat /tmp/tpp_register_replay_response.json
