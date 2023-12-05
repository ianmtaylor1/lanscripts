#!/usr/bin/env sh

# After updating the TXT record, check every DNS_CHECK_INTERVAL seconds
# up to DNS_MAX_CHECKS times for propagation.
DNS_CHECK_INTERVAL=10
DNS_MAX_CHECKS=31

# Which program to use for recursive DNS lookups?
# Known working:
#   dig +trace
#   drill -T
DIGTRACE="dig +trace"

###############################################################################
usage() {
        echo USAGE:
        echo
        echo "$(basename $0) <action> <credfile>"
        echo
        echo "where <action> is either 'auth' or 'cleanup'"
}

unquote() {
        sed -e 's/^"//' -e 's/"$//'
}

drop_dot() {
        sed -e 's/\.$//'
}

# Get the value of a DNS record using a recursive lookup
# USAGE: get_record example.com AAAA
get_record() {
        local name=$1
        local rtype=$2
        $DIGTRACE $rtype $name | \
                awk -v name="$name" -v rtype="$rtype" \
                '($1 == name || $1 == name".") && $4 == rtype {print $5}'
}

# Follows a trail of CNAME records from the given input name until there are
# no more CNAMES, returning the name having no more CNAME records.
# USAGE: chase_cname www.example.com
chase_cname() {
        local name=$1
        local cname=$(get_record $name CNAME)
        while [ ! -z "$cname" ]; do
                name=$cname
                cname=$(get_record $name CNAME)
        done
        echo $name | drop_dot
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

# 0. Verify usage and parse arguments
if [ ! "$#" = "2" ]; then
        usage $@
        exit 1
fi
if [ ! "$1" = "auth" ] && [ ! "$1" = "cleanup" ]; then
        usage $@
        exit 1
else
        ACTION="$1"
fi
if [ ! -f "$2" ]; then
        usage $@
        exit 1
else
        CRED_FILE="$2"
fi

# 1. Determine whether we are validating or cleaning up
if [ "$ACTION" = "cleanup" ]; then
        txtvalue="completed"
else
        txtvalue=$CERTBOT_VALIDATION
fi

# 2. Determine the TXT record we need to update
TXTNAME=$(chase_cname _acme-challenge.$CERTBOT_DOMAIN)

# 3. Update the TXT record with the provided value from certbot
echo Updating $TXTNAME ...
update_txt $TXTNAME $txtvalue $(get_api_key $TXTNAME $CRED_FILE)

# 4. Check periodically until record propogates
if [ "$ACTION" = "auth" ]; then
        checknum=0
        while [ "$checknum" -lt "$DNS_MAX_CHECKS" ]; do
                echo Waiting for DNS propagation...
                sleep $DNS_CHECK_INTERVAL
                [ "$(get_record $TXTNAME TXT | unquote)" = "$txtvalue" ] && break
                checknum=$((checknum+1))
        done
        if [ "$checknum" = "$DNS_MAX_CHECKS" ]; then
                echo Record did not propagate.
                exit 1
        fi
fi

echo Done.
