#!/bin/bash
set -e

# x86_64, aarch64
ARCH=$(uname -m)
LD_DIR="${LD_DIR:-./LogDevice}"
HS_DIR="${HS_DIR:-./docker-haskell}"
HSTREAM_DIR="${HSTREAM_DIR:-./hstream}"

setup() {
    git clone --recurse-submodules https://github.com/hstreamdb/LogDevice.git
    git clone --recurse-submodules https://github.com/hstreamdb/docker-haskell.git
    cd $LD_DIR && git checkout -b stable origin/stable
}

# -----------------------------------------------------------------------------

build_logdevice_builder() {
    cd $LD_DIR
    git checkout stable
    docker build . -f docker/Dockerfile.builder --tag hstreamdb/logdevice-builder:$ARCH
}

push_logdevice_builder() {
    docker push hstreamdb/logdevice-builder:$ARCH
}

push_logdevice_builder_manifest() {
    docker manifest rm hstreamdb/logdevice-builder || true
    docker manifest create hstreamdb/logdevice-builder \
        hstreamdb/logdevice-builder:x86_64 \
        hstreamdb/logdevice-builder:aarch64
    docker manifest push hstreamdb/logdevice-builder
}

build_logdevice() {
    cd $LD_DIR
    git checkout stable
    docker build . -f docker/Dockerfile --tag hstreamdb/logdevice:$ARCH
    docker build . -f docker/Dockerfile --tag hstreamdb/logdevice-client:$ARCH --target client
}

push_logdevice() {
    docker push hstreamdb/logdevice:$ARCH
    docker push hstreamdb/logdevice-client:$ARCH
}

push_logdevice_manifest() {
    docker manifest rm hstreamdb/logdevice || true
    docker manifest rm hstreamdb/logdevice-client || true

    docker manifest create hstreamdb/logdevice \
        hstreamdb/logdevice:x86_64 \
        hstreamdb/logdevice:aarch64
    docker manifest push hstreamdb/logdevice

    docker manifest create hstreamdb/logdevice-client \
        hstreamdb/logdevice-client:x86_64 \
        hstreamdb/logdevice-client:aarch64
    docker manifest push hstreamdb/logdevice-client
}

# -----------------------------------------------------------------------------

build_logdevice_builder_rq() {
    cd $LD_DIR
    git checkout main
    docker build . -f docker/Dockerfile.builder --tag hstreamdb/logdevice-builder:rqlite:$ARCH
}

push_logdevice_builder_rq() {
    docker push hstreamdb/logdevice-builder:rqlite_$ARCH
}

push_logdevice_builder_manifest_rq() {
    docker manifest rm hstreamdb/logdevice-builder:rqlite || true
    docker manifest create hstreamdb/logdevice-builder:rqlite \
        hstreamdb/logdevice-builder:rqlite_x86_64 \
        hstreamdb/logdevice-builder:rqlite_aarch64
    docker manifest push hstreamdb/logdevice-builder:rqlite
}

build_logdevice_rq() {
    cd $LD_DIR
    git checkout main
    docker build . -f docker/Dockerfile --tag hstreamdb/logdevice:rqlite_$ARCH
    docker build . -f docker/Dockerfile --tag hstreamdb/logdevice-client:rqlite_$ARCH --target client
}

push_logdevice_rq() {
    docker push hstreamdb/logdevice:rqlite_$ARCH
    docker push hstreamdb/logdevice-client:rqlite_$ARCH
}

push_logdevice_manifest_rq() {
    docker manifest rm hstreamdb/logdevice:rqlite || true
    docker manifest rm hstreamdb/logdevice-client:rqlite || true

    docker manifest create hstreamdb/logdevice:rqlite \
        hstreamdb/logdevice:rqlite_x86_64 \
        hstreamdb/logdevice:rqlite_aarch64
    docker manifest push hstreamdb/logdevice:rqlite

    docker manifest create hstreamdb/logdevice-client:rqlite \
        hstreamdb/logdevice-client:rqlite_x86_64 \
        hstreamdb/logdevice-client:rqlite_aarch64
    docker manifest push hstreamdb/logdevice-client:rqlite
}

# -----------------------------------------------------------------------------

build_grpc() {
    cd $HS_DIR
    docker build . -f dockerfiles/grpc -t ghcr.io/hstreamdb/grpc:1.35.0_$ARCH
}

push_grpc() {
    docker push ghcr.io/hstreamdb/grpc:1.35.0_$ARCH
}

push_grpc_manifest() {
    docker manifest rm ghcr.io/hstreamdb/grpc:1.35.0 || true
    docker manifest create ghcr.io/hstreamdb/grpc:1.35.0 \
        ghcr.io/hstreamdb/grpc:1.35.0_x86_64 \
        ghcr.io/hstreamdb/grpc:1.35.0_aarch64
    docker manifest push ghcr.io/hstreamdb/grpc:1.35.0
}

# -----------------------------------------------------------------------------

