# Dynamic DNS Update

IPv4 and IPv6 Dynamic DNS on [Hurricane Electric DNS](https://dns.he.net/).

## Requirements

Your LAN network needs:

* IPv4 via NAT (optional)
* Public delegated IPv6 prefix (can be dynamic)
  - The prefix for the network of your server should be a /64.

Your server needs:

* A public IPv6 address
* Python 3
* [dnspython](https://dnspython.readthedocs.io/en/latest/)
* The `ip` command.

Your server can optionally have: (These will improve your experience.)

* A static host part of IPv6 address (e.g. modified EUI-64, DHCPv6 static allocation, or address token)

## How it works

### IPv4

The IPv4 DDNS update is simple. It uses an internet-based API, in this case [ipify.org](https://ipify.org), 
to determine the public IPv4 address assigned to your router and updates the Hurricane Electric `A` record accordingly. 
It assumes you are using port forwarding on your router to allow access to your server over IPv4 behind NAT.

### IPv6

The IPv6 DDNS update is more complicated for a few reasons:

* Each computer on the LAN has its own public IPv6 address(es), and NAT is not used at the router.
* Each computer can actually have *multiple* IPv6 addresses: multiple prefixes, link-local addresses, ULA addresses,
and temporary addresses are all possible.
* If a computer has temporary addresses, it will prefer those for outgoing connections. So the address returned by
a service like [api6.ipify.org](https://api6.ipify.org) will not necessarily be the best address at which to reach a server.

As a result, the selection of the IPv6 address is based on collecting all the IPv6 addresses available on the server and
ranking them according to some criteria, then selecting the best address. This ranking is based on a comparison to
the current IPv6 address in Hurricane Electric's `AAAA` record (the "registered" address), so it depends on you manually 
setting one value at the beginning.

First, the script finds "candidates": any globally routable IPv6 address on the specified interface(s) not marked 
"temporary" or "deprecated" by the `ip` command. Then it ranks them according to these sorting values:

1. Sort first by host identifier. Is the host identifier (low 64 bits) of the address the same as the currently registered
address? Sort all matching addresses over non-matching addresses.
2. Sort next by prefix match length. Sort addresses so that ones having a longer prefix in common with the registered addresss
are sorted first.

Finally, update the `AAAA` record with the highest-ranked address according to these criteria.
