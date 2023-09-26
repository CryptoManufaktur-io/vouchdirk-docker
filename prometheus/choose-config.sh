#!/bin/sh
# Check CLIENT, which is COMPOSE_FILE, for the
# Prometheus config we need.
# Expects a full prometheus command with parameters as argument(s)

cp /etc/prometheus/global-prom.yml /etc/prometheus/prometheus.yml

case "$CLIENT" in
  *dirk* ) cat /etc/prometheus/dirk-prom.yml >> /etc/prometheus/prometheus.yml;;
esac

case "$CLIENT" in
  *vouch* ) cat /etc/prometheus/vouch-prom.yml >> /etc/prometheus/prometheus.yml;;
esac

if [ -f "/etc/prometheus/custom-prom.yml" ]; then
    cat /etc/prometheus/custom-prom.yml >> /etc/prometheus/prometheus.yml
fi

exec "$@" --config.file=/etc/prometheus/prometheus.yml
