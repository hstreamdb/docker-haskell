#!/bin/bash
set -ex

# x86_64, aarch64
ARCH=$(uname -m)
SUPPORT_ARCH="x86_64 aarch64"

LD_DIR="${LD_DIR:-./LogDevice}"
HS_DIR="${HS_DIR:-./docker-haskell}"
HSTREAM_DIR="${HSTREAM_DIR:-./hstream}"
DOCKER_BIN="${DOCKER_BIN:-docker}"      # e.g. set to podman

# -----------------------------------------------------------------------------

_gen_tag() {
    tag="$1"
    arch="$2"
    if [ -z "$tag" ] || [ "$tag" = "latest" ]; then
        echo "$arch"
    else
        echo "${tag}_$arch"
    fi
}

_tag() {
    image="$1"
    old_tag="$2"
    new_tag="$3"
    for arch in $SUPPORT_ARCH; do
        old_tag_=$(_gen_tag $old_tag $arch)
        new_tag_=$(_gen_tag $new_tag $arch)

        $DOCKER_BIN pull $image:$old_tag_
        $DOCKER_BIN tag $image:$old_tag_ $image:$new_tag_
        $DOCKER_BIN push $image:$new_tag_
    done
}

_push_manifest() {
    image="$1"
    tag="$2"

    [ -z "$image" ] && echo "No image!" && exit 1;

    tag_x86="${tag}_x86_64"
    tag_arm="${tag}_aarch64"
    if [ -z "$tag" ] || [ "$tag" = "latest" ]; then
        tag="latest"
        tag_x86="x86_64"
        tag_arm="aarch64"
    fi
    $DOCKER_BIN manifest rm $image:$tag || true
    manifests="$image:${tag_x86}"
    [ "$(docker pull $image:${tag_arm})" ] && \
        manifests="$manifests $image:${tag_arm}" || true
    $DOCKER_BIN manifest create $image:$tag $manifests
    $DOCKER_BIN manifest push $image:$tag
}

_buildx() {
    dockerfile="$1"
    image_name="$2"
    target="$3"
    tag="$4"
    test -n "$target" && target="--target $target"
    metadata_file=$(mktemp)

    # build and push digest
    docker buildx build \
        --file $dockerfile \
        $target \
        --output type=image,name=$image_name,push-by-digest=true,name-canonical=true,push=true \
        --metadata-file $metadata_file \
        .
    digest=$(python3 -c "import json; d = json.load(open('$metadata_file')); print(d['containerimage.digest'])")

    # writes to local image store, so it will appear in `docker images`
    docker buildx build \
        --file $dockerfile $target \
        --output type=docker,name=$image_name:$tag .

    # create tag from digests
    #
    # TODO: update digest for the architecture
    #
    # manifests=$(docker buildx imagetools inspect --raw $image_name)
    # parse_manifests="import json; d = $manifests; \
    # print(d['manifests']) \
    # for m in d['manifests']
    #   if m['platform']['architecture'] == ...
    # "
    # x=$(python3 -c "$parse_manifests")
    docker buildx imagetools create \
        --tag $image_name:$tag \
        $image_name@$digest
}

# -----------------------------------------------------------------------------

setup() {
    git clone --recurse-submodules https://github.com/hstreamdb/LogDevice.git
    git clone --recurse-submodules https://github.com/hstreamdb/docker-haskell.git
    git clone --recurse-submodules https://github.com/hstreamdb/hstream.git
    cd $LD_DIR && git checkout -b stable origin/stable

    # XXX: Required for push-by-digest feature
    #docker buildx create --use --name build --node build --driver-opt network=host
}

# -----------------------------------------------------------------------------

logdevice_builder() {
    cd $LD_DIR
    git checkout stable
    _buildx "docker/Dockerfile.builder" "hstreamdb/logdevice-builder" "" "latest"
}

logdevice() {
    cd $LD_DIR
    git checkout stable

    _buildx "docker/Dockerfile" "hstreamdb/logdevice" "" "latest"
    _buildx "docker/Dockerfile" "hstreamdb/logdevice-client" "client" "latest"
}

logdevice_builder_rqlite() {
    cd $LD_DIR
    git checkout main
    _buildx "docker/Dockerfile.builder" "hstreamdb/logdevice-builder" "" "rqlite"
}

