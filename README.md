# thrift ktls loadgen build

These are a set of scripts perform an OSS build of fbthrift's perf tools,
specifically a version of `loadgen` that uses kTLS.

## Instructions
* Drop necessary OpenSSL patches in ./openssl/patches/
* Kernel should be v4.18+ or a kernel with KTLS RX support
* Run ./setup-fbcode-oss-ubuntu-18.04.sh in an Ubuntu 18.04 environment.
  * The environment variable `FBCODE_PREFIX` controls where supporting libraries
    will be installed.
  * Example: running `env FBCODE_PREFIX=/fbcode ./setup-fbcode-oss-ubuntu-18.04`
    will install the final `loadgen` tool in `/fbcode/bin/loadgen`
