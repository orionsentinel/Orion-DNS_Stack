FROM alpine:3.20

# Install keepalived and dependencies
RUN apk add --no-cache \
    keepalived \
    bash \
    curl \
    iputils \
    bind-tools \
    docker-cli \
    && rm -rf /var/cache/apk/*

# Create directory for keepalived
RUN mkdir -p /etc/keepalived

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Entrypoint processes template and starts keepalived
ENTRYPOINT ["/entrypoint.sh"]
CMD ["keepalived", "--dont-fork", "--log-console", "--log-detail", "--vrrp"]