_build_ghc() {
    cd $HS_DIR
    build_ghc="$1"  # e.g. 9.2.8
    tag="$2"  # e.g. 9.2.8
    tag1="$3" # e.g. 9.2
    docker build . -f dockerfiles/ghc_from_haskell \
        --build-arg GHC=$build_ghc \
        -t ghcr.io/hstreamdb/ghc:${tag}_$ARCH \
        -t ghcr.io/hstreamdb/ghc:${tag1}_$ARCH
}

_push_ghc() {
    tag="$1"  # e.g. 9.2.8
    tag1="$2" # e.g. 9.2
    docker push ghcr.io/hstreamdb/ghc:${tag}_$ARCH
    docker push ghcr.io/hstreamdb/ghc:${tag1}_$ARCH
}

_push_ghc_manifest() {
    tag="$1"  # e.g. 9.2.8
    tag1="$2" # e.g. 9.2
    docker manifest rm ghcr.io/hstreamdb/ghc:$tag || true
    docker manifest rm ghcr.io/hstreamdb/ghc:$tag1 || true

    docker manifest create ghcr.io/hstreamdb/ghc:$tag \
        ghcr.io/hstreamdb/ghc:${tag}_x86_64 \
        ghcr.io/hstreamdb/ghc:${tag}_aarch64
    docker manifest create ghcr.io/hstreamdb/ghc:$tag1 \
        ghcr.io/hstreamdb/ghc:${tag1}_x86_64 \
        ghcr.io/hstreamdb/ghc:${tag1}_aarch64

    docker manifest push ghcr.io/hstreamdb/ghc:$tag
    docker manifest push ghcr.io/hstreamdb/ghc:$tag1
}

_push_ghc_latest_manifest() {
    tag="$1"  # e.g. 9.2.8
    docker manifest rm ghcr.io/hstreamdb/ghc || true

    docker manifest create ghcr.io/hstreamdb/ghc \
        ghcr.io/hstreamdb/ghc:${tag}_x86_64 \
        ghcr.io/hstreamdb/ghc:${tag}_aarch64

    docker manifest push ghcr.io/hstreamdb/ghc
}

build_ghc810() {
    _build_ghc 8.10.7 8.10.7 8.10
}
build_ghc902() {
    _build_ghc 9.2.8 9.2.8 9.2
}
build_ghc904() {
    _build_ghc 9.4.5 9.4.5 9.4
}

push_ghc810() {
    _push_ghc 8.10.7 8.10
}
push_ghc902() {
    _push_ghc 9.2.8 9.2
}
push_ghc904() {
    _push_ghc 9.4.5 9.4
}

push_ghc810_manifest() {
    _push_ghc_manifest 8.10.7 8.10
}
push_ghc902_manifest() {
    _push_ghc_manifest 9.2.8 9.2
}
push_ghc904_manifest() {
    _push_ghc_manifest 9.4.5 9.4
}

push_ghc_latest_manifest() {
    _push_ghc_latest_manifest 9.2.8
}

# -----------------------------------------------------------------------------

build_hsthrift() {
    cd $HS_DIR
    docker build . -f dockerfiles/hsthrift -t ghcr.io/hstreamdb/hsthrift:$ARCH
}

push_hsthrift() {
    docker push ghcr.io/hstreamdb/hsthrift:$ARCH
}

push_hsthrift_manifest() {
    docker manifest rm ghcr.io/hstreamdb/hsthrift || true
    docker manifest create ghcr.io/hstreamdb/hsthrift \
        ghcr.io/hstreamdb/hsthrift:x86_64 \
        ghcr.io/hstreamdb/hsthrift:aarch64
    docker manifest push ghcr.io/hstreamdb/hsthrift
}

# -----------------------------------------------------------------------------

build_hadmin_store() {
    cd $HS_DIR
    docker build . -f dockerfiles/hadmin_store -t ghcr.io/hstreamdb/hadmin-store:$ARCH
}

push_hadmin_store() {
    docker push ghcr.io/hstreamdb/hadmin-store:$ARCH
}

push_hadmin_store_manifest() {
    docker manifest rm ghcr.io/hstreamdb/hadmin-store || true
    docker manifest create ghcr.io/hstreamdb/hadmin-store \
        ghcr.io/hstreamdb/hadmin-store:x86_64 \
        ghcr.io/hstreamdb/hadmin-store:aarch64
    docker manifest push ghcr.io/hstreamdb/hadmin-store
}

# -----------------------------------------------------------------------------

_build_haskell() {
    cd $HS_DIR
    ghc="$1"
    ld_client="$2"
    tag="$3"
    tag1="$4"
    docker build . -f Dockerfile \
        --build-arg GHC=$ghc \
        --build-arg LD_CLIENT_IMAGE=$ld_client \
        --tag hstreamdb/haskell:${tag}_$ARCH \
        --tag hstreamdb/haskell:${tag1}_$ARCH
}