logdevice_rqlite() {
    cd $LD_DIR
    git checkout main

    _buildx "docker/Dockerfile" "hstreamdb/logdevice" "" "rqlite"
    _buildx "docker/Dockerfile" "hstreamdb/logdevice-client" "client" "rqlite"
}

# TODO
# grpc
# ghc

hsthrift() {
    cd $HS_DIR
    _buildx "dockerfiles/hsthrift" "ghcr.io/hstreamdb/hsthrift" "" "latest"
}

# -----------------------------------------------------------------------------
# Outdated
#
# TODO: use buildx instead

build_logdevice_builder() {
    cd $LD_DIR
    git checkout stable
    $DOCKER_BIN build . -f docker/Dockerfile.builder --tag hstreamdb/logdevice-builder:$ARCH
}

push_logdevice_builder() {
    $DOCKER_BIN push hstreamdb/logdevice-builder:$ARCH
}

push_logdevice_builder_manifest() {
    $DOCKER_BIN manifest rm hstreamdb/logdevice-builder || true
    $DOCKER_BIN manifest create hstreamdb/logdevice-builder \
        hstreamdb/logdevice-builder:x86_64 \
        hstreamdb/logdevice-builder:aarch64
    $DOCKER_BIN manifest push hstreamdb/logdevice-builder
}

tag_logdevice_builder() {
    old_tag="latest"
    new_tag="v3.3.0"
    _tag hstreamdb/logdevice-builder $old_tag $new_tag
    _push_manifest "hstreamdb/logdevice-builder" "$new_tag"
}

build_logdevice() {
    cd $LD_DIR
    git checkout stable
    $DOCKER_BIN build . -f docker/Dockerfile --tag hstreamdb/logdevice:$ARCH
    $DOCKER_BIN build . -f docker/Dockerfile --tag hstreamdb/logdevice-client:$ARCH --target client
}

push_logdevice() {
    $DOCKER_BIN push hstreamdb/logdevice:$ARCH
    $DOCKER_BIN push hstreamdb/logdevice-client:$ARCH
}

push_logdevice_manifest() {
    $DOCKER_BIN manifest rm hstreamdb/logdevice || true
    $DOCKER_BIN manifest rm hstreamdb/logdevice-client || true

    $DOCKER_BIN manifest create hstreamdb/logdevice \
        hstreamdb/logdevice:x86_64 \
        hstreamdb/logdevice:aarch64
    $DOCKER_BIN manifest push hstreamdb/logdevice

    $DOCKER_BIN manifest create hstreamdb/logdevice-client \
        hstreamdb/logdevice-client:x86_64 \
        hstreamdb/logdevice-client:aarch64
    $DOCKER_BIN manifest push hstreamdb/logdevice-client
}

tag_logdevice() {
    old_tag="latest"
    new_tag="v3.3.0"
    _tag hstreamdb/logdevice $old_tag $new_tag
    _push_manifest hstreamdb/logdevice $new_tag

    _tag hstreamdb/logdevice-client $old_tag $new_tag
    _push_manifest hstreamdb/logdevice-client $new_tag
}

# -----------------------------------------------------------------------------

build_logdevice_builder_rq() {
    cd $LD_DIR
    git checkout main
    $DOCKER_BIN build . -f docker/Dockerfile.builder --tag hstreamdb/logdevice-builder:rqlite_$ARCH
}

push_logdevice_builder_rq() {
    $DOCKER_BIN push hstreamdb/logdevice-builder:rqlite_$ARCH
}

push_logdevice_builder_manifest_rq() {
    $DOCKER_BIN manifest rm hstreamdb/logdevice-builder:rqlite || true
    $DOCKER_BIN manifest create hstreamdb/logdevice-builder:rqlite \
        hstreamdb/logdevice-builder:rqlite_x86_64 \
        hstreamdb/logdevice-builder:rqlite_aarch64
    $DOCKER_BIN manifest push hstreamdb/logdevice-builder:rqlite
}

build_logdevice_rq() {
    cd $LD_DIR
    git checkout main
    $DOCKER_BIN build . -f docker/Dockerfile --tag hstreamdb/logdevice:rqlite_$ARCH
    $DOCKER_BIN build . -f docker/Dockerfile --tag hstreamdb/logdevice-client:rqlite_$ARCH --target client
}

