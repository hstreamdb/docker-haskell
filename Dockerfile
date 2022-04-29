# ------------------------------------------------------------------------------
# Install haskell toolkit with extra shared libraries used by hstreamdb.
#
# See also: https://github.com/haskell/docker-haskell/
# ------------------------------------------------------------------------------

ARG GHC=8.10.4
FROM ghcr.io/hstreamdb/ghc:${GHC}

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        vim \
        bash-completion \
        golang-1.16-go \
        libstatgrab-dev && \
    ln -s /usr/lib/go-1.16/bin/go /usr/bin/go && \
    ln -s /usr/lib/go-1.16/bin/gofmt /usr/bin/gofmt && \
    grep -wq '^source /etc/profile.d/bash_completion.sh' /etc/bash.bashrc \
        || echo 'source /etc/profile.d/bash_completion.sh' >> /etc/bash.bashrc && \
    rm -rf /var/lib/apt/lists/* && \
    echo "root:toor" | chpasswd

ENV PATH /root/.cabal/bin:/root/.local/bin:/usr/local/bin:/opt/cabal/bin:/opt/ghc/bin:$PATH
ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# ------------------------------------------------------------------------------
# Install grpc-dev library

COPY --from=ghcr.io/hstreamdb/grpc:1.35.0 /usr/local/include/ /usr/local/include/
COPY --from=ghcr.io/hstreamdb/grpc:1.35.0 /usr/local/bin/ /usr/local/bin/
COPY --from=ghcr.io/hstreamdb/grpc:1.35.0 /usr/local/lib/ /usr/local/lib/

# ------------------------------------------------------------------------------
# Install LogDevice client

COPY requirements/ /tmp/requirements/
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
      $(cat /tmp/requirements/ubuntu-focal.txt) && \
    rm -rf /tmp/requirements && rm -rf /var/lib/apt/lists/* && apt-get clean

COPY --from=hstreamdb/logdevice-client:latest /usr/local/lib/ /usr/local/lib/
COPY --from=hstreamdb/logdevice-client:latest /usr/local/include/ /usr/local/include/
COPY --from=hstreamdb/logdevice-client:latest /usr/lib/libjemalloc.so.2 /usr/lib/
RUN ln -sr /usr/lib/libjemalloc.so.2 /usr/lib/libjemalloc.so && \
    [ -f "/usr/local/include/thrift/lib/thrift/gen-cpp2/RpcMetadata_types.h" ] &&  \
    # temporary fix of "cabal build --enable-profiling" \
    sed -i '/^#pragma once/a #ifdef PROFILING\n#undef PROFILING\n#endif' /usr/local/include/thrift/lib/thrift/gen-cpp2/RpcMetadata_types.h

COPY --from=hstreamdb/logdevice-client:latest /usr/local/bin/thrift1 /usr/local/bin/

# ------------------------------------------------------------------------------
# Install fbthrift

COPY --from=ghcr.io/hstreamdb/hsthrift:latest \
    /usr/local/bin/thrift-compiler \
    /usr/local/bin/thrift-compiler

ENV LANG C.UTF-8
CMD ["ghci"]

# vim: set ft=dockerfile:
