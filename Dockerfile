FROM ubuntu:bionic
VOLUME ["/fbcode"]
ADD ./setup-fbcode-oss-ubuntu-18.04.sh /tmp/bootstrap.sh
RUN env FBCODE_PREFIX=/fbcode /bin/bash /tmp/bootstrap.sh
ENTRYPOINT /bin/bash
