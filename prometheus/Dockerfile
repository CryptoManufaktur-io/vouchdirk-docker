FROM prom/prometheus:latest

COPY ./*-prom.yml /etc/prometheus/
COPY --chown=nobody:nobody ./choose-config.sh /usr/local/bin/choose-config.sh
# Belt and suspenders
RUN chmod -R 755 /usr/local/bin/*
USER root
RUN chown nobody:nobody /etc/prometheus/*.yml
USER nobody

# For reference and local testing with docker; this is otherwise set by docker-compose
ENV CLIENT=dirk

ENTRYPOINT choose-config.sh
CMD ["/bin/prometheus", "--storage.tsdb.path=/prometheus", "--web.console.libraries=/usr/share/prometheus/console_libraries", "--web.console.templates=/usr/share/prometheus/consoles"]
