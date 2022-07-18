# From https://github.com/leonardochaia/docker-monerod/blob/master/src/Dockerfile
ARG MONERO_BRANCH=v0.18.0.0

# Select Ubuntu 20.04LTS for the build image base
FROM ubuntu:20.04 as build
LABEL author="sethsimmons@pm.me" \
      maintainer="sethsimmons@pm.me"

# Dependency list from https://github.com/monero-project/monero#compiling-monero-from-source
# Added DEBIAN_FRONTEND=noninteractive to workaround tzdata prompt on installation
RUN apt-get update \
    && apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    automake \
    autotools-dev \
    bsdmainutils \
    build-essential \
    ca-certificates \
    ccache \
    cmake \
    curl \
    git \
    libtool \
    pkg-config \
    gperf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC'
ENV USE_SINGLE_BUILDDIR 1
ENV BOOST_DEBUG         1

# Switch to Monero source directory
WORKDIR /monero

# Git pull Monero source at specified tag/branch
ARG MONERO_BRANCH
RUN git clone --recursive --branch ${MONERO_BRANCH} \
    https://github.com/monero-project/monero . \
    && git submodule init && git submodule update

# Make static Monero binaries
ARG NPROC
RUN test -z "$NPROC" && nproc > /nproc || echo -n "$NPROC" > /nproc && make -j"$(cat /nproc)" depends target=x86_64-linux-gnu

# Select Ubuntu 20.04LTS for the image base
FROM ubuntu:20.04

# Install remaining dependencies
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y ca-certificates curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add user and setup directories for monerod
RUN useradd -ms /bin/bash monero \
    && mkdir -p /home/monero/.bitmonero \
    && chown -R monero:monero /home/monero/.bitmonero
USER monero

# Switch to home directory and install newly built monerod binary
WORKDIR /home/monero
COPY --chown=monero:monero --from=build /monero/build/release/bin/monero-wallet-rpc /usr/local/bin/monero-wallet-rpc

# Expose p2p and restricted RPC ports
EXPOSE 18083

# Start monerod with required --non-interactive flag and sane defaults that are overridden by user input (if applicable)
ENTRYPOINT ["monero-wallet-rpc", "--non-interactive"]
CMD ["--rpc-bind-port=18083"]
