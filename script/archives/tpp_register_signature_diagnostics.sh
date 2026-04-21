#!/usr/bin/env bash
set -euo pipefail

cd "/Users/Shared/dev/Salt Edge/compliance_test_app"

ENV_CERT_PATH_OVERRIDE="${SE_QSEAL_CERT_PATH-}"
ENV_KEY_PATH_OVERRIDE="${SE_QSEAL_KEY_PATH-}"
ENV_PUBLIC_KEY_PATH_OVERRIDE="${SE_QSEAL_PUBLIC_KEY_PATH-}"

set -a
source ./.env
set +a

if [ -n "${ENV_CERT_PATH_OVERRIDE}" ]; then
  SE_QSEAL_CERT_PATH="${ENV_CERT_PATH_OVERRIDE}"
fi

if [ -n "${ENV_KEY_PATH_OVERRIDE}" ]; then
  SE_QSEAL_KEY_PATH="${ENV_KEY_PATH_OVERRIDE}"
fi

if [ -n "${ENV_PUBLIC_KEY_PATH_OVERRIDE}" ]; then
  SE_QSEAL_PUBLIC_KEY_PATH="${ENV_PUBLIC_KEY_PATH_OVERRIDE}"
fi

CERT_PATH="${SE_QSEAL_CERT_PATH}"
KEY_PATH="${SE_QSEAL_KEY_PATH}"
URL="${SE_API_BASE_URL:-https://priora.saltedge.com}/api/berlingroup/v1/tpp/register"
ENDPOINT="/api/berlingroup/v1/tpp/register"

REQUEST_ID="$(tr 'A-Z' 'a-z' <<< "$(uuidgen)")"
DATE_HDR="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S GMT')"
CERT_BODY_B64="$(awk 'BEGIN{p=0} /BEGIN CERTIFICATE/{p=1;next} /END CERTIFICATE/{p=0} p{printf "%s",$0}' "$CERT_PATH")"
CERT_PEM_B64="$(base64 -b 0 -i "$CERT_PATH")"
SUBJECT_COMPAT="$(openssl x509 -in "$CERT_PATH" -noout -subject -nameopt compat)"
DOCS_KEYID="SN=0,DN=${SUBJECT_COMPAT#subject=}"
EMPTY_DIGEST_VALUE="SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="

openssl x509 -in "$CERT_PATH" -outform der -out /tmp/tpp_register_cert.der
CERT_DER_B64="$(base64 -b 0 -i /tmp/tpp_register_cert.der)"
FPR_LINE="$(openssl x509 -in "$CERT_PATH" -noout -fingerprint -sha256)"
KEYID_HEX="${FPR_LINE#*=}"
KEYID_HEX="${KEYID_HEX//:/}"
KEYID_HEX="$(tr 'A-Z' 'a-z' <<< "$KEYID_HEX")"

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

DOCS_PAYLOAD="$(jq -n \
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

printf "%s" "$DOCS_PAYLOAD" > /tmp/tpp_register_docs_payload.json
openssl dgst -binary -sha256 -out /tmp/tpp_register_docs_digest.bin /tmp/tpp_register_docs_payload.json
DOCS_DIGEST_VALUE="SHA-256=$(base64 -b 0 -i /tmp/tpp_register_docs_digest.bin)"

run_variant() {
  local name="$1"
  local keyid="$2"
  local signed_headers="$3"
  local signing_lines="$4"
  local payload_path="$5"
  local digest_value="$6"
  local cert_header_value="$7"
  local signature_prefix="${8:-}"

  printf '%b' "$signing_lines" > /tmp/tpp_register_signing_string.txt
  openssl dgst -sha256 -sign "$KEY_PATH" -out /tmp/tpp_register_signature.bin /tmp/tpp_register_signing_string.txt
  local signature_b64
  signature_b64="$(base64 -b 0 -i /tmp/tpp_register_signature.bin)"

  local signature_hdr
  signature_hdr="keyId=\"${keyid}\",algorithm=\"rsa-sha256\",headers=\"${signed_headers}\",signature=\"${signature_b64}\""
  if [ -n "$signature_prefix" ]; then
    signature_hdr="${signature_prefix}${signature_hdr}"
  fi

  local http_code
  http_code="$(curl -sS -o /tmp/tpp_register_response_${name}.json -w "%{http_code}" \
    -X POST "$URL" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Date: ${DATE_HDR}" \
    -H "X-Request-ID: ${REQUEST_ID}" \
    -H "Digest: ${digest_value}" \
    -H "Signature: ${signature_hdr}" \
    -H "TPP-Signature-Certificate: ${cert_header_value}" \
    -d @"${payload_path}")"

  local msg
  msg="$(jq -r '.tppMessages[0].text // "(no text)"' /tmp/tpp_register_response_${name}.json 2>/dev/null || cat /tmp/tpp_register_response_${name}.json)"

  echo "variant=${name} status=${http_code} msg=${msg}"
}