push_logdevice_rq() {
    $DOCKER_BIN push hstreamdb/logdevice:rqlite_$ARCH
    $DOCKER_BIN push hstreamdb/logdevice-client:rqlite_$ARCH
}

push_logdevice_manifest_rq() {
    _push_manifest "hstreamdb/logdevice" "rqlite"
    _push_manifest "hstreamdb/logdevice-client" "rqlite"
}

# -----------------------------------------------------------------------------

GRPC=${GRPC:-1.54.2}

build_grpc() {
    cd $HS_DIR
    $DOCKER_BIN build . -f dockerfiles/grpc \
        --build-arg GRPC=v${GRPC} \
        -t ghcr.io/hstreamdb/grpc:${GRPC}_$ARCH
}

push_grpc() {
    $DOCKER_BIN push ghcr.io/hstreamdb/grpc:${GRPC}_$ARCH
}

push_grpc_manifest() {
    _push_manifest ghcr.io/hstreamdb/grpc "$GRPC"
}

# -----------------------------------------------------------------------------

_build_ghc() {
    cd $HS_DIR
    build_ghc="$1"  # e.g. 9.2.8
    tag="$2"  # e.g. 9.2.8
    tag1="$3" # e.g. 9.2
    $DOCKER_BIN build . -f dockerfiles/ghc_from_haskell \
        --build-arg GHC=$build_ghc \
        -t ghcr.io/hstreamdb/ghc:${tag}_$ARCH \
        -t ghcr.io/hstreamdb/ghc:${tag1}_$ARCH
}

_push_ghc() {
    tag="$1"  # e.g. 9.2.8
    tag1="$2" # e.g. 9.2
    $DOCKER_BIN push ghcr.io/hstreamdb/ghc:${tag}_$ARCH
    $DOCKER_BIN push ghcr.io/hstreamdb/ghc:${tag1}_$ARCH
}

_push_ghc_latest_manifest() {
    tag="$1"  # e.g. 9.2.8
    $DOCKER_BIN manifest rm ghcr.io/hstreamdb/ghc || true

    $DOCKER_BIN manifest create ghcr.io/hstreamdb/ghc \
        ghcr.io/hstreamdb/ghc:${tag}_x86_64 \
        ghcr.io/hstreamdb/ghc:${tag}_aarch64

    $DOCKER_BIN manifest push ghcr.io/hstreamdb/ghc
}

build_ghc810() {
    _build_ghc 8.10.7 8.10.7 8.10
}
build_ghc902() {
    _build_ghc 9.2.8 9.2.8 9.2
}
build_ghc904() {
    _build_ghc 9.4.8 9.4.8 9.4
}

push_ghc810() {
    _push_ghc 8.10.7 8.10
}
push_ghc902() {
    _push_ghc 9.2.8 9.2
}
push_ghc904() {
    _push_ghc 9.4.8 9.4
}

push_ghc810_manifest() {
    _push_manifest ghcr.io/hstreamdb/ghc 8.10.7
    _push_manifest ghcr.io/hstreamdb/ghc 8.10
}
push_ghc902_manifest() {
    _push_manifest ghcr.io/hstreamdb/ghc 9.2.8
    _push_manifest ghcr.io/hstreamdb/ghc 9.2
}
push_ghc904_manifest() {
    _push_manifest ghcr.io/hstreamdb/ghc 9.4.8
    _push_manifest ghcr.io/hstreamdb/ghc 9.4
}

push_ghc_latest_manifest() {
    ghc=${@:2}
    if [ -z "$ghc" ]; then
        echo "Empty ghc"
        exit 1
    else
        _push_ghc_latest_manifest $ghc
    fi
}

# -----------------------------------------------------------------------------

build_hsthrift() {
    cd $HS_DIR
    $DOCKER_BIN build . -f dockerfiles/hsthrift -t ghcr.io/hstreamdb/hsthrift:$ARCH
}

push_hsthrift() {
    $DOCKER_BIN push ghcr.io/hstreamdb/hsthrift:$ARCH
}

