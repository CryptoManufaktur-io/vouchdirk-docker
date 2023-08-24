#!/usr/bin/env bash
# Run this once, it currently does not query or sanity check anything at all
set -e
source .env
mkdir -p ./config/certs
cd config/certs
echo Creating authority
if [ ! -f dirk_authority.key ]; then
  openssl genrsa -des3 -out dirk_authority.key 4096
fi
if [ ! -f dirk_authority.crt ]; then
  openssl req -x509 -new -nodes -key dirk_authority.key -sha256 -days 1825 -out dirk_authority.crt
fi
cat << EOF >generic.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
EOF
echo Create vouch 1 and 2 keys
for i in {1..2}; do
  if [ -f vouch$i.crt ]; then
    continue
  fi
  openssl genrsa -out vouch$i.key 4096
  cp generic.ext vouch$i.ext
  echo "DNS.1 = vouch$i" >> vouch$i.ext
  openssl req -out vouch$i.csr -key vouch$i.key -new -subj "/CN=vouch$i" -addext "subjectAltName=DNS:vouch$i"
  openssl x509 -req -in vouch$i.csr -CA dirk_authority.crt -CAkey dirk_authority.key -CAcreateserial -out vouch$i.crt -days 1825 -sha256 -extfile vouch$i.ext  
  openssl x509 -in vouch$i.crt -text -noout
done
echo Create dirk 1 through 5 keys
for i in {1..5}; do
  if [ -f dirk$i.crt ]; then
    continue
  fi
  openssl genrsa -out dirk$i.key 4096
  cp generic.ext dirk$i.ext
  varname=DIRK$i
  echo "DNS.1 = ${!varname}.${DOMAIN}" >> dirk$i.ext
  openssl req -out dirk$i.csr -key dirk$i.key -new -subj "/CN=${!varname}.${DOMAIN}" -addext "subjectAltName=DNS:${!varname}.${DOMAIN}"
  openssl x509 -req -in dirk$i.csr -CA dirk_authority.crt -CAkey dirk_authority.key -CAcreateserial -out dirk$i.crt -days 1825 -sha256 -extfile dirk$i.ext
  openssl x509 -in dirk$i.crt -text -noout
done
echo Create dirk config files
cd ..
ceil=10000
floor=1000
for i in {1..5}; do
  part1=0
  part2=0
  while [ "$part1" -le $floor ]; do
    part1=$RANDOM
    let "part1 %= $ceil"
  done
  while [ "$part2" -le $floor ]; do
    part2=$RANDOM
    let "part2 %= $ceil"
  done
  id[$i]=$part1$part2
  echo "ID $i is ${id[$i]}"
done

