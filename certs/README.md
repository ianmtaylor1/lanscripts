# Manual Hook for Certbot and Hurricane Electric DNS 

This script is a hook for the `--manual-auth-hook` and `--manual-cleanup-hook` options of [Certbot](https://certbot.eff.org/)
that can perform DNS-01 challenges to issue certificates.

## How to use

1. Edit the parameters at the top of the script, if necessary. Defaults will work on systems with `dig` installed.
2. Create credentials file (see below)
3. Run
```
certbot certonly \
    -d myserver.example.com \
    --preferred-challenges dns --manual \
    --manual-auth-hook '/path/to/he-manual-hook.sh auth /path/to/creds.txt' \
    --manual-cleanup-hook '/path/to/he-manual-hook.sh cleanup /path/to/creds.txt'
```
replacing the domain and your path to the script. Optionally also specify a `--deploy-hook` to install the certificate.

## CNAME chasing

One of the things that makes this script especially useful to me is its ability to follow CNAMEs. During DNS-01 challenges, 
if the `_acme-challenge.` record is a CNAME, the issuer will follow it until it finds a TXT record. This script does the same
thing when determining which TXT record it needs to update. If you are issuing a certificate for `server.example.com`, and there
is a CNAME record, this script will follow CNAMEs until it arrives at a name with a TXT record. As long as *that* TXT record is on
Hurricane Electric DNS, and a credential for that TXT record exists in your credentials file, this script will update it just fine.

## The credentials file

The credentials file is a text file with two whitespace-separated columns. The first column is the full TXT record name used in the 
DNS-01 challenge (e.g. `_acme-challenge.server.example.com`) and the second column is the Hurricane Electric ddns key used
to update that record. This file only needs to be readable by the user the script runs as, which in the case of certbot is root.
