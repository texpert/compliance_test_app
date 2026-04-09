#!/usr/bin/env bash
set -euo pipefail

cd "/Users/Shared/dev/Salt Edge/compliance_test_app"
set -a
source ./.env
set +a

CERT_PATH="${SE_QSEAL_CERT_PATH}"
KEY_PATH="${SE_QSEAL_KEY_PATH}"
URL="${SE_API_BASE_URL:-https://priora.saltedge.com}/api/berlingroup/v1/tpp/register"
ENDPOINT="/api/berlingroup/v1/tpp/register"

REQUEST_ID="$(tr 'A-Z' 'a-z' <<< "$(uuidgen)")"
DATE_HDR="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S GMT')"
CERT_BODY_B64="$(awk 'BEGIN{p=0} /BEGIN CERTIFICATE/{p=1;next} /END CERTIFICATE/{p=0} p{printf "%s",$0}' "$CERT_PATH")"

openssl x509 -in "$CERT_PATH" -outform der -out /tmp/tpp_register_cert.der
CERT_DER_B64="$(base64 -b 0 -i /tmp/tpp_register_cert.der)"
FPR_LINE="$(openssl x509 -in "$CERT_PATH" -noout -fingerprint -sha256)"
CERT_FPR_KEYID="${FPR_LINE#*=}"
CERT_FPR_KEYID="${CERT_FPR_KEYID//:/}"
CERT_FPR_KEYID="$(tr 'A-Z' 'a-z' <<< "$CERT_FPR_KEYID")"

PAYLOAD="$(jq -n \
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
  --arg cert_value "$CERT_BODY_B64" \
  '{data:{company:{city:$city,address:$address,email:$email,name:$name,phone_number:$phone,zip_code:$zip},representative:{email:$rep_email,name:$rep_name},certificate:{name:$cert_name,type:$cert_type,value:$cert_value}}}')"

printf "%s" "$PAYLOAD" > /tmp/tpp_register_payload.json
openssl dgst -binary -sha256 -out /tmp/tpp_register_digest.bin /tmp/tpp_register_payload.json
DIGEST_VALUE="SHA-256=$(base64 -b 0 -i /tmp/tpp_register_digest.bin)"

printf "(request-target): post %s\ndate: %s\nx-request-id: %s\ndigest: %s" "$ENDPOINT" "$DATE_HDR" "$REQUEST_ID" "$DIGEST_VALUE" > /tmp/tpp_register_signing_string.txt
openssl dgst -sha256 -sign "$KEY_PATH" -out /tmp/tpp_register_signature.bin /tmp/tpp_register_signing_string.txt
SIGNATURE_B64="$(base64 -b 0 -i /tmp/tpp_register_signature.bin)"
SIGNATURE_HDR="keyId=\"${CERT_FPR_KEYID}\",algorithm=\"rsa-sha256\",headers=\"(request-target) date x-request-id digest\",signature=\"${SIGNATURE_B64}\""

HTTP_CODE="$(curl -sS -o /tmp/tpp_register_response.json -w "%{http_code}" \
  -X POST "$URL" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Date: ${DATE_HDR}" \
  -H "X-Request-ID: ${REQUEST_ID}" \
  -H "Digest: ${DIGEST_VALUE}" \
  -H "Signature: ${SIGNATURE_HDR}" \
  -H "TPP-Signature-Certificate: ${CERT_DER_B64}" \
  -d @/tmp/tpp_register_payload.json)"

echo "HTTP_STATUS:${HTTP_CODE}"
cat /tmp/tpp_register_response.json
