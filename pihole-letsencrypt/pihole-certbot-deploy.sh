#!/usr/bin/env bash

set -e

# Into which folder do you want to deploy the pihole's certificates?
# For a standard installation, this would be /etc/pihole. For a docker
# container, this will be the bind mount path.
DEST=/path/to/etc-pihole

# If using pihole in docker, put the location of your docker-compose.yml
# file here. If not using docker, set to the empty string.
COMPOSE=/path/to/docker-compose.yml
#COMPOSE=""

# Enter the user and group name that the certificates will be chowned to
# after installation, and the permissions of any files that contain the
# private key
OWNER=myuser
GROUP=mygroup
PRIVKEYPERM=0600

######################################################################

# Certbot passes the live path of the renewed certificate in this variable
[[ -d "$RENEWED_LINEAGE" ]] || exit 1
SOURCE=$RENEWED_LINEAGE

# Extraneous files
cp "$SOURCE/fullchain.pem" "$DEST/tls.crt"
chown $OWNER:$GROUP "$DEST/tls.crt"
cp "$SOURCE/chain.pem" "$DEST/tls_ca.crt"
chown $OWNER:$GROUP "$DEST/tls_ca.crt"

# This one matters: combine full chain and key to one pem file
cat "$SOURCE/fullchain.pem" "$SOURCE/privkey.pem" > "$DEST/tls.pem"
chown $OWNER:$GROUP "$DEST/tls.pem"
chmod $PRIVKEYPERM "$DEST/tls.pem"

# Restart the container
if ! [ -z "$COMPOSE" ]; then
docker-compose -f "$COMPOSE" down >/dev/null
docker-compose -f "$COMPOSE" up -d >/dev/null
fi
