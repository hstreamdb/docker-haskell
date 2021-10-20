# ------------------------------------------------------------------------------
# Install haskell toolkit with extra shared library used by hstreamdb.
#
# See also: https://github.com/haskell/docker-haskell/
# ------------------------------------------------------------------------------

FROM ubuntu:focal

RUN apt-get update && \
    apt-get install -y --no-install-recommends gnupg ca-certificates dirmngr && \
    rm -rf /var/lib/apt/lists/*

ARG GHC=8.10.4
ARG UBUNTU_KEY=063DAB2BDC0B3F9FCEBC378BFF3AEACEF6F88286
ARG CABAL_INSTALL=3.4

RUN export GNUPGHOME="$(mktemp -d)" && \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys ${UBUNTU_KEY} && \
    gpg --batch --armor --export ${UBUNTU_KEY} > /etc/apt/trusted.gpg.d/haskell.org.gpg.asc && \
    gpgconf --kill all && \
    echo 'deb http://ppa.launchpad.net/hvr/ghc/ubuntu bionic main' > /etc/apt/sources.list.d/ghc.list && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        cabal-install-${CABAL_INSTALL} \
        curl \
        g++ \
        ghc-${GHC} \
        ghc-${GHC}-prof \
        git \
        vim \
        libsqlite3-dev \
        libtinfo-dev \
        make \
        cmake \
        netbase \
        bash-completion \
        openssh-client \
        xz-utils \
        libstatgrab-dev \
        zlib1g-dev && \
    rm -rf "$GNUPGHOME" && rm -rf /var/lib/apt/lists/* && apt-get clean

ENV PATH /root/.cabal/bin:/root/.local/bin:/usr/local/bin:/opt/cabal/bin:/opt/ghc/bin:$PATH
ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# ------------------------------------------------------------------------------
# Install latest cabal

COPY --from=hstreamdb/hsthrift /usr/local/bin/cabal-3.6 /usr/local/bin/cabal-3.6
RUN update-alternatives --install /opt/cabal/bin/cabal opt-cabal /usr/local/bin/cabal-3.6 30401 \
      --slave /opt/ghc/bin/cabal opt-ghc-cabal /usr/local/bin/cabal-3.6 && \
    update-alternatives --set opt-cabal /usr/local/bin/cabal-3.6

# ------------------------------------------------------------------------------
# Install grpc-dev library

COPY --from=hstreamdb/grpc:1.35.0 /usr/local/include/ /usr/local/include/
COPY --from=hstreamdb/grpc:1.35.0 /usr/local/bin/ /usr/local/bin/
COPY --from=hstreamdb/grpc:1.35.0 /usr/local/lib/ /usr/local/lib/

# ------------------------------------------------------------------------------
# Install LogDevice client

COPY requirements/ /tmp/requirements/
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
      $(cat /tmp/requirements/ubuntu-focal.txt) && \
    rm -rf /tmp/requirements && rm -rf /var/lib/apt/lists/* && apt-get clean

COPY --from=hstreamdb/logdevice-client:latest /usr/local/include/ /usr/local/include/
COPY --from=hstreamdb/logdevice-client:latest /usr/local/lib/ /usr/local/lib/
COPY --from=hstreamdb/logdevice-client:latest /usr/lib/libjemalloc.so.2 /usr/lib/
RUN ln -sr /usr/lib/libjemalloc.so.2 /usr/lib/libjemalloc.so

# ------------------------------------------------------------------------------
# Install fbthrift

COPY --from=hstreamdb/logdevice-client:latest /usr/local/bin/thrift1 /usr/local/bin/
COPY --from=hstreamdb/hsthrift:latest /usr/local/bin/thrift-compiler /usr/local/bin/thrift-compiler

# ------------------------------------------------------------------------------
# Install stack

ARG STACK=2.7.1
ARG STACK_KEY=C5705533DA4F78D8664B5DC0575159689BEFB442
ARG STACK_RELEASE_KEY=2C6A674E85EE3FB896AFC9B965101FF31C5C154D

RUN if [ -n "$STACK" ]; then  \
    export GNUPGHOME="$(mktemp -d)" && \
    for key in ${STACK_KEY} ${STACK_RELEASE_KEY}; do \
      gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
      gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
      gpg --batch --keyserver pgp.mit.edu --recv-keys "$key" ; \
    done && \
    curl -fSL https://github.com/commercialhaskell/stack/releases/download/v${STACK}/stack-${STACK}-linux-x86_64.tar.gz -o stack.tar.gz && \
    curl -fSL https://github.com/commercialhaskell/stack/releases/download/v${STACK}/stack-${STACK}-linux-x86_64.tar.gz.asc -o stack.tar.gz.asc && \
    gpg --batch --trusted-key 0x575159689BEFB442 --verify stack.tar.gz.asc stack.tar.gz && \
    tar -xf stack.tar.gz -C /usr/local/bin --strip-components=1 && \
    /usr/local/bin/stack config set system-ghc --global true && \
    /usr/local/bin/stack config set install-ghc --global false && \
    rm -rf "$GNUPGHOME" /var/lib/apt/lists/* /stack.tar.gz.asc /stack.tar.gz ; \
    fi

ENV LANG C.UTF-8
CMD ["ghci"]

# vim: set ft=dockerfile:
