#!/usr/bin/env sh

# DNS servers. DNS_SERVER is used to trace CNAMES to the TXT record that
# needs to be updated. Script waits until both DNS_SERVER and
# DNS_SERVER_SECONDARY have the updated value before returning. Best to
# supply servers from two different providers.
DNS_SERVER=one.one.one.one
DNS_SERVER_SECONDARY=dns.google

# Text file containing dyn.dns.he.net API credentials. Each line contains
# the full name of the TXT record and the API update key, spearated by
# whitespace.
CRED_FILE=/mnt/acme/scripts/creds.txt

# After updating the TXT record, check every DNS_CHECK_INTERVAL seconds
# up to DNS_MAX_CHECKS times for propagation.
DNS_CHECK_INTERVAL=30
DNS_MAX_CHECKS=11


###############################################################################
usage() {
        echo USAGE:
        echo
        echo "$0 <action>"
        echo
        echo "where <action> is either 'auth' or 'cleanup'"
}

unquote() {
        sed -e 's/^"//' -e 's/"$//'
}

# USAGE: get_record example.com AAAA 8.8.8.8
get_record() {
        local name=$1
        local rtype=$2
        local server=$3
        dig +short $name @$server $rtype
}

# Follows a trail of CNAME records from the given input name until there are
# no more CNAMES, returning the name having no more CNAME records.
# USAGE: chase_cname www.example.com 8.8.8.8
chase_cname() {
        local name=$1
        local server=$2
        local cname=$(get_record $name CNAME $server)
        while [ ! -z "$cname" ]; do
                name=${cname%.} # Remove any trailing period
                cname=$(get_record $name CNAME $server)
        done
        echo $name
}

# Updates a Hurricane Electric TXT record to the specified value
# USAGE: update_txt www.example.com <value> <api-key>
update_txt() {
        local name=$1
        local value=$2
        local key=$3
        local out=$(curl "https://dyn.dns.he.net/nic/update" \
                -d "hostname=$name" \
                -d "password=$key" \
                -d "txt=$value" \
                2>/dev/null)
        status=${out%% *}
        if [ ! "$status" = "good" ] && [ ! "$status" = "nochg" ]; then
                echo $out
                exit 1
        fi
}

# Return key for the txt record from the credentials file
# File format: two columns separated by whitespace. First column is full record
# name (e.g. _acme-challenge.sub.example.com), second column is the API key.
# USAGE: get_api_key <record-name> <file>
get_api_key() {
        local txtname=$1
        local credfile=$2
        awk -v name="$txtname" '$1 == name { print $2 }' $credfile
}

###############################################################################

# 0. Verify usage
if [ ! "$#" = "1" ]; then
        usage $@
        exit 1
fi
if [ ! "$1" = "auth" ] && [ ! "$1" = "cleanup" ]; then
        usage $@
        exit 1
fi

# 1. Determine whether we are validating or cleaning up
if [ "$1" = "cleanup" ]; then
        txtvalue="completed"
else
        txtvalue=$CERTBOT_VALIDATION
fi

# 2. Determine the TXT record we need to update
TXTNAME=$(chase_cname _acme-challenge.$CERTBOT_DOMAIN $DNS_SERVER)

# 3. Update the TXT record with the provided value from certbot
echo Updating $TXTNAME ...
update_txt $TXTNAME $txtvalue $(get_api_key $TXTNAME $CRED_FILE)

# 4. Check periodically until record propogates
if [ "$1" = "auth" ]; then
        checknum=0
        while [ "$checknum" -lt "$DNS_MAX_CHECKS" ]; do
                echo Waiting for DNS propagation...
                sleep $DNS_CHECK_INTERVAL
                [ "$(get_record $TXTNAME TXT $DNS_SERVER | unquote)" = "$txtvalue" ] \
                        && [ "$(get_record $TXTNAME TXT $DNS_SERVER_SECONDARY | unquote)" = "$txtvalue" ] \
                        && break
                checknum=$((checknum+1))
        done
        if [ "$checknum" = "$DNS_MAX_CHECKS" ]; then
                echo Record did not propagate.
                exit 1
        fi
fi

echo Done.

