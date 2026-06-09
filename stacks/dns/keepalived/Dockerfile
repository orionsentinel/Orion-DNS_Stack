FROM alpine:3.20

# Install keepalived and other required packages
RUN apk add --no-cache \
    keepalived \
    iputils \
    iproute2 \
    bash \
    bind-tools \
    curl \
    docker-cli

# Create keepalived config directory
RUN mkdir -p /etc/keepalived

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY check_dns.sh /etc/keepalived/check_dns.sh
COPY notify_master.sh /etc/keepalived/notify_master.sh
COPY notify_backup.sh /etc/keepalived/notify_backup.sh
COPY notify_fault.sh /etc/keepalived/notify_fault.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh \
    /etc/keepalived/check_dns.sh \
    /etc/keepalived/notify_master.sh \
    /etc/keepalived/notify_backup.sh \
    /etc/keepalived/notify_fault.sh

# Expose VRRP protocol
EXPOSE 112/udp

# Run entrypoint script which generates config and starts keepalived
ENTRYPOINT ["/entrypoint.sh"]
