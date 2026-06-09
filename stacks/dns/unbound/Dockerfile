# Unbound DNS Resolver with Smart Prefetch Configuration Support
# Based on ghcr.io/klutchell/unbound with minimal config injection
#
# Features:
# - Conditional smart prefetch configuration via UNBOUND_SMART_PREFETCH env var
# - Full recursive resolution (no third-party DNS providers)
# - DNSSEC validation and privacy hardening
# - Docker HEALTHCHECK using unbound-host for real DNS resolution testing

FROM ghcr.io/klutchell/unbound:1.19.0

# Install bash for entrypoint script (unbound-host is included in base image)
USER root
RUN apk add --no-cache bash

# Copy configuration files
COPY unbound.conf /opt/unbound/etc/unbound/unbound.conf.base
COPY 30-performance-and-privacy.conf /opt/unbound/etc/unbound/30-performance-and-privacy.conf

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER unbound

# Docker HEALTHCHECK: Uses unbound-host to test real DNS resolution
# Tests resolution of a well-known domain through the local Unbound instance
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["unbound-host", "-C", "/opt/unbound/etc/unbound/unbound.conf", "example.com"]

ENTRYPOINT ["/entrypoint.sh"]
