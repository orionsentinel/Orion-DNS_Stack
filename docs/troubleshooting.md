# Troubleshooting

Practical, copy-paste fixes for the common failure modes. Addresses use the
canonical scheme (`docs/networking.md`): Node A `.244`, Node B `.245`, VIP `.243`.

## Quick health check

```bash
./scripts/verify-ha.sh        # VIP owner, keepalived state, DNS via VIP + node IP
dig @192.168.8.243 github.com +short   # resolution via the VIP
docker compose ps             # containers up, healthy
docker logs keepalived --tail 50
```

## Secondary becomes MASTER while primary is healthy (split-brain)

VRRP packets aren't reaching the peer. Check unicast config on **both** nodes:

```bash
docker exec keepalived sh -c 'grep -E "unicast_src_ip|unicast_peer" -A2 /etc/keepalived/keepalived.conf'
```

Expected — Node A: `unicast_src_ip 192.168.8.244`, peer `192.168.8.245`
(and the mirror on Node B). If wrong, fix `PEER_IP` / `UNICAST_SRC_IP` in `.env`
and recreate: `docker compose --profile two-node-ha-primary up -d --force-recreate keepalived`.

Confirm VRRP (protocol 112) is flowing:

```bash
docker exec keepalived sh -c 'apk add --no-cache tcpdump >/dev/null 2>&1; tcpdump -ni eth0 proto 112 -c 10'
```

- Packets on primary but none on secondary → `rp_filter` / NIC / switch filtering.
- None anywhere → wrong `PEER_IP` or capability issue (`NET_RAW` needed).

## No DNS on the VIP

`dig @192.168.8.243` times out:

1. VIP assigned? `ip addr show eth0 | grep 192.168.8.243`
2. `network_mode: host` set in `compose.yml` (it is, by default).
3. `DNSMASQ_LISTENING=all` in `.env`.
4. Firewall allows 53/udp+tcp.

## iPhone / device bypasses DNS

A device resolves names you should be blocking → it's using its own DoH/DoT.

```bash
# Prove the device isn't hitting the VIP:
dig @192.168.8.243 doubleclick.net +short    # should be 0.0.0.0 / blocked
```

Fixes (at the router):
- Hand out **only** the VIP `192.168.8.243` as DNS via DHCP.
- Redirect/NAT all outbound `:53` to the VIP so static DNS settings can't escape.
- Block known DoH resolver endpoints, or enable "disable DoH" if your router/Pi-hole
  supports the `use-application-dns.net` canary (Pi-hole blocks it by default).

## VRRP_PASSWORD errors / keepalived restart loop

```bash
docker logs keepalived 2>&1 | grep -A5 "Validating environment"
```

`VRRP_PASSWORD` must be **exactly 8 characters** and identical on both nodes. Fix
`.env`, then `--force-recreate keepalived`. Also check for unresolved `${VAR}`
literals in the rendered config (the entrypoint resolves these; a restart loop
often means a missing env var).

## "dnsmasq: cannot open log ... Is a directory"

`pihole.log` got created as a directory:

```bash
rm -rf ./pihole/var-log/pihole.log && touch ./pihole/var-log/pihole.log
./scripts/bootstrap_dirs.sh        # or just recreate the dirs
docker compose restart pihole_unbound
```

## NIC flapping (`eth0 down` / link resets)

Common with USB 2.5G adapters. Disable EEE and USB power management, check
cabling/switch. `dmesg -T | grep -Ei 'eth0|link (up|down)|reset' | tail`.
