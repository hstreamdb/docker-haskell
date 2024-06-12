#!/usr/bin/env python3

import subprocess
import fire
import json
import os
import sys
import tempfile

SUPPORT_PLATFORMS = ["linux/amd64", "linux/arm64"]


def log(s):
    print(f"\033[96m{s}\033[0m")


def warn(s):
    print(f"\033[93m{s}\033[0m")


def get_current_platform():
    import platform

    system_os = platform.system().lower()
    machine = platform.machine()

    if system_os != "linux":
        warn(f"Warning: runing on a non-linux platform: {system_os}")

    cur_platform = None
    if machine in ["x86_64", "amd64"]:
        # Only linux is supported
        cur_platform = "linux/amd64"
    elif platform.machine() in ["aarch64", "arm64"]:
        # Only linux is supported
        cur_platform = "linux/arm64"

    assert cur_platform in SUPPORT_PLATFORMS
    return cur_platform


def run(cmd, shell=True, check=True, interactive=False, **kw):
    log(f"=> run: {cmd}")
    if interactive:
        choice = input("Contine? Enter for yes, other for Exit. ")
        if choice.strip():
            sys.exit(0)
    return subprocess.run(cmd, shell=shell, check=check, **kw)


def get_git_tag(cwd):
    return (
        run(
            "git describe --tag --abbrev=0",
            stdout=subprocess.PIPE,
            cwd=cwd,
        )
        .stdout.decode()
        .strip()
    )


def get_git_commit(cwd):
    return (
        run(
            "git rev-parse HEAD",
            stdout=subprocess.PIPE,
            cwd=cwd,
        )
        .stdout.decode()
        .strip()
    )


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
    if len(tags) < 1:
        raise ValueError("tags must not be empty")
    current_platform = get_current_platform()

    if target:
        target = f"--target {target}"

    # Build
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
        run(cmd, shell=True, cwd=cwd, check=True)
        digest = json.load(open(metadata_file))["containerimage.digest"]
    log(f"-> [build] {image_name} digest: {digest}")

    # FIXME: merge into the Build step
    # [Optional] writes to local image store, so it will appear in `docker images`
    if write_to_docker:
        for tag in tags:
            cmd = f"""
            docker buildx build \
                --file {dockerfile} {target} {build_args} \
                --output type=docker,name={image_name}:{tag} .
            """.strip()
            run(cmd, shell=True, cwd=cwd, check=True)

    # Push
    info_format = '--format "{{json .Manifest}}"'
    fetch_info_cmd = (
        f"docker buildx imagetools inspect {info_format} {image_name}:{tags[0]}"
    )
    image_info = run(
        fetch_info_cmd,
        shell=True,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if image_info.returncode != 0:
        if "not found" in image_info.stdout.decode():
            exist_manifests = []
        else:
            raise RuntimeError(image_info.stdout.decode())
    else:
        exist_manifests = json.loads(image_info.stdout).get("manifests")
        if not exist_manifests:
            # FIXME: get architecture from exist image(no manifests)
            #
            # for now we assume the exist image is for linux/amd64
            exist_manifests = [
                {
                    "platform": {"os": "linux", "architecture": "amd64"},
                    "digest": exist_manifests["digest"],
                }
            ]
    digests_to_push = set([digest])
    for m in exist_manifests:
        platform = m["platform"]["os"] + "/" + m["platform"]["architecture"]
        if platform in SUPPORT_PLATFORMS and platform != current_platform:
            digests_to_push.add(m["digest"])

    tag_param = " ".join(f"--tag {image_name}:{tag}" for tag in tags)
    digest_param = " ".join(f"{image_name}@{d}" for d in digests_to_push)
    log(f"-> [push] tags: {tag_param}, digests: {digest_param}")
    if push:
        cmd = f"docker buildx imagetools create {tag_param} {digest_param}"
        run(cmd, shell=True, cwd=cwd)


def setup(work_dir=".", use_container_builder=True):
    ld_dir = os.path.join(work_dir, "LogDevice")
    hs_dir = os.path.join(work_dir, "docker-haskell")
    cmd = f"""
    git clone --recurse-submodules https://github.com/hstreamdb/LogDevice.git {ld_dir}
    git clone --recurse-submodules https://github.com/hstreamdb/docker-haskell.git {hs_dir}
    """
    run(cmd, shell=True, check=True)
    run(
        "git checkout -b stable origin/stable",
        shell=True,
        cwd=ld_dir,
        check=True,
    )

    # XXX: Required for push-by-digest feature
    #
    # NOTE: Cannot use a local image to FROM when using docker-container
    # builder, so we need to push the image to a registry.
    #
    # - https://github.com/docker/buildx/issues/1453
    # - https://github.com/moby/buildkit/issues/2343
    if use_container_builder:
        cmd = "docker buildx create --use --name build --node build --driver-opt network=host"
        run(cmd, shell=True, check=True)


def logdevice_builder(
    ld_dir="./LogDevice", no_push=False, no_write_to_docker=False
):
    run(
        "git checkout stable && git submodule update --init --recursive",
        shell=True,
        cwd=ld_dir,
    )
    _buildx(
        "docker/Dockerfile.builder",
        "hstreamdb/logdevice-builder",
        ["latest"],
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=ld_dir,
    )


def logdevice(ld_dir="./LogDevice", no_push=False, no_write_to_docker=False):
    run(
        "git checkout stable && git submodule update --init --recursive",
        shell=True,
        cwd=ld_dir,
    )
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
    run(
        "git checkout main && git submodule update --init --recursive",
        shell=True,
        cwd=ld_dir,
    )
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
    run(
        "git checkout main && git submodule update --init --recursive",
        shell=True,
        cwd=ld_dir,
    )
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


def grpc(
    hs_dir="./docker-haskell",
    no_push=False,
    no_write_to_docker=False,
    version="1.54.2",
):
    _buildx(
        "dockerfiles/grpc",
        "ghcr.io/hstreamdb/grpc",
        [version],
        build_args=f"--build-arg GRPC=v{version}",
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hs_dir,
    )


def _ghc(ghcs, hs_dir, no_push, no_write_to_docker):
    _buildx(
        "dockerfiles/ghc_from_haskell",
        "ghcr.io/hstreamdb/ghc",
        ghcs,
        build_args=f"--build-arg GHC={ghcs[0]}",
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hs_dir,
    )


def ghc810(hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False):
    _ghc(["8.10.7", "8.10"], hs_dir, no_push, no_write_to_docker)


def ghc904(hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False):
    _ghc(["9.4.8", "9.4"], hs_dir, no_push, no_write_to_docker)


def ghc906(hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False):
    _ghc(["9.6.5", "9.6"], hs_dir, no_push, no_write_to_docker)


def ghc(hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False):
    ghc810(
        hs_dir=hs_dir, no_push=no_push, no_write_to_docker=no_write_to_docker
    )
    ghc904(
        hs_dir=hs_dir, no_push=no_push, no_write_to_docker=no_write_to_docker
    )
    ghc906(
        hs_dir=hs_dir, no_push=no_push, no_write_to_docker=no_write_to_docker
    )


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


def _haskell(tags, ghc, ld_image, hs_dir, no_push, no_write_to_docker):
    _buildx(
        "Dockerfile",
        "hstreamdb/haskell",
        tags,
        build_args=f"--build-arg GHC={ghc} --build-arg LD_CLIENT_IMAGE={ld_image}",
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hs_dir,
    )


# Deprecated
def haskell810(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _haskell(
        ["8.10.7", "8.10"],
        "8.10.7",
        "hstreamdb/logdevice-client",
        hs_dir,
        no_push,
        no_write_to_docker,
    )


# Deprecated
def haskell810_rqlite(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _haskell(
        ["rqlite_8.10.7", "rqlite_8.10"],
        "8.10.7",
        "hstreamdb/logdevice-client:rqlite",
        hs_dir,
        no_push,
        no_write_to_docker,
    )


def haskell904(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _haskell(
        ["9.4.8", "9.4", "latest"],
        "9.4.8",
        "hstreamdb/logdevice-client",
        hs_dir,
        no_push,
        no_write_to_docker,
    )


def haskell904_rqlite(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _haskell(
        ["rqlite_9.4.8", "rqlite_9.4", "rqlite"],
        "9.4.8",
        "hstreamdb/logdevice-client:rqlite",
        hs_dir,
        no_push,
        no_write_to_docker,
    )


def haskell906(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _haskell(
        ["9.6.5", "9.6"],
        "9.6.5",
        "hstreamdb/logdevice-client",
        hs_dir,
        no_push,
        no_write_to_docker,
    )


def haskell906_rqlite(
    hs_dir="./docker-haskell", no_push=False, no_write_to_docker=False
):
    _haskell(
        ["rqlite_9.6.5", "rqlite_9.6"],
        "9.6.5",
        "hstreamdb/logdevice-client:rqlite",
        hs_dir,
        no_push,
        no_write_to_docker,
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
    haskell906(
        hs_dir=hs_dir, no_push=no_push, no_write_to_docker=no_write_to_docker
    )
    haskell906_rqlite(
        hs_dir=hs_dir, no_push=no_push, no_write_to_docker=no_write_to_docker
    )


# TODO: hstream_builder


def hstream(
    hstream_dir="./hstream",
    tag="v0.19.5",
    build_cache="no_cache",  # "no_cache" or "cache", currently arm builds have to use "no_cache"
    no_push=False,
    no_write_to_docker=False,
):
    if not os.path.exists(hstream_dir):
        run(
            f"git clone --recurse-submodules -b {tag} https://github.com/hstreamdb/hstream.git {hstream_dir}"
        )
    git_tag = get_git_tag(hstream_dir)
    git_commit = get_git_commit(hstream_dir)
    build_args = f"""
        --build-arg HS_IMAGE=hstreamdb/haskell:9.4 \
        --build-arg LD_IMAGE=hstreamdb/logdevice:latest \
        --build-arg BUILD_CACHE={build_cache} \
        --build-arg HSTREAM_VERSION={git_tag} \
        --build-arg HSTREAM_VERSION_COMMIT={git_commit}
        """.strip()
    _buildx(
        "docker/Dockerfile",
        "hstreamdb/hstream",
        [tag],
        build_args=build_args,
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hstream_dir,
    )


def hstream_rqlite(
    hstream_dir="./hstream",
    tag="v0.19.5",
    build_cache="no_cache",  # "no_cache" or "cache", currently arm builds have to use "no_cache"
    no_push=False,
    no_write_to_docker=False,
):
    if not os.path.exists(hstream_dir):
        run(
            f"git clone --recurse-submodules -b {tag} https://github.com/hstreamdb/hstream.git {hstream_dir}"
        )
    git_tag = get_git_tag(hstream_dir)
    git_commit = get_git_commit(hstream_dir)
    build_args = f"""
        --build-arg HS_IMAGE=hstreamdb/haskell:rqlite_9.4 \
        --build-arg LD_IMAGE=hstreamdb/logdevice:rqlite \
        --build-arg BUILD_CACHE={build_cache} \
        --build-arg HSTREAM_VERSION={git_tag} \
        --build-arg HSTREAM_VERSION_COMMIT={git_commit}
        """.strip()
    _buildx(
        "docker/Dockerfile",
        "hstreamdb/hstream",
        ["rqlite_" + tag],
        build_args=build_args,
        push=not no_push,
        write_to_docker=not no_write_to_docker,
        cwd=hstream_dir,
    )


if __name__ == "__main__":
    if "-h" in sys.argv or "--help" in sys.argv:
        sys.stdout = open("/dev/null", "w")

    fns = [
        setup,
        logdevice_builder,
        logdevice,
        logdevice_builder_rqlite,
        logdevice_rqlite,
        grpc,
        ghc810,
        ghc904,
        ghc906,
        ghc,
        hsthrift,
        hadmin_store,
        haskell810,
        haskell810_rqlite,
        haskell904,
        haskell904_rqlite,
        haskell906,
        haskell906_rqlite,
        haskell,
        hstream,
        hstream_rqlite,
    ]
    fire.Fire({fn.__name__: fn for fn in fns})
