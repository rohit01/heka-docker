FROM ubuntu:16.04
MAINTAINER Rohit Gupta <hello@rohit.io>

# Install from master (default)
ENV     HEKA_BINARY_URL="https://github.com/mozilla-services/heka/releases/download/v0.10.0/heka_0.10.0_amd64.deb"
ENV     HEKA_CONF="config.toml"

# Install build dependencies
RUN     apt-get update && \
            apt-get -y upgrade && \
            apt-get install -y wget && \
            wget "${HEKA_BINARY_URL}" -O /tmp/heka.deb && \
            dpkg -i /tmp/heka.deb && \
            apt-get clean && \
            rm -f /tmp/heka.deb && \
            mkdir -p /heka/etc /heka/log

# Copy configuration
COPY    etc /heka/etc
COPY    lua_custom /usr/share/heka/lua_custom
COPY    run.sh /heka/run.sh

# Execute
WORKDIR /heka
CMD     exec /heka/run.sh