build_haskell810() {
    _build_haskell 8.10.7 hstreamdb/logdevice-client 8.10.7 8.10
}
build_haskell902() {
    _build_haskell 9.2.8 hstreamdb/logdevice-client 9.2.8 9.2
}
build_haskell904() {
    _build_haskell 9.4.5 hstreamdb/logdevice-client 9.4.5 9.4
}

build_haskell810_rq() {
    _build_haskell 8.10.7 hstreamdb/logdevice-client:rqlite "rqlite_8.10.7" "rqlite_8.10"
}
build_haskell902_rq() {
    _build_haskell 9.2.8 hstreamdb/logdevice-client:rqlite "rqlite_9.2.8" "rqlite_9.2"
}
build_haskell904_rq() {
    _build_haskell 9.4.5 hstreamdb/logdevice-client:rqlite "rqlite_9.4.5" "rqlite_9.4"
}

_push_haskell() {
    tag="$1"
    tag1="$2"
    docker push hstreamdb/haskell:${tag}_$ARCH
    docker push hstreamdb/haskell:${tag1}_$ARCH
}

push_haskell810() {
    _push_haskell 8.10.7 8.10
}
push_haskell902() {
    _push_haskell 9.2.8 9.2
}
push_haskell904() {
    _push_haskell 9.4.5 9.4
}
push_haskell810_rq() {
    _push_haskell "rqlite_8.10.7" "rqlite_8.10"
}
push_haskell902_rq() {
    _push_haskell "rqlite_9.2.8" "rqlite_9.2"
}
push_haskell904_rq() {
    _push_haskell "rqlite_9.4.5" "rqlite_9.4"
}

_push_haskell_manifest(){
    image="hstreamdb/haskell"
    tag="$1"
    tag1="$2"
    docker manifest rm $image:$tag || true
    docker manifest create $image:$tag \
        $image:${tag}_x86_64 \
        $image:${tag}_aarch64
    docker manifest push $image:$tag

    docker manifest rm $image:$tag1 || true
    docker manifest create $image:$tag1 \
        $image:${tag1}_x86_64 \
        $image:${tag1}_aarch64
    docker manifest push $image:$tag1
}

push_haskell810_manifest() {
    _push_haskell_manifest 8.10.7 8.10
}
push_haskell902_manifest() {
    _push_haskell_manifest 9.2.8 9.2
}
push_haskell904_manifest() {
    _push_haskell_manifest 9.4.5 9.4
}

push_haskell810_manifest_rq() {
    _push_haskell_manifest "rqlite_8.10.7" "rqlite_8.10"
}
push_haskell902_manifest_rq() {
    _push_haskell_manifest "rqlite_9.2.8" "rqlite_9.2"
}
push_haskell904_manifest_rq() {
    _push_haskell_manifest "rqlite_9.4.5" "rqlite_9.4"
}

_push_haskell_latest_manifest() {
    image="hstreamdb/haskell"
    tag="$1"
    ghc="$2"

    docker manifest rm $image:$tag || true
    docker manifest create $image:$tag \
        $image:${ghc}_x86_64 \
        $image:${ghc}_aarch64
    docker manifest push $image:$tag
}

push_haskell_latest_manifest() {
    _push_haskell_latest_manifest latest 9.2.8
}
push_haskell_latest_manifest_rq() {
    _push_haskell_latest_manifest rqlite "rqlite_9.2.8"
}

# -----------------------------------------------------------------------------

_build_hstream() {
    cd $HSTREAM_DIR
    builder_image="$1"
    ld_image="$2"
    git_tag="$(git describe --tag --abbrev=0)"
    git_commit="$(git rev-parse HEAD)"
    docker build . -f docker/Dockerfile \
        --build-arg BUILDER_IMAGE=$builder_image \
        --build-arg LD_IMAGE=$ld_image \
        --build-arg HSTREAM_VERSION=$git_tag \
        --build-arg HSTREAM_VERSION_COMMIT=$git_commit \
        -t hstreamdb/hstream:$git_tag
}

build_hstream() {
    _build_hstream "hstreamdb/haskell:9.2" "hstreamdb/logdevice:latest"
}
build_hstream_rq() {
    _build_hstream "hstreamdb/haskell:rqlite_9.2" "hstreamdb/logdevice:rqlite"
}

_pre_push_hstream() {
    tag="$1"
    docker pull hstreamdb/hstream:$tag
    docker tag hstreamdb/hstream:$tag hstreamdb/hstream:${tag}_$ARCH
    docker push hstreamdb/hstream:${tag}_$ARCH
}
pre_push_hstream() {
    _pre_push_hstream "v0.15.2"
    _pre_push_hstream "rqlite_v0.15.2"
}

_push_hstream_manifest() {
    image="hstreamdb/hstream"
    tag="$1"
    docker manifest rm $image:$tag || true
    docker manifest create $image:$tag \
        $image:${tag}_x86_64 \
        $image:${tag}_aarch64
    docker manifest push $image:$tag
}

push_hstream_tag_manifest() {
    _push_hstream_manifest "v0.15.2"
}

# -----------------------------------------------------------------------------

[ "$1" ] && $1
