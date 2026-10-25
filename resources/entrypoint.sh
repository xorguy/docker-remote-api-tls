#!/bin/sh
set -e

if [ "$DEBUG" = "true" ]; then
  set -x
fi

if [ -n "$CERTS_PASSWORD_FILE" ]; then
  echo "Using cert password from $CERTS_PASSWORD_FILE"
  { CREATE_CERTS_WITH_PW="$(cat "$CERTS_PASSWORD_FILE")"; } 2>/dev/null
fi

if [ -n "${CREATE_CERTS_WITH_PW:+set}" ]; then
  if [ -z "$(ls -A "$CERTS_DIR" 2>/dev/null)" ]; then

    # passed to create-certs.sh via env so it does not show up in the process list or xtrace
    { export CERTS_PASSWORD="$CREATE_CERTS_WITH_PW"; } 2>/dev/null

    echo "Create CA cert"
    /script/create-certs.sh -m ca -t "$CERTS_DIR" -e "$CA_EXPIRATION_DAYS"
    echo "Create server cert"
    /script/create-certs.sh -m server -h "$CERT_HOSTNAME" -t "$CERTS_DIR" -e "$CERT_EXPIRATION_DAYS"
    echo "Create client cert"
    /script/create-certs.sh -m client -h testClient -t "$CERTS_DIR" -e "$CERT_EXPIRATION_DAYS"

    unset CERTS_PASSWORD

    mkdir "$CERTS_DIR/client"
    mv "$CERTS_DIR/ca.pem" "$CERTS_DIR/ca-cert.pem"
    cp "$CERTS_DIR/ca-cert.pem" "$CERTS_DIR/client/ca.pem"
    mv "$CERTS_DIR/client-testClient-cert.pem" "$CERTS_DIR/client/cert.pem"
    mv "$CERTS_DIR/client-testClient-key.pem" "$CERTS_DIR/client/key.pem"
    chmod 444 "$CERTS_DIR/client/key.pem"

  else

    echo "$CERTS_DIR is not empty. Not creating certs."
  fi

else  
  echo "CREATE_CERTS_WITH_PW is not set. Not creating certs."
fi