echo "Diagnostics (redacted):"
echo "- keyId(hex) length: ${#KEYID_HEX}"
echo "- keyId(docs DN) length: ${#DOCS_KEYID}"
echo "- digest length: ${#DIGEST_VALUE}"
echo "- cert der b64 length: ${#CERT_DER_B64}"
echo "- cert pem b64 length: ${#CERT_PEM_B64}"
echo "- payload bytes: $(wc -c < /tmp/tpp_register_payload.json | tr -d ' ')"
echo "- docs payload bytes: $(wc -c < /tmp/tpp_register_docs_payload.json | tr -d ' ')"

base_signing="(request-target): post ${ENDPOINT}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}\ndigest: ${DIGEST_VALUE}"
with_cert_signing="(request-target): post ${ENDPOINT}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}\ndigest: ${DIGEST_VALUE}\ntpp-signature-certificate: ${CERT_DER_B64}"
docs_signing="digest: ${DOCS_DIGEST_VALUE}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}"
docs_empty_digest_signing="digest: ${EMPTY_DIGEST_VALUE}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}"
docs_request_target_signing="(request-target): post ${ENDPOINT}\ndigest: ${DOCS_DIGEST_VALUE}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}"
docs_payload_default_signing="(request-target): post ${ENDPOINT}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}\ndigest: ${DOCS_DIGEST_VALUE}"
original_payload_docs_style_signing="digest: ${DIGEST_VALUE}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}"
original_payload_pem_cert_only="(request-target): post ${ENDPOINT}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}\ndigest: ${DIGEST_VALUE}"
original_payload_dn_keyid_only="(request-target): post ${ENDPOINT}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}\ndigest: ${DIGEST_VALUE}"
original_payload_sig_prefix_only="(request-target): post ${ENDPOINT}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}\ndigest: ${DIGEST_VALUE}"
original_payload_docs_headers_only="digest: ${DIGEST_VALUE}\ndate: ${DATE_HDR}\nx-request-id: ${REQUEST_ID}"

run_variant "hex_keyid_no_cert_header" "$KEYID_HEX" "(request-target) date x-request-id digest" "$base_signing" /tmp/tpp_register_payload.json "$DIGEST_VALUE" "$CERT_DER_B64"
run_variant "colon_keyid_no_cert_header" "${FPR_LINE#*=}" "(request-target) date x-request-id digest" "$base_signing" /tmp/tpp_register_payload.json "$DIGEST_VALUE" "$CERT_DER_B64"
run_variant "hex_keyid_with_cert_header" "$KEYID_HEX" "(request-target) date x-request-id digest tpp-signature-certificate" "$with_cert_signing" /tmp/tpp_register_payload.json "$DIGEST_VALUE" "$CERT_DER_B64"
run_variant "docs_payload_default_signature" "$KEYID_HEX" "(request-target) date x-request-id digest" "$docs_payload_default_signing" /tmp/tpp_register_docs_payload.json "$DOCS_DIGEST_VALUE" "$CERT_DER_B64"
run_variant "original_payload_docs_style_signature" "$DOCS_KEYID" "digest date x-request-id" "$original_payload_docs_style_signing" /tmp/tpp_register_payload.json "$DIGEST_VALUE" "$CERT_PEM_B64" "Signature "
run_variant "original_pem_cert_only" "$KEYID_HEX" "(request-target) date x-request-id digest" "$original_payload_pem_cert_only" /tmp/tpp_register_payload.json "$DIGEST_VALUE" "$CERT_PEM_B64"
run_variant "original_dn_keyid_only" "$DOCS_KEYID" "(request-target) date x-request-id digest" "$original_payload_dn_keyid_only" /tmp/tpp_register_payload.json "$DIGEST_VALUE" "$CERT_DER_B64"
run_variant "original_sig_prefix_only" "$KEYID_HEX" "(request-target) date x-request-id digest" "$original_payload_sig_prefix_only" /tmp/tpp_register_payload.json "$DIGEST_VALUE" "$CERT_DER_B64" "Signature "
run_variant "original_docs_headers_only" "$KEYID_HEX" "digest date x-request-id" "$original_payload_docs_headers_only" /tmp/tpp_register_payload.json "$DIGEST_VALUE" "$CERT_DER_B64"
run_variant "docs_literal_exactish" "$DOCS_KEYID" "digest date x-request-id" "$docs_empty_digest_signing" /tmp/tpp_register_docs_payload.json "$EMPTY_DIGEST_VALUE" "$CERT_PEM_B64" "Signature "
run_variant "docs_literal_computed_digest" "$DOCS_KEYID" "digest date x-request-id" "$docs_signing" /tmp/tpp_register_docs_payload.json "$DOCS_DIGEST_VALUE" "$CERT_PEM_B64" "Signature "
run_variant "docs_literal_no_prefix" "$DOCS_KEYID" "digest date x-request-id" "$docs_signing" /tmp/tpp_register_docs_payload.json "$DOCS_DIGEST_VALUE" "$CERT_PEM_B64"
run_variant "docs_literal_with_request_target" "$DOCS_KEYID" "(request-target) digest date x-request-id" "$docs_request_target_signing" /tmp/tpp_register_docs_payload.json "$DOCS_DIGEST_VALUE" "$CERT_PEM_B64"
