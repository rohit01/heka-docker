FROM ubuntu:16.04
MAINTAINER Rohit Gupta <hello@rohit.io>

# Install from master (default)
ENV     HEKA_BINARY_URL="https://github.com/mozilla-services/heka/releases/download/v0.10.0/heka_0.10.0_amd64.deb"
ENV     HEKA_CONF="config.toml"

# Install build dependencies
RUN     apt-get update && \
            apt-get -y upgrade && \
            apt-get install --no-install-recommends -y wget && \
            wget --no-check-certificate "${HEKA_BINARY_URL}" -O /tmp/heka.deb && \
            dpkg -i /tmp/heka.deb && \
            apt-get clean && \
            rm -f /tmp/heka.deb && \
            mkdir -p /heka/etc /heka/log && \
            apt-get clean && \
            rm -rf /var/lib/apt/lists/*

# Copy configuration
COPY    etc /heka/etc
COPY    lua_custom /usr/share/heka/lua_custom
COPY    run.sh /heka/run.sh

# Execute
WORKDIR /heka
CMD     exec /heka/run.sh
