#!/bin/bash
# Get name params
while getopts n: flag
do
    case "${flag}" in
        n) name=${OPTARG};;
    esac
done
if [ -z "$name" ]; then
  echo "Target certificate name not found"
  exit 1
fi

out_name=$(echo "$name" | tr ' ' '_' | tr '-' '_' | tr '[:upper:]' '[:lower:]')
echo "Generate certificate: $out_name";

# Setup directories
out_dir="./$out_name"
if [ ! -d $out_dir ]; then
  mkdir -p $out_dir;
fi

# 1. Generate CA and Client private keys
ca_private="./ca_private.key"
if [ ! -f "$ca_private" ]; then
  openssl genrsa -out $ca_private 2048
fi

client_private="$out_dir/${out_name}_client_private.key"
openssl genrsa -out $client_private 2048

# 2. Generate openssl configuration for CA CSR
ca_openssl="./ca_openssl.cnf"
cat > $ca_openssl << EOF

[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
default_md = sha1
distinguished_name = dn

[ dn ]
CN = SaltEdge CA Authority
O = SaltEdgeCA
C = RO
ST = Fake street

[ cert_ext ]
subjectKeyIdentifier=hash
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth,serverAuth
EOF

# 3. Create CA CSR
ca_csr="./ca.csr"
if [ ! -f "$ca_csr" ]; then
  openssl req -config ca_openssl.cnf -new -key $ca_private -nodes -out $ca_csr
fi

# 4. Create CA self signed certificate from CA CSRs
ca_certificate="./ca_certificate.crt"
if [ ! -f "$ca_certificate" ]; then
  openssl x509 -signkey $ca_private -in $ca_csr -req -days 365 -out $ca_certificate
fi

# 5. Generate openssl configuration for Client CSR
client_openssl="$out_dir/${out_name}_client_openssl.cnf"
#template.
cat > $client_openssl << EOF
[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
default_md = sha1
distinguished_name = dn

[ dn ]
CN = $out_name TEST TPP
O = TEST-TPP-$out_name
C = RO
ST = Fake street
organizationIdentifier = TEST-TPP-$out_name

[ cert_ext ]
basicConstraints = CA:TRUE
subjectKeyIdentifier = hash
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth,serverAuth
qcStatements = "ASN1:UTF8String:...statement PSP_AI PSP_PI PSP_CI..."
EOF

# 6. Create Client CSR
client_csr="$out_dir/${out_name}_client.csr"
openssl req -config $client_openssl -new -key $client_private -nodes -out $client_csr

# 7. Create Client self signed certificate from Client CSR
client_signed_certifcate="$out_dir/${out_name}_client_signed_certifcate.crt"
openssl x509 -req -days 360 -extfile $client_openssl -extensions cert_ext -in $client_csr -CAcreateserial -CA $ca_certificate -CAkey $ca_private -out $client_signed_certifcate

# 8. Zip Client output
zip -r "$out_dir.zip" "$out_dir/"
