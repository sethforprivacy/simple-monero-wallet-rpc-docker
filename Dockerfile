# Initial base from https://github.com/leonardochaia/docker-monerod/blob/master/src/Dockerfile
# Alpine specifics from https://github.com/cornfeedhobo/docker-monero/blob/f96711415f97af1fc9364977d1f5f5ecd313aad0/Dockerfile

# renovate: datasource=github-releases depName=monero-project/monero
ARG MONERO_BRANCH=v0.18.5.1
ARG MONERO_COMMIT_HASH=4f92268d7c16741cfb41e5bbe2aa46cc260a9ea5

# Select Alpine 3 for the build image base
FROM alpine:3.24.1 AS build
LABEL author="seth@sethforprivacy.com" \
      maintainer="seth@sethforprivacy.com"

# Upgrade base image
RUN set -ex && apk --update --no-cache upgrade

# Install all dependencies for a static build
RUN set -ex && apk add --update --no-cache \
    autoconf \
    automake \
    bison \
    boost \
    boost-atomic \
    boost-build \
    boost-build-doc \
    boost-chrono \
    boost-container \
    boost-context \
    boost-contract \
    boost-coroutine \
    boost-date_time \
    boost-dev \
    boost-doc \
    boost-fiber \
    boost-filesystem \
    boost-graph \
    boost-iostreams \
    boost-libs \
    boost-locale \
    boost-log \
    boost-log_setup \
    boost-math \
    boost-prg_exec_monitor \
    boost-program_options \
    boost-python3 \
    boost-random \
    boost-regex \
    boost-serialization \
    boost-stacktrace_basic \
    boost-stacktrace_noop \
    boost-static \
    boost-system \
    boost-thread \
    boost-timer \
    boost-type_erasure \
    boost-unit_test_framework \
    boost-wave \
    boost-wserialization \
    ca-certificates \
    cmake \
    curl \
    dev86 \
    doxygen \
    eudev-dev \
    file \
    flex \
    g++ \
    git \
    graphviz \
    libsodium-dev \
    libtool \
    libusb-dev \
    linux-headers \
    make \
    miniupnpc-dev \
    ncurses-dev \
    openssl-dev \
    pcsc-lite-dev \
    pkgconf \
    protobuf-dev \
    rapidjson-dev \
    readline-dev \
    zeromq-dev

# Set necessary args and environment variables for building Monero
ARG MONERO_BRANCH
ARG MONERO_COMMIT_HASH
ARG NPROC
ARG TARGETARCH
ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC'
ENV USE_SINGLE_BUILDDIR=1
ENV BOOST_DEBUG=1

# Build expat, a dependency for libunbound
# renovate: datasource=github-release-attachments depName=libexpat/libexpat versioning=semver-coerced
ARG EXPAT_VERSION=R_2_6_4
ARG EXPAT_CHECKSUM=8dc480b796163d4436e6f1352e71800a774f73dbae213f1860b60607d2a83ada
RUN set -ex && EXPAT_SEMVER="$(echo ${EXPAT_VERSION} | sed 's/R_//;s/_/./g')" && \
    wget "https://github.com/libexpat/libexpat/releases/download/${EXPAT_VERSION}/expat-${EXPAT_SEMVER}.tar.bz2" && \
    echo "${EXPAT_CHECKSUM}  expat-${EXPAT_SEMVER}.tar.bz2" | sha256sum -c && \
    tar -xf expat-${EXPAT_SEMVER}.tar.bz2 && \
    rm expat-${EXPAT_SEMVER}.tar.bz2 && \
    cd expat-${EXPAT_SEMVER} && \
    ./configure --enable-static --disable-shared --prefix=/usr && \
    make -j${NPROC:-$(nproc)} && \
    make -j${NPROC:-$(nproc)} install

# Build libunbound for static builds
WORKDIR /tmp
# renovate: datasource=github-release-attachments depName=NLnetLabs/unbound versioning=semver-coerced
ARG LIBUNBOUND_VERSION=release-1.22.0
ARG LIBUNBOUND_CHECKSUM=4e32a36d57cda666b1c8ee02185ba73462330452162d1b9c31a5b91a853ba946
RUN set -ex && wget "https://github.com/NLnetLabs/unbound/archive/refs/tags/${LIBUNBOUND_VERSION}.tar.gz"  && \
    echo "${LIBUNBOUND_CHECKSUM}" "${LIBUNBOUND_VERSION}.tar.gz" | sha256sum -c && \
    tar -xzf ${LIBUNBOUND_VERSION}.tar.gz && \
    rm ${LIBUNBOUND_VERSION}.tar.gz && \
    cd unbound-${LIBUNBOUND_VERSION} && \
    ./configure --disable-shared --enable-static --without-pyunbound --with-libexpat=/usr --with-ssl=/usr --with-libevent=no --without-pythonmodule --disable-flto --with-pthreads --with-libunbound-only --with-pic && \
    make -j${NPROC:-$(nproc)} && \
    make -j${NPROC:-$(nproc)} install

