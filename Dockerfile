# ------------------------------------------------------------------------------
# Install haskell toolkit with extra shared libraries used by hstreamdb.
#
# See also: https://github.com/haskell/docker-haskell/
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Global args (should be on the top of dockerifle)

ARG GHC=8.10.7
ARG LD_CLIENT_IMAGE="hstreamdb/logdevice-client:latest"

# ------------------------------------------------------------------------------

FROM ${LD_CLIENT_IMAGE} as ld_client

FROM ghcr.io/hstreamdb/ghc:${GHC}

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        vim \
        bash-completion \
        python3 \
        gdb \
        golang \
        librdkafka-dev \
        libstatgrab-dev \
        libgsasl7-dev && \
    grep -wq '^source /etc/profile.d/bash_completion.sh' /etc/bash.bashrc \
        || echo 'source /etc/profile.d/bash_completion.sh' >> /etc/bash.bashrc && \
    rm -rf /var/lib/apt/lists/* && \
    echo "root:toor" | chpasswd

ENV PATH /root/.cabal/bin:/root/.local/bin:/usr/local/bin:/opt/cabal/bin:/opt/ghc/bin:$PATH
ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# ------------------------------------------------------------------------------
# Install grpc-dev library

COPY --from=ghcr.io/hstreamdb/grpc:1.54.2 /usr/local/include/ /usr/local/include/
COPY --from=ghcr.io/hstreamdb/grpc:1.54.2 /usr/local/bin/ /usr/local/bin/
COPY --from=ghcr.io/hstreamdb/grpc:1.54.2 /usr/local/lib/ /usr/local/lib/

# ------------------------------------------------------------------------------
# Install LogDevice client

COPY requirements/ /tmp/requirements/
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
      $(cat /tmp/requirements/ubuntu-jammy.txt) && \
    rm -rf /tmp/requirements && rm -rf /var/lib/apt/lists/* && apt-get clean

COPY --from=ld_client /usr/local/lib/ /usr/local/lib/
COPY --from=ld_client /usr/local/include/ /usr/local/include/
COPY --from=ld_client /usr/lib/libjemalloc.so.2 /usr/lib/
RUN ln -sr /usr/lib/libjemalloc.so.2 /usr/lib/libjemalloc.so && \
    [ -f "/usr/local/include/thrift/lib/thrift/gen-cpp2/RpcMetadata_types.h" ] &&  \
    # temporary fix of "cabal build --enable-profiling" \
    sed -i '/^#pragma once/a #ifdef PROFILING\n#undef PROFILING\n#endif' /usr/local/include/thrift/lib/thrift/gen-cpp2/RpcMetadata_types.h

COPY --from=ld_client /usr/local/bin/thrift1 /usr/local/bin/

# ------------------------------------------------------------------------------
# Install fbthrift

COPY --from=ghcr.io/hstreamdb/hsthrift:latest \
    /usr/local/bin/thrift-compiler \
    /usr/local/bin/thrift-compiler

# ------------------------------------------------------------------------------
# FIXME: hadmim-store

COPY --from=ghcr.io/hstreamdb/hadmin-store:latest \
    /usr/local/bin/hadmin-store \
    /usr/local/bin/hadmin-store

RUN mkdir -p /etc/bash_completion.d && \
    grep -wq '^source /etc/profile.d/bash_completion.sh' /etc/bash.bashrc || echo 'source /etc/profile.d/bash_completion.sh' >> /etc/bash.bashrc && \
    /usr/local/bin/hadmin-store --bash-completion-script /usr/local/bin/hadmin-store > /etc/bash_completion.d/hadmin-store

# ------------------------------------------------------------------------------

ENV LANG C.UTF-8
CMD ["ghci"]

# vim: set ft=dockerfile:
