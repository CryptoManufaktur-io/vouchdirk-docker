# vouchdirk-docker

Attestant's Vouch &amp; Dirk in docker compose, to be used with eth-docker

This repo assumes a 2 vouch and 5 dirk setup with 3/5 threshold signing, and 3 Ethereum CL:EL full nodes.

## Initial setup

`cp default.env .env`, edit it to choose whether to run vouch and dirk or just dirk or just vouch, set the instance ID
for dirk/vouch, and adjust host and domain names to fit your environment.

If you are going to use Vouch traces, set `TRACE_URL` and `VOUCH_SAN` in `.env`. Either copy `tempo_authority.crt` into
`config/certs`, or if you don't have a CA and server key for Tempo yet, let the next step create them.

`./create-dirk-config.sh` is meant to be run just once. It has no sanity checks and creates the CA, certs, and
config yml files. The `config` directory would then be copied to each server where a vouch or dirk instance runs. The
script gets names from `.env`, which must exist.

`./ethd up` to start Vouch/Dirk services.

On each of the Dirk instances, run `docker compose run --rm create-wallet` once.

Run `./ethd restart dirk` to ensure Dirk loads this new wallet correctly.

## Key generation

To create keys, adjust start and stop index in `.env` and then run `docker compose run --rm create-accounts`.

To verify the first of these keys for correctness, run `docker compose run --rm verify-account`

To create deposit data, using the same start and stop index in `.env`, run `docker compose run --rm create-depositdata`.
Adjust `FORK_VERSION` in `.env` if you are going to generate for a testnet.

You can then create a single deposit.json with:  
`jq -n '[inputs|add]' config/depositdata/deposit-val-{1..10}.json > ~/deposits.json`  
adjusting the `{1..10}` for the range you want to have in the file.

## Architecture; redundancy and slashing considerations

2 Vouch (one warm standby) and a 3/5 Dirk (3 threshold, 5 total) were chosen carefully. With 2 Vouch and 2/4 Dirk there
would be a risk of slashing; 3 Vouch and 3/5 Dirk, Vouch might not get to threshold and never be able to sign duties. 

1 Vouch and 2/3 Dirk would also work just as well.

This repository was created for a cross-region setup, with five hosts for Vouch/Dirk and 3 separate hosts for the CL:EL
Ethereum nodes. It'd need some adjustment to be more flexible in these numbers.

An alternate setup could run 1 Vouch and a 2/3 Dirk threshold setup inside a single k8s cluster. This repo does not aim
to support that use case.

The reason a cross-region setup was chosen is that while region outages are rare, they do occur. It is desirable for a
staking node operator to be able to regain liveness even when an entire region fails.

With multiple Vouch instances, a degradation in the number of Dirk instances can result in the inability to sign. At its
simplest, if there are 2 Vouch and 4 Dirk (out of originally 5) with a threshold of 3, then it is possible for one Vouch
instance to obtain 2 signatures and the second Vouch instance to obtain 2 signatures, with neither reaching the
threshold and no signature generated. If MEV is in use, the CL needs to "point back to" Vouch, and this as well requires
the use of a single Vouch instance.

For this reason, it is recommended to run Vouch in container orchestration with cross-AZ failover, and have the second
Vouch instance ready in case there is an outage for an entire region. Vouch is stateless and will start in seconds.

Slashing protection works like this:
- Vouch will ask Dirk for a threshold signature
- A Dirk that has already participated in one will refuse to do so again because of the slashing protection DB. That
means if both Vouch are running simultaneously, one will get to at least 3/5, the other to at most 2/5 and won't get a
full signature
- The slashing protection DB is kept locally by each Dirk

## Adding and removing keys

The recommendation by attestant.io is to restart Dirk instances after adding or removing keys, because of the way
caching works.

## Backup and restore

To back up the wallet on each local Dirk instance, run `docker compose run --rm export-keys` and then save the resulting
file and the passphrase you used.

You will need to run this on all five (5) Dirk instances individually.

Each Dirk instance is its own entity. If a Dirk instance fails, the backup of that instance can be restored, and once it
is rebuilt it will continue in the cluster.

## Prometheus

By adding `:prometheus.yml` to `COMPOSE_FILE` in `.env`  you can run a Prometheus that can remote-write to your Mimir or
Thanos, with the remote-write section in `prometheus/custom-prom.yml`.


## Promtail - Logs collection

By adding `promtail.yml:ext-network.yml` [***Add ext-network.yml once, if already added in prometheus then skip it***] you can run a Promtail that will collect logs from all containers and send them to your remote Loki, with the remote-write section in `promtail/custom-lokiurl.yml`.


## Promtail - Logs collection

By adding `promtail.yml:ext-network.yml` you can run a Promtail that will collect logs from all containers and send them to your remote Loki, with the remote-write section in `promtail/custom-lokiurl.yml`.

## Acknowledgements

Huge THANK YOU to Jeff Schroeder at Jump Crypto for generously sharing his knowledge of this setup, and to Jim McDonald
at attestant.io for creating these tools in the first place, and always having patience and time for explanations.

## Resources

- [Distributed key generation guide](https://github.com/attestantio/dirk/blob/master/docs/distributed_key_generation.md)  
- [Ethstaker Discord](https://discord.io/ethstaker)  
- [Attestant Discord](https://discord.gg/U5GNUuQQr3)

## License

[Apache License v2](LICENSE)

## Version

This is vouchdirk-docker v1.1.1
