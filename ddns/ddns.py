#!/usr/bin/env python3

import dns.resolver # Requires dnspython
import ipaddress as ip
import requests
import subprocess
from datetime import datetime

# Domain we are updating
domain = "myserver.example.com"
# Hurricane Electric DDNS update key for the domain
update_key = "xxx"
# Servers to use to check current DNS assignment
check_servers = ["2001:470:100::2", "216.218.130.2"]
# Specific interface from which to get IPv6 addresses. Blank for all.
interface = ""

########################################

def get_current_v4():
    # Get the current IPv4 address for the server by asking an external API
    response = requests.get("https://api4.ipify.org/")
    if not response:
        raise Exception("Error {} getting current IPv4".format(response.status_code))
    return response.text

def get_registered(domain, servers, rdtype):
    # Query the given domain at the given DNS server to see what IP is currently registered.
    resolver = dns.resolver.Resolver(configure=False)
    resolver.nameservers = servers
    answer = resolver.resolve(domain, rdtype)
    if len(answer) > 1:
        raise Exception("Got {} records. Expected 1.".format(len(answer)))
    return answer[0].address

def get_registered_v4(domain, servers):
    return get_registered(domain, servers, "A")

def get_registered_v6(domain, servers):
    return ip.IPv6Address(get_registered(domain, servers, "AAAA")).compressed

def update_he(domain, key, ip):
    # Update DDNS entry with Hurricane Electric DNS (IPv4 or IPv6)
    response = requests.post("https://dyn.dns.he.net/nic/update",
            {"hostname":domain, "password":key, "myip":ip})
    # Check errors
    response.raise_for_status()
    # Return True if address updated, False if no change
    if response.text[:4] == "good":
        return True
    elif response.text[:5] == "nochg":
        return False
    else:
        raise Exception("DNS Update Failed: {}".format(response.text))

def get_candidates_v6(iface = ""):
    # Get list of global IPv6 addresses on given interface
    cmd = "ip -6 addr show {} -temporary -deprecated | awk '/inet/{{print $2}}' | cut -d '/' -f 1".format(iface)
    cmdout = subprocess.check_output(cmd, shell=True).decode('utf8', 'strict').split("\n")
    candidates = [ip.IPv6Address(x) for x in cmdout if x != ""]
    return [x.compressed for x in candidates if x.is_global]

def _first_diff(a, b):
    # Find the index of the first character in which two strings differ
    for i,p in enumerate(zip(a,b)):
        if p[0] != p[1]:
            return i
    return min(len(a), len(b))

def best_candidate_v6(candidates, current):
    # Of the list of candidate IPv6 addresses, select the best to replace
    # the current address. Rank first on host id (low 64 bits) equalling,
    # then on longest prefix match
    current_ip = ip.IPv6Address(current)
    current_host = int(current_ip) % (2**64)
    current_bits = "{:#b}".format(current_ip)[2:66]

    def prefkey(x):
        x_ip = ip.IPv6Address(x)
        x_host = int(x_ip) % (2**64)
        x_bits = "{:#b}".format(x_ip)[2:66]
        return (-(x_host == current_host), -_first_diff(x_bits, current_bits), x_host)

    return sorted(candidates, key=prefkey)[0]


########################################

registered_v4 = get_registered_v4(domain, check_servers)
current_v4 = get_current_v4()
registered_v6 = get_registered_v6(domain, check_servers)
current_v6 = best_candidate_v6(get_candidates_v6(interface), registered_v6)

changed_v4 = False
changed_v6 = False

if registered_v4 != current_v4:
    if update_he(domain, update_key, current_v4):
        changed_v4 = True

if registered_v6 != current_v6:
    if update_he(domain, update_key, current_v6):
        changed_v6 = True


if changed_v4 or changed_v6:
    print(datetime.now())
if changed_v4:
    print("(IPv4) {} -> {}".format(registered_v4, current_v4))
if changed_v6:
    print("(IPv6) {} -> {}".format(registered_v6, current_v6))
