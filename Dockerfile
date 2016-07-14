FROM golang:1.6.2-alpine
MAINTAINER Rohit Gupta <hello@rohit.io>

# Install from master (default)
ENV     HEKA_VERSION="master"

# Install build dependencies
RUN     apk add --update build-base curl git mercurial ca-certificates cmake perl

# Install Heka
RUN     mkdir -p ${GOPATH}/src/github.com/mozilla-services/ && \
            cd ${GOPATH}/src/github.com/mozilla-services/ && \
            git clone https://github.com/mozilla-services/heka.git -b ${HEKA_VERSION} && \
            cd ${GOPATH}/src/github.com/mozilla-services/heka && \
            source build.sh && \
            mkdir /heka && \
            mkdir /heka/etc && \
            mkdir /heka/log && \
            cp -r /go/src/github.com/mozilla-services/heka/build/heka/* /heka/ && \
            for i in decoders encoders filters modules; do \
                mkdir -p /heka/lua_${i} && \
                cp /go/src/github.com/mozilla-services/heka/sandbox/lua/${i}/* /heka/lua_${i}; \
            done && \
            cp /go/src/github.com/mozilla-services/heka/sandbox/lua/modules/* /heka/lua_modules && \
            cp -r /go/src/github.com/mozilla-services/heka/dasher /heka/ && \
            go clean -i -r && \
            apk del --purge build-base go git mercurial cmake perl && \
            rm -rf ${GOPATH} /tmp/* /var/cache/apk/* /root/.n*

# Copy configuration
COPY    etc /heka/etc/
COPY    run.sh /heka/run.sh

WORKDIR /heka
ENV     HEKA_CONF="config.toml"

# Execute
CMD     exec /heka/run.sh
