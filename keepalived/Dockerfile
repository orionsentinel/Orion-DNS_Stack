FROM alpine:3.23

RUN apk add --no-cache keepalived bash curl bind-tools iproute2 iputils gettext ca-certificates

ENV KEEPALIVED_CONFIG_DIR=/etc/keepalived

COPY entrypoint.sh /usr/local/bin/keepalived-entrypoint.sh
COPY scripts/check_dns.sh /usr/local/share/keepalived/check_dns.sh
COPY scripts/notify_master.sh /usr/local/share/keepalived/notify_master.sh
COPY scripts/notify_backup.sh /usr/local/share/keepalived/notify_backup.sh
COPY scripts/notify_fault.sh /usr/local/share/keepalived/notify_fault.sh

RUN chmod +x /usr/local/bin/keepalived-entrypoint.sh \
    /usr/local/share/keepalived/check_dns.sh \
    /usr/local/share/keepalived/notify_master.sh \
    /usr/local/share/keepalived/notify_backup.sh \
    /usr/local/share/keepalived/notify_fault.sh

VOLUME ["/etc/keepalived"]

ENTRYPOINT ["/usr/local/bin/keepalived-entrypoint.sh"]