__publicIP=$(curl -s -4 https://ifconfig.me/ip)

for i in {1..5}; do
  if [ -f dirk$i.yml ]; then
    continue
  fi
  varname=DIRK$i
  cat << EOF >dirk$i.yml
# log-level is the global log level for Dirk logging.
log-level: Info

server:
  # id should be randomly chosen 8-digit numeric ID; it must be unique across all of your Dirk instances.
  id: ${id[$i]}
  # name is the name of your server, as specified in its SSL certificate.
  name: ${!varname}.${DOMAIN}
  # listen-address is the interface and port on which Dirk will listen for requests; change 127.0.0.1
  # to 0.0.0.0 to listen on all network interfaces.
  listen-address: 0.0.0.0:13141
  rules:
    # admin-ips is a list of IP addresses from which requests for voluntary exits will be accepted.
    admin-ips: [ ${__publicIP} ]
# storage-path is the path where information created by the slashing protection system is stored.
storage-path: /data/protection
certificates:
  # server-cert is the majordomo URL to the server's certificate.
  server-cert: file:///config/certs/dirk$i.crt
  # server-key is the majordomo URL to the server's key.
  server-key: file:///config/certs/dirk$i.key
  # ca-cert is the certificate of the CA that issued the client certificates.  If not present Dirk will use
  # the standard CA certificates supplied with the server.
  ca-cert: file:///config/certs/dirk_authority.crt
# stores is a list of locations and types of Ethereum 2 stores.  If no stores are supplied Dirk will use the
# default filesystem store.
stores:
- name: Local
  type: filesystem
  location: /data/wallets
metrics:
  # listen-address is where Dirk's Prometheus server will present.  If this value is not present then Dirk
  # will not gather metrics.
  listen-address: 0.0.0.0:8081
peers:
  # These are the IDs and addresses of the peers with which Dirk can communicate for distributed key generation.
  # At a minimum it must include this instance.
  ${id[1]}: ${DIRK1}.${DOMAIN}:13141
  ${id[2]}: ${DIRK2}.${DOMAIN}:13141
  ${id[3]}: ${DIRK3}.${DOMAIN}:13141
  ${id[4]}: ${DIRK4}.${DOMAIN}:13141
  ${id[5]}: ${DIRK5}.${DOMAIN}:13141
unlocker:
  # account-passphrases is a list of passphrases that can be used to unlock wallets.  Each entry is a majordomo URL.
  account-passphrases:
  - file:///config/passphrases/account-passphrase.txt
process:
  # generation-passphrase is the passphrase used to encrypt newly-generated accounts.  It is a majordomo URL.
  generation-passphrase: file:///config/passphrases/account-passphrase.txt
permissions:
  # This permission allows vouch1/2 the ability to carry out all operations on accounts in all wallets. 
  vouch1:
    .*: All
  vouch2:
    .*: All
EOF
done
echo Create passphrase
mkdir -p passphrases
if [ ! -f passphrases/account-passphrase.txt ]; then
  openssl rand -base64 32 >passphrases/account-passphrase.txt
fi
echo Create vouch config files
for i in {1..2}; do
  if [ -f vouch$i.yml ]; then
    continue
  fi
  cat << EOF >vouch$i.yml
# log-level is the global log level for Vouch logging.
log-level: Info

beacon-node-addresses:
  - ${CL1}
  - ${CL2}
  - ${CL3}

# metrics is the module that logs metrics, in this case using prometheus.
metrics:
  prometheus:
    # log-level is the log level for this module, over-riding the global level.
    log-level: warn
    # listen-address is the address on which prometheus listens for metrics requests.
    listen-address: 0.0.0.0:8081

# graffiti provides graffiti data.  Full details are in the separate document.
graffiti:
  static:
    value: ${GRAFFITI}

# scheduler handles the scheduling of Vouch's operations.
scheduler:
  # style can be 'basic' (deprecated) or 'advanced' (default).  Do not use the basic scheduler unless instructed.
  style: advanced

# submitter submits data to beacon nodes.  If not present the nodes in beacon-node-address above will be used.
submitter:
  # style can currently only be 'multinode'
  style: multinode

# blockrelay provides information about mev relays.  Advanced configuration
# information is available in the documentation.
blockrelay:
  fallback-fee-recipient: '${FEE_RECIPIENT}'
  config:
    url: file:///config/vouch-ee.json

# strategies provide advanced strategies for dealing with multiple beacon nodes
strategies:
  beaconblockproposal:
    # style can be 'best', which obtains blocks from all nodes and compares them, or 'first', which uses the first returned
    style: best
  blindedbeaconblockproposal:
    # style can be 'best', which obtains blocks from all nodes and compares them, or 'first', which uses the first returned
    style: best
  # The attestationdata strategy obtains attestation data from multiple sources.
  attestationdata:
    # style can be 'best', which obtains attestations from all nodes and selects the best, or 'first', which uses the first returned
    style: best
  # The aggregateattestation strategy obtains aggregate attestations from multiple sources.
  # Note that the list of nodes here must be a subset of those in the attestationdata strategy.  If not, the nodes will not have
  # been gathering the attestations to aggregate and will error when the aggregate request is made.
  aggregateattestation:
    # style can be 'best', which obtains aggregates from all nodes and selects the best, or 'first', which uses the first returned
    style: best
  # The synccommitteecontribution strategy obtains sync committee contributions from multiple sources.
  synccommitteecontribution:
    # style can be 'best', which obtains contributions from all nodes and selects the best, or 'first', which uses the first returned
    style: best

accountmanager:
  dirk:
    endpoints:
      - ${DIRK1}.${DOMAIN}:13141
      - ${DIRK2}.${DOMAIN}:13141
      - ${DIRK3}.${DOMAIN}:13141
      - ${DIRK4}.${DOMAIN}:13141
      - ${DIRK5}.${DOMAIN}:13141
    client-cert: file:///config/certs/vouch$i.crt
    client-key: file:///config/certs/vouch$i.key
    ca-cert: file:///config/certs/dirk_authority.crt
    accounts:
      - ${WALLET_NAME}
EOF
done
cat << EOF >vouch-ee.json.tmp
{
  "version": 2,
  "fee_recipient": "${FEE_RECIPIENT}",
  "gas_limit": "30000000",
  "relays": {
        ${MEV_RELAYS}
  }
}
EOF
jq . <vouch-ee.json.tmp >vouch-ee.json
rm vouch-ee.json.tmp
echo Create exiter config file
cat << EOF >exiter.yml
running_mode: SIGNER

beacon_node_url: ${CL1}

dirk:
  endpoint: ${DIRK1}.${DOMAIN}:13141
  client_cert: /config/certs/vouch1.crt
  client_key: /config/certs/vouch1.key
  ca_cert: /config/certs/dirk_authority.crt
  wallet: ${WALLET_NAME}
EOF

if [ -z "${TRACE_URL}" ]; then
  echo Done
  exit 0
fi

if [ ! -f "./certs/tempo_authority.crt" ]; then
  echo Tempo authority not found, creating
  echo If you already have one, abort now and copy it in!
  cd certs
  if [ ! -f tempo_authority.key ]; then
    openssl genrsa -des3 -out tempo_authority.key 4096
  fi
  if [ ! -f tempo_authority.crt ]; then
    openssl req -x509 -new -nodes -key tempo_authority.key -sha256 -days 1825 -out tempo_authority.crt
  fi
  if [ ! -f tempo_host.crt ]; then
    echo Generating tempo_host key for tempo server
    trace_host=$(echo "${TRACE_URL}" | awk -F[/:] '{print $4}')
    openssl genrsa -out tempo_host.key 4096
    cp generic.ext tempo_host.ext
    echo "DNS.1 = ${trace_host}" >> tempo_host.ext
    openssl req -out tempo_host.csr -key tempo_host.key -new -subj "/CN=${trace_host}" -addext "subjectAltName=DNS:${trace_host}"
    openssl x509 -req -in tempo_host.csr -CA tempo_authority.crt -CAkey tempo_authority.key -CAcreateserial -out tempo_host.crt -days 1825 -sha256 -extfile tempo_host.ext
    openssl x509 -in tempo_host.crt -text -noout
  fi
  cd ..
fi

if [ ! -f "./certs/tempo_client.crt" ]; then
  cd certs
  openssl genrsa -out tempo_client.key 4096
  cp generic.ext tempo_client.ext
  echo "DNS.1 = ${VOUCH_SAN}" >> tempo_client.ext
  openssl req -out tempo_client.csr -key tempo_client.key -new -subj "/CN=${VOUCH_SAN}" -addext "subjectAltName=DNS:${VOUCH_SAN}"
  openssl x509 -req -in tempo_client.csr -CA tempo_authority.crt -CAkey tempo_authority.key -CAcreateserial -out tempo_client.crt -days 1825 -sha256 -extfile tempo_client.ext
  openssl x509 -in tempo_client.crt -text -noout
  cd ..
fi

for i in {1..2}; do
  if grep -q "tracing:" vouch$i.yml; then
    continue
  fi
  echo Append tracing config to vouch$i.yml config
  cat << EOF >>vouch$i.yml

tracing:
  # Address is the host and port of an OTLP trace receiver.
  address: '${TRACE_URL}'
  client-cert: file:///config/certs/tempo_client.crt
  client-key: file:///config/certs/tempo_client.key
  ca-cert: file:///config/certs/tempo_authority.crt
EOF
done

echo Done
