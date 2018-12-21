FROM ubuntu:bionic
COPY ./setup-fbcode-oss-ubuntu-18.04.sh /tmp/bootstrap.sh
COPY ./patches/ /tmp/docker_patches/
RUN env FBCODE_PREFIX=/fbcode FBCODE_PATCHES_DIR=/tmp/docker_patches \
        /bin/bash /tmp/bootstrap.sh && rm -rf /tmp/docker_patches
ENTRYPOINT /bin/bash