push_hsthrift_manifest() {
    $DOCKER_BIN manifest rm ghcr.io/hstreamdb/hsthrift || true
    $DOCKER_BIN manifest create ghcr.io/hstreamdb/hsthrift \
        ghcr.io/hstreamdb/hsthrift:x86_64 \
        ghcr.io/hstreamdb/hsthrift:aarch64
    $DOCKER_BIN manifest push ghcr.io/hstreamdb/hsthrift
}

# -----------------------------------------------------------------------------

build_hadmin_store() {
    cd $HS_DIR
    $DOCKER_BIN build . -f dockerfiles/hadmin_store -t ghcr.io/hstreamdb/hadmin-store:$ARCH
}

push_hadmin_store() {
    $DOCKER_BIN push ghcr.io/hstreamdb/hadmin-store:$ARCH
}

push_hadmin_store_manifest() {
    _push_manifest ghcr.io/hstreamdb/hadmin-store
}

# -----------------------------------------------------------------------------

_build_haskell() {
    cd $HS_DIR
    ghc="$1"
    ld_client="$2"
    tag="$3"
    tag1="$4"
    $DOCKER_BIN build . -f Dockerfile \
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
    _build_haskell 9.4.8 hstreamdb/logdevice-client 9.4.8 9.4
}

build_haskell810_rq() {
    _build_haskell 8.10.7 hstreamdb/logdevice-client:rqlite "rqlite_8.10.7" "rqlite_8.10"
}
build_haskell902_rq() {
    _build_haskell 9.2.8 hstreamdb/logdevice-client:rqlite "rqlite_9.2.8" "rqlite_9.2"
}
build_haskell904_rq() {
    _build_haskell 9.4.8 hstreamdb/logdevice-client:rqlite "rqlite_9.4.8" "rqlite_9.4"
}

_push_haskell() {
    tag="$1"
    tag1="$2"
    $DOCKER_BIN push hstreamdb/haskell:${tag}_$ARCH
    $DOCKER_BIN push hstreamdb/haskell:${tag1}_$ARCH
}

push_haskell810() {
    _push_haskell 8.10.7 8.10
}
push_haskell902() {
    _push_haskell 9.2.8 9.2
}
push_haskell904() {
    _push_haskell 9.4.8 9.4
}
push_haskell810_rq() {
    _push_haskell "rqlite_8.10.7" "rqlite_8.10"
}
push_haskell902_rq() {
    _push_haskell "rqlite_9.2.8" "rqlite_9.2"
}
push_haskell904_rq() {
    _push_haskell "rqlite_9.4.8" "rqlite_9.4"
}

_push_haskell_manifest(){
    image="hstreamdb/haskell"
    tag="$1"
    tag1="$2"
    $DOCKER_BIN manifest rm $image:$tag || true
    $DOCKER_BIN manifest create $image:$tag \
        $image:${tag}_x86_64 \
        $image:${tag}_aarch64
    $DOCKER_BIN manifest push $image:$tag

    $DOCKER_BIN manifest rm $image:$tag1 || true
    $DOCKER_BIN manifest create $image:$tag1 \
        $image:${tag1}_x86_64 \
        $image:${tag1}_aarch64
    $DOCKER_BIN manifest push $image:$tag1
}

push_haskell810_manifest() {
    _push_manifest hstreamdb/haskell 8.10.7
    _push_manifest hstreamdb/haskell 8.10
}
push_haskell902_manifest() {
    _push_manifest hstreamdb/haskell 9.2.8
    _push_manifest hstreamdb/haskell 9.2
}
push_haskell904_manifest() {
    _push_manifest hstreamdb/haskell 9.4.8
    _push_manifest hstreamdb/haskell 9.4
}

push_haskell810_manifest_rq() {
    _push_manifest hstreamdb/haskell "rqlite_8.10.7"
    _push_manifest hstreamdb/haskell "rqlite_8.10"
}
push_haskell902_manifest_rq() {
    _push_manifest hstreamdb/haskell "rqlite_9.2.8"
    _push_manifest hstreamdb/haskell "rqlite_9.2"
}
push_haskell904_manifest_rq() {
    _push_manifest hstreamdb/haskell "rqlite_9.4.8"
    _push_manifest hstreamdb/haskell "rqlite_9.4"
}

