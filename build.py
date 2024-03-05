#!/usr/bin/env python3

from subprocess import run
import fire
import json
import sys
import tempfile


def log(s):
    print(f"\033[96m{s}\033[0m")


def _buildx(
    dockerfile,
    image_name,
    tags,  # list of tags, e.g. ["tag1", "tag2"]
    target="",
    build_args="",
    push=True,
    write_to_docker=False,
    cwd=".",
):
    if target:
        target = f"--target {target}"

    with tempfile.NamedTemporaryFile() as fp:
        fp.close()
        metadata_file = fp.name
        if push:
            output = f"type=image,name={image_name},push-by-digest=true,name-canonical=true,push=true"
        else:
            output = (
                f"type=image,name={image_name},name-canonical=true,push=false"
            )
        # build and push digest
        cmd = f"""
        docker buildx build \
            --file {dockerfile} \
            {target} {build_args} \
            --output {output} \
            --metadata-file {metadata_file} .
        """.strip()
        log(f"-> run: {cmd}")
        run(cmd, shell=True, cwd=cwd, check=True)
        digest = json.load(open(metadata_file))["containerimage.digest"]

    log(f"-> {image_name} digest: {digest}")

    # [Optional] writes to local image store, so it will appear in `docker images`
    if write_to_docker:
        for tag in tags:
            cmd = f"""
            docker buildx build \
                --file {dockerfile} {target} {build_args} \
                --output type=docker,name={image_name}:{tag} .
            """.strip()
            log(f"-> run: {cmd}")
            run(cmd, shell=True, cwd=cwd, check=True)

    if push:
        # Push tag from digests
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
        tag_param = " ".join(f"--tag {image_name}:{tag}" for tag in tags)
        cmd = (
            f"docker buildx imagetools create {tag_param} {image_name}@{digest}"
        )
        log(f"-> run: {cmd}")
        run(cmd, shell=True, cwd=cwd)


# TODO
def setup():
    # git clone --recurse-submodules https://github.com/hstreamdb/LogDevice.git
    # git clone --recurse-submodules https://github.com/hstreamdb/docker-haskell.git
    # git clone --recurse-submodules https://github.com/hstreamdb/hstream.git
    # cd $LD_DIR && git checkout -b stable origin/stable

    # XXX: Required for push-by-digest feature
    #
    # NOTE: Cannot use a local image to FROM when using docker-container
    # builder, so we need to push the image to a registry.
    #
    # - https://github.com/docker/buildx/issues/1453
    # - https://github.com/moby/buildkit/issues/2343
    #
    # cmd = "docker buildx create --use --name build --node build --driver-opt network=host"
    print("TODO")


def logdevice_builder(
    ld_dir="./LogDevice", no_push=False, no_write_to_docker=False
):
    # FIXME: also update submodules?
    run("git checkout stable", shell=True, cwd=ld_dir)
    _buildx(
        "docker/Dockerfile.builder",
        "hstreamdb/logdevice-builder",
        ["latest"],
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=ld_dir,
    )


def logdevice(ld_dir="./LogDevice", no_push=False, no_write_to_docker=False):
    # FIXME: also update submodules?
    run("git checkout stable", shell=True, cwd=ld_dir)
    _buildx(
        "docker/Dockerfile",
        "hstreamdb/logdevice",
        ["latest"],
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=ld_dir,
    )
    _buildx(
        "docker/Dockerfile",
        "hstreamdb/logdevice-client",
        ["latest"],
        target="client",
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=ld_dir,
    )


def logdevice_builder_rqlite(
    ld_dir="./LogDevice", no_push=False, no_write_to_docker=False
):
    # FIXME: also update submodules?
    run("git checkout main", shell=True, cwd=ld_dir)
    _buildx(
        "docker/Dockerfile.builder",
        "hstreamdb/logdevice-builder",
        ["rqlite"],
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=ld_dir,
    )


def logdevice_rqlite(
    ld_dir="./LogDevice", no_push=False, no_write_to_docker=False
):
    # FIXME: also update submodules?
    run("git checkout main", shell=True, cwd=ld_dir)
    _buildx(
        "docker/Dockerfile",
        "hstreamdb/logdevice",
        ["rqlite"],
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=ld_dir,
    )
    _buildx(
        "docker/Dockerfile",
        "hstreamdb/logdevice-client",
        ["rqlite"],
        target="client",
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=ld_dir,
    )


# TODO
# grpc
# ghc


def hsthrift(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _buildx(
        "dockerfiles/hsthrift",
        "ghcr.io/hstreamdb/hsthrift",
        ["latest"],
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hs_dir,
    )


def hadmin_store(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _buildx(
        "dockerfiles/hadmin_store",
        "ghcr.io/hstreamdb/hadmin-store",
        ["latest"],
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hs_dir,
    )


def haskell810(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _buildx(
        "Dockerfile",
        "hstreamdb/haskell",
        ["8.10.7", "8.10"],
        build_args="--build-arg GHC=8.10.7 --build-arg LD_CLIENT_IMAGE=hstreamdb/logdevice-client",
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hs_dir,
    )


def haskell810_rqlite(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _buildx(
        "Dockerfile",
        "hstreamdb/haskell",
        ["rqlite_8.10.7", "rqlite_8.10"],
        build_args="--build-arg GHC=8.10.7 --build-arg LD_CLIENT_IMAGE=hstreamdb/logdevice-client:rqlite",
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hs_dir,
    )


def haskell904(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _buildx(
        "Dockerfile",
        "hstreamdb/haskell",
        ["9.4.8", "9.4", "latest"],
        build_args="--build-arg GHC=9.4.8 --build-arg LD_CLIENT_IMAGE=hstreamdb/logdevice-client",
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hs_dir,
    )


def haskell904_rqlite(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _buildx(
        "Dockerfile",
        "hstreamdb/haskell",
        ["rqlite_9.4.8", "rqlite_9.4", "rqlite"],
        build_args="--build-arg GHC=9.4.8 --build-arg LD_CLIENT_IMAGE=hstreamdb/logdevice-client:rqlite",
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hs_dir,
    )


def haskell(hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False):
    haskell810(
        hs_dir=hs_dir, no_push=no_push, no_write_to_docker=no_write_to_docker
    )
    haskell810_rqlite(
        hs_dir=hs_dir, no_push=no_push, no_write_to_docker=no_write_to_docker
    )
    haskell904(
        hs_dir=hs_dir, no_push=no_push, no_write_to_docker=no_write_to_docker
    )
    haskell904_rqlite(
        hs_dir=hs_dir, no_push=no_push, no_write_to_docker=no_write_to_docker
    )


# TODO
# hstream


if __name__ == "__main__":
    if "-h" in sys.argv or "--help" in sys.argv:
        sys.stdout = open("/dev/null", "w")

    fns = [
        setup,
        logdevice_builder,
        logdevice,
        logdevice_builder_rqlite,
        logdevice_rqlite,
        # TODO: grpc, ghc
        hsthrift,
        hadmin_store,
        haskell810,
        haskell810_rqlite,
        haskell904,
        haskell904_rqlite,
        haskell,
        # TODO: hstream
    ]
    fire.Fire({fn.__name__: fn for fn in fns})