# Switch to Monero source directory
WORKDIR /monero

# Git pull Monero source at specified tag/branch and compile statically-linked monerod binary
RUN set -ex && git clone --recursive --branch ${MONERO_BRANCH} \
    --depth 1 --shallow-submodules \
    https://github.com/monero-project/monero . \
    && test `git rev-parse HEAD` = ${MONERO_COMMIT_HASH} || exit 1 \
    && case ${TARGETARCH:-amd64} in \
        "arm64") CMAKE_ARCH="armv8-a"; CMAKE_BUILD_TAG="linux-armv8" ;; \
        "amd64") CMAKE_ARCH="x86-64"; CMAKE_BUILD_TAG="linux-x64" ;; \
        *) echo "Dockerfile does not support this platform"; exit 1 ;; \
    esac \
    && mkdir -p build/release && cd build/release \
    && cmake -D ARCH=${CMAKE_ARCH} -D STATIC=ON -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release -D BUILD_TAG=${CMAKE_BUILD_TAG} -D STACK_TRACE=OFF ../.. \
    && cd /monero && nice -n 19 ionice -c2 -n7 make -j${NPROC:-$(nproc)} -C build/release wallet_rpc_server

# Begin final image build
# Select Alpine 3 for the base image
FROM alpine:3.24.1 AS final

# Upgrade base image
RUN set -ex && apk --update --no-cache upgrade

# Install all dependencies for static binaries + curl for healthcheck
RUN set -ex && apk add --update --no-cache \
    curl \
    ca-certificates \
    libsodium \
    ncurses-libs \
    pcsc-lite-libs \
    readline \
    tzdata \
    zeromq

# Add user and setup directories for monerod
RUN set -ex && adduser -Ds /bin/ash monero \
    && mkdir -p /home/monero/.bitmonero \
    && chown -R monero:monero /home/monero/.bitmonero

# Copy and enable entrypoint script
COPY --chmod=0755 entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

# Copy healthcheck script
COPY --chmod=0755 healthcheck.sh /healthcheck.sh

# Install and configure fixuid and switch to MONERO_USER
ARG MONERO_USER="monero"
ARG TARGETARCH
# Checksums must be updated manually when bumping FIXUID_VERSION (upstream publishes no checksum file)
ARG FIXUID_AMD64_CHECKSUM=8c47f64ec4eec60e79871796ea4097ead919f7fcdedace766da9510b78c5fa14
ARG FIXUID_ARM64_CHECKSUM=827e0b480c38470b5defb84343be7bb4e85b9efcbf3780ac779374e8b040a969
# renovate: datasource=github-releases depName=boxboat/fixuid
ARG FIXUID_VERSION=0.6.0
RUN set -ex && case ${TARGETARCH:-amd64} in \
        "arm64") FIXUID_ARCH="arm64"; FIXUID_CHECKSUM="${FIXUID_ARM64_CHECKSUM}" ;; \
        "amd64") FIXUID_ARCH="amd64"; FIXUID_CHECKSUM="${FIXUID_AMD64_CHECKSUM}" ;; \
        *) echo "Dockerfile does not support this platform"; exit 1 ;; \
    esac && \
    curl -SsL -o /tmp/fixuid.tar.gz "https://github.com/boxboat/fixuid/releases/download/v${FIXUID_VERSION}/fixuid-${FIXUID_VERSION}-linux-${FIXUID_ARCH}.tar.gz" && \
    echo "${FIXUID_CHECKSUM}  /tmp/fixuid.tar.gz" | sha256sum -c && \
    tar -C /usr/local/bin -xzf /tmp/fixuid.tar.gz && \
    rm /tmp/fixuid.tar.gz && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: ${MONERO_USER}\ngroup: ${MONERO_USER}\n" > /etc/fixuid/config.yml
USER "${MONERO_USER}:${MONERO_USER}"

# Switch to home directory and install newly built monerod binary
WORKDIR /home/monero
COPY --chown=monero:monero --from=build /monero/build/release/bin/monero-wallet-rpc /usr/local/bin/monero-wallet-rpc

# Expose default wallet directory
WORKDIR /home/${MONERO_USER}/wallet

# Expose default wallet-rpc port
EXPOSE 18083

# Add HEALTHCHECK against json_rpc get_version, honoring --rpc-login credentials if set
HEALTHCHECK --interval=30s --timeout=5s CMD /healthcheck.sh || exit 1

# Start monerod with sane defaults that are overridden by user input (if applicable)
CMD ["--wallet-dir=/home/monero/wallet", "--rpc-bind-port=18083"]
