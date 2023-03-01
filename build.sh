#!/bin/bash
set -e

# x86_64, aarch64
ARCH=$(uname -m)
LD_DIR="./LogDevice"
HS_DIR="./docker-haskell"

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

build_ghc() {
    cd $HS_DIR
    docker build . -f dockerfiles/ghc_from_haskell \
        --build-arg GHC=8.10.7 \
        -t ghcr.io/hstreamdb/ghc:8.10.7_$ARCH \
        -t ghcr.io/hstreamdb/ghc:8.10_$ARCH

    docker build . -f dockerfiles/ghc_from_haskell \
        --build-arg GHC=9.2.7 \
        -t ghcr.io/hstreamdb/ghc:9.2.7_$ARCH \
        -t ghcr.io/hstreamdb/ghc:9.2_$ARCH

    docker build . -f dockerfiles/ghc_from_haskell \
        --build-arg GHC=9.4.5 \
        -t ghcr.io/hstreamdb/ghc:9.4.5_$ARCH \
        -t ghcr.io/hstreamdb/ghc:9.4_$ARCH
}

push_ghc() {
    docker push ghcr.io/hstreamdb/ghc:8.10.7_$ARCH
    docker push ghcr.io/hstreamdb/ghc:8.10_$ARCH

    docker push ghcr.io/hstreamdb/ghc:9.2.7_$ARCH
    docker push ghcr.io/hstreamdb/ghc:9.2_$ARCH

    docker push ghcr.io/hstreamdb/ghc:9.4.5_$ARCH
    docker push ghcr.io/hstreamdb/ghc:9.4_$ARCH
}

push_ghc_manifest() {
    for x in "8.10.7:8.10" "9.2.7:9.2" "9.4.5:9.4"; do
        tag=$(echo $x | cut -d ":" -f 1)
        tag1=$(echo $x | cut -d ":" -f 2)

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
    done
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

build_haskell() {
    cd $HS_DIR
    for x in "8.10.7:8.10" "9.2.7:9.2" "9.4.5:9.4"; do
        tag=$(echo $x | cut -d ":" -f 1)
        tag1=$(echo $x | cut -d ":" -f 2)

        docker build . -f Dockerfile \
            --build-arg GHC=$tag \
            --build-arg LD_CLIENT_IMAGE=hstreamdb/logdevice-client \
            --tag hstreamdb/haskell:${tag}_$ARCH \
            --tag hstreamdb/haskell:${tag1}_$ARCH
        done
}

push_haskell() {
    for x in "8.10.7:8.10" "9.2.7:9.2" "9.4.5:9.4"; do
        tag=$(echo $x | cut -d ":" -f 1)
        tag1=$(echo $x | cut -d ":" -f 2)

        docker push hstreamdb/haskell:${tag}_$ARCH
        docker push hstreamdb/haskell:${tag1}_$ARCH
    done
}

push_haskell_manifest() {
    image="hstreamdb/haskell"
    for x in "8.10.7:8.10" "9.2.7:9.2" "9.4.5:9.4"; do
        tag=$(echo $x | cut -d ":" -f 1)
        tag1=$(echo $x | cut -d ":" -f 2)

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
    done

    docker manifest rm $image:latest || true
    docker manifest create $image:latest \
        $image:9.2_x86_64 \
        $image:9.2_aarch64
    docker manifest push $image:latest
}

# -----------------------------------------------------------------------------

build_haskell_rq() {
    cd $HS_DIR
    for x in "8.10.7:8.10.7:8.10" "9.2.7:9.2.7:9.2" "9.4.5:9.4.5:9.4"; do
        ghc=$(echo $x | cut -d ":" -f 1)
        tag="rqlite_$(echo $x | cut -d ":" -f 2)"
        tag1="rqlite_$(echo $x | cut -d ":" -f 3)"

        docker build . -f Dockerfile \
            --build-arg GHC=$ghc \
            --build-arg LD_CLIENT_IMAGE=hstreamdb/logdevice-client:rqlite \
            --tag hstreamdb/haskell:${tag}_$ARCH \
            --tag hstreamdb/haskell:${tag1}_$ARCH
    done
}

push_haskell_rq() {
    for x in "8.10.7:8.10" "9.2.7:9.2" "9.4.5:9.4"; do
        tag="rqlite_$(echo $x | cut -d ":" -f 1)"
        tag1="rqlite_$(echo $x | cut -d ":" -f 2)"

        docker push hstreamdb/haskell:${tag}_$ARCH
        docker push hstreamdb/haskell:${tag1}_$ARCH
    done
}

push_haskell_manifest_rq() {
    image="hstreamdb/haskell"
    for x in "8.10.7:8.10" "9.2.7:9.2" "9.4.5:9.4"; do
        tag="rqlite_$(echo $x | cut -d ":" -f 1)"
        tag1="rqlite_$(echo $x | cut -d ":" -f 2)"

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
    done

    docker manifest rm $image:rqlite || true
    docker manifest create $image:rqlite \
        $image:rqlite_9.2_x86_64 \
        $image:rqlite_9.2_aarch64
    docker manifest push $image:rqlite
}
