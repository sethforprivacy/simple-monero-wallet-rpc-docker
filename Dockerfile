# Initial base from https://github.com/leonardochaia/docker-monerod/blob/master/src/Dockerfile
# Alpine specifics from https://github.com/cornfeedhobo/docker-monero/blob/f96711415f97af1fc9364977d1f5f5ecd313aad0/Dockerfile

# Set Monero branch or tag to build
ARG MONERO_BRANCH=v0.18.5.1

# Set the proper HEAD commit hash for the given branch/tag in MONERO_BRANCH
ARG MONERO_COMMIT_HASH=4f92268d7c16741cfb41e5bbe2aa46cc260a9ea5

# Select Alpine 3 for the build image base
FROM alpine:3.24.2@sha256:31b6477333eb8257db9e5d7c3a7264fd0467928756f0bbcc27d35bea5d28cdbd AS build
LABEL author="seth@sethforprivacy.com" \
      maintainer="seth@sethforprivacy.com"

# Upgrade base image
RUN set -ex && apk --update --no-cache upgrade

# Install all dependencies for a static build
RUN set -ex && apk add --update --no-cache \
    bison \
    boost-atomic \
    boost-chrono \
    boost-date_time \
    boost-dev \
    boost-filesystem \
    boost-program_options \
    boost-random \
    boost-regex \
    boost-serialization \
    boost-static \
    boost-system \
    boost-thread \
    ca-certificates \
    ccache \
    cmake \
    eudev-dev \
    file \
    flex \
    g++ \
    git \
    libsodium-dev \
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
ENV CCACHE_DIR=/ccache

# Build expat, a dependency for libunbound
ARG EXPAT_VERSION="2.6.4"
ARG EXPAT_HASH="8dc480b796163d4436e6f1352e71800a774f73dbae213f1860b60607d2a83ada"
RUN set -ex && wget https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-${EXPAT_VERSION}.tar.bz2 && \
    echo "${EXPAT_HASH}  expat-${EXPAT_VERSION}.tar.bz2" | sha256sum -c && \
    tar -xf expat-${EXPAT_VERSION}.tar.bz2 && \
    rm expat-${EXPAT_VERSION}.tar.bz2 && \
    cd expat-${EXPAT_VERSION} && \
    ./configure --enable-static --disable-shared --prefix=/usr && \
    make -j${NPROC:-$(nproc)} && \
    make -j${NPROC:-$(nproc)} install

# Build libunbound for static builds
WORKDIR /tmp
ARG LIBUNBOUND_VERSION="release-1.22.0"
ARG LIBUNBOUND_HASH="4e32a36d57cda666b1c8ee02185ba73462330452162d1b9c31a5b91a853ba946"
RUN set -ex && wget "https://github.com/NLnetLabs/unbound/archive/refs/tags/${LIBUNBOUND_VERSION}.tar.gz" && \
    echo "${LIBUNBOUND_HASH}  ${LIBUNBOUND_VERSION}.tar.gz" | sha256sum -c && \
    tar -xzf ${LIBUNBOUND_VERSION}.tar.gz && \
    rm ${LIBUNBOUND_VERSION}.tar.gz && \
    cd unbound-${LIBUNBOUND_VERSION} && \
    ./configure --disable-shared --enable-static --without-pyunbound --with-libexpat=/usr --with-ssl=/usr --with-libevent=no --without-pythonmodule --disable-flto --with-pthreads --with-libunbound-only --with-pic && \
    make -j${NPROC:-$(nproc)} && \
    make -j${NPROC:-$(nproc)} install

# Switch to Monero source directory
WORKDIR /monero

# Git pull Monero source at specified tag/branch and compile statically-linked monero-wallet-rpc binary
RUN --mount=type=cache,target=/ccache set -ex && git clone --recursive --branch ${MONERO_BRANCH} \
    --depth 1 --shallow-submodules \
    https://github.com/monero-project/monero . \
    && test `git rev-parse HEAD` = ${MONERO_COMMIT_HASH} || exit 1 \
    && case ${TARGETARCH:-amd64} in \
        "arm64") CMAKE_ARCH="armv8-a"; CMAKE_BUILD_TAG="linux-armv8" ;; \
        "amd64") CMAKE_ARCH="x86-64"; CMAKE_BUILD_TAG="linux-x64" ;; \
        *) echo "Dockerfile does not support this platform"; exit 1 ;; \
    esac \
    && mkdir -p build/release && cd build/release \
    && cmake -D ARCH=${CMAKE_ARCH} -D STATIC=ON -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release -D BUILD_TAG=${CMAKE_BUILD_TAG} -D STACK_TRACE=OFF -D CMAKE_C_COMPILER_LAUNCHER=ccache -D CMAKE_CXX_COMPILER_LAUNCHER=ccache ../.. \
    && cd /monero && nice -n 19 ionice -c2 -n7 make -j${NPROC:-$(nproc)} -C build/release wallet_rpc_server \
    && ccache -s

# Strip debug symbols from the shipped binary (STACK_TRACE=OFF, so none needed)
RUN set -ex && strip --strip-unneeded /monero/build/release/bin/monero-wallet-rpc

# Begin final image build
# Select Alpine 3 for the base image
FROM alpine:3.24.2@sha256:31b6477333eb8257db9e5d7c3a7264fd0467928756f0bbcc27d35bea5d28cdbd AS final

# Upgrade base image
RUN set -ex && apk --update --no-cache upgrade

# Install runtime dependencies for the binary + curl for the healthcheck
# (package set verified against ldd of the published image: zmq, sodium,
# ssl/crypto, readline/ncursesw; pcsc is not linked by this target)
RUN set -ex && apk add --update --no-cache \
    curl \
    ca-certificates \
    libsodium \
    ncurses-libs \
    readline \
    su-exec \
    tzdata \
    zeromq

# Add user and setup directories for monero-wallet-rpc
RUN set -ex && adduser -Ds /bin/ash monero \
    && mkdir -p /home/monero/.bitmonero /home/monero/wallet \
    && chown -R monero:monero /home/monero

# Copy and enable entrypoint and healthcheck scripts
COPY --chmod=0755 entrypoint.sh /entrypoint.sh
COPY --chmod=0755 healthcheck.sh /healthcheck.sh
ENTRYPOINT [ "/entrypoint.sh" ]

# Pin HOME so default paths (/home/monero/.bitmonero, /home/monero/wallet)
# are unchanged; the entrypoint drops privileges via su-exec.
ARG MONERO_USER="monero"
ENV HOME="/home/${MONERO_USER}"

# Switch to home directory and install newly built monero-wallet-rpc binary
WORKDIR /home/${MONERO_USER}
COPY --chown=monero:monero --from=build /monero/build/release/bin/monero-wallet-rpc /usr/local/bin/monero-wallet-rpc

# Expose default wallet directory
WORKDIR /home/${MONERO_USER}/wallet

# Expose default wallet-rpc port
EXPOSE 18083

# Healthcheck against the configured RPC port (PID 1 cmdline), honoring
# --rpc-login credentials if set
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s CMD /healthcheck.sh || exit 1

# Start monero-wallet-rpc with sane defaults that are overridden by user input (if applicable)
CMD ["--wallet-dir=/home/monero/wallet", "--rpc-bind-port=18083"]