_push_haskell_latest_manifest() {
    image="hstreamdb/haskell"
    tag="$1"
    ghc="$2"

    $DOCKER_BIN manifest rm $image:$tag || true
    $DOCKER_BIN manifest create $image:$tag \
        $image:${ghc}_x86_64 \
        $image:${ghc}_aarch64
    $DOCKER_BIN manifest push $image:$tag
}

push_haskell_latest_manifest() {
    ghc=${@:2}
    if [ -z "$ghc" ]; then
        echo "Empty ghc"
        exit 1
    else
        _push_haskell_latest_manifest latest $ghc
    fi
}
push_haskell_latest_manifest_rq() {
    ghc=${@:2}
    if [ -z "$ghc" ]; then
        echo "Empty ghc"
        exit 1
    else
        _push_haskell_latest_manifest rqlite "rqlite_$ghc"
    fi
}

# -----------------------------------------------------------------------------

HSTREAM_TAG="v0.16.0"

_build_hstream() {
    cd $HSTREAM_DIR
    hs_image="$1"
    ld_image="$2"
    image="$3"
    tag="$4"
    target="$5"
    git_tag="$(git describe --tag --abbrev=0)"
    git_commit="$(git rev-parse HEAD)"
    # TODO: divede to x86_64 and aarch64
    if [ "$ARCH" = "x86_64" ]; then
        build_cache="cache"
    else
        build_cache="no_cache"
    fi
    if [ -n "$target" ]; then
        target_arg="--target $target"
    else
        target_arg=""
    fi
    $DOCKER_BIN build . -f docker/Dockerfile \
        --build-arg HS_IMAGE=$hs_image \
        --build-arg LD_IMAGE=$ld_image \
        --build-arg BUILD_CACHE=$build_cache \
        --build-arg HSTREAM_VERSION=$git_tag \
        --build-arg HSTREAM_VERSION_COMMIT=$git_commit \
        $target_arg \
        -t $image:$tag
}

rebuild_hstream_builder() {
    cd $HSTREAM_DIR
    hs_image="hstreamdb/haskell:9.2"
    ld_image="hstreamdb/logdevice:latest"
    git_tag="$(git describe --tag --abbrev=0)"
    git_commit="$(git rev-parse HEAD)"
    $DOCKER_BIN build . -f docker/Dockerfile \
        --build-arg HS_IMAGE=$hs_image \
        --build-arg LD_IMAGE=$ld_image \
        --build-arg BUILD_CACHE="no_cache" \
        --build-arg HSTREAM_VERSION=$git_tag \
        --build-arg HSTREAM_VERSION_COMMIT=$git_commit \
        --target builder \
        -t hstreamdb/hstream-builder
}

build_hstream() {
    _build_hstream "hstreamdb/haskell:9.2" "hstreamdb/logdevice:latest" \
       "hstreamdb/hstream" "${HSTREAM_TAG}_$ARCH" ""
}

build_hstream_rq() {
    _build_hstream "hstreamdb/haskell:rqlite_9.2" "hstreamdb/logdevice:rqlite" \
       "hstreamdb/hstream" "rqlite_${HSTREAM_TAG}_$ARCH" ""
}

push_hstream() {
    $DOCKER_BIN push hstreamdb/hstream:${HSTREAM_TAG}_$ARCH
}

push_hstream_rq() {
    $DOCKER_BIN push hstreamdb/hstream:rqlite_${HSTREAM_TAG}_$ARCH
}

_pre_push_hstream() {
    tag="$1"
    $DOCKER_BIN pull hstreamdb/hstream:$tag
    $DOCKER_BIN tag hstreamdb/hstream:$tag hstreamdb/hstream:${tag}_x86_64
    $DOCKER_BIN push hstreamdb/hstream:${tag}_x86_64
}
pre_push_hstream() {
    if [ "$ARCH" = "x86_64" ]; then
        _pre_push_hstream "$HSTREAM_TAG"
        _pre_push_hstream "rqlite_$HSTREAM_TAG"
    else
        echo "Only for x86_64!"
        exit 1
    fi
}

push_hstream_tag_manifest() {
    _push_manifest "hstreamdb/hstream" "$HSTREAM_TAG"
    _push_manifest "hstreamdb/hstream" "rqlite_$HSTREAM_TAG"
}

# -----------------------------------------------------------------------------

[ "$1" ] && $1 $@
