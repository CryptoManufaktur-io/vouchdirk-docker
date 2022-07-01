# vouchdirk-docker

Attestant's Vouch &amp; Dirk in docker compose, to be used with eth-docker

`cp default.env .env`, choose whether to run vouch and dirk or just dirk or just vouch, set the instance ID, copy a `config` directory, and
`docker-compose up -d`

`./create-dirk-config.sh` is meant to be run just once. It has no sanity checks and creates the CA, certs, and config yml files. The `config` directory
would then be copied to each server where a vouch or dirk instance runs. The script gets names from `.env`, which must exist.

This repo assumes a 2 vouch and 5 dirk setup with 3/5 threshold signing. It'd need to be adjusted for 1 vouch and 2/3 threshold signing.

To create keys, adjust start and stop index in `.env` and then run `docker-compose run --rm create-accounts`.

To verify one of these keys for correctness, run `docker-compose run --rm verify-account`

To create deposit data, using the same start and stop index in `.env`, run `docker-compose run --rm create-depositdata`. Adjust `FORK_VERSION` in
`.env` if you are going to generate for a testnet.

You can then create a single deposit.json with: `jq -n '[inputs|add]' config/depositdata/deposit-val-* > ./deposits.json`

Huge THANK YOU to Jeff Schroeder at Jump Crypto for generously sharing his knowledge of this setup
